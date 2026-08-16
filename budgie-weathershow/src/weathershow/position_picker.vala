/*
* WeatherShowII
* Author: Jacob Vlijm
* Copyright © 2017 Ubuntu Budgie Developers
* Website=https://ubuntubudgie.org
* This program is free software: you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the Free
* Software Foundation, either version 3 of the License, or any later version.
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
* more details. You should have received a copy of the GNU General Public
* License along with this program.  If not, see
* <https://www.gnu.org/licenses/>.
*
* WeatherShowPositionPicker is a click-to-place dialog for setting the
* desktop widget's x/y position, ported from budgie-showtime's
* PositionPickerDialog (src/showtime/BudgieShowTime.vala). Anchor-corner
* support was dropped: weathershow's desktop window is always top-left
* anchored (see desktop_weather.vala:set_windowpos), so this dialog only
* ever reports a top-left x/y pair. Screen size is queried through Gdk,
* which is enough for a plain (non layer-shell) settings dialog on both
* X11 and Wayland sessions, so no extra build dependency is required.
*/

using Gtk;
#if FOR_WAYLAND
using libxfce4windowing;
#endif

namespace WeatherShowApplet {

    public class WeatherShowPositionPicker : Gtk.Window {

        private Gtk.DrawingArea canvas;
        private GLib.Settings settings;
        private int selected_x;
        private int selected_y;
        private Gtk.SpinButton x_spin;
        private Gtk.SpinButton y_spin;
        private int preview_width = 220;
        private int preview_height = 110;
        private bool mouse_over = false;
        private int hover_x = 0;
        private int hover_y = 0;

        // Screen representation
        private int screen_width;
        private int screen_height;
        private int canvas_width = 600;
        private int canvas_height = 400;
        private double scale_factor;

        // Colors
        private const double GRID_COLOR_R = 0.3;
        private const double GRID_COLOR_G = 0.3;
        private const double GRID_COLOR_B = 0.3;
        private const double SELECTION_COLOR_R = 0.3;
        private const double SELECTION_COLOR_G = 0.6;
        private const double SELECTION_COLOR_B = 0.9;
        private const double HOVER_COLOR_R = 0.5;
        private const double HOVER_COLOR_G = 0.7;
        private const double HOVER_COLOR_B = 1.0;

        public signal void position_selected(int x, int y);

        public WeatherShowPositionPicker(GLib.Settings weathershow_settings) {
            this.settings = weathershow_settings;
            this.title = _("Choose WeatherShow Position");
            this.set_default_size(700, 550);
            this.set_modal(true);
            this.set_position(Gtk.WindowPosition.CENTER);
            this.destroy_with_parent = true;

            // Get current settings
            selected_x = settings.get_int("xposition");
            selected_y = settings.get_int("yposition");

            // Get screen dimensions
            get_screen_dimensions();

            // Calculate scale factor for canvas
            scale_factor = (double)canvas_width / (double)screen_width;
            if ((double)canvas_height / (double)screen_height < scale_factor) {
                scale_factor = (double)canvas_height / (double)screen_height;
            }

            setup_ui();
        }

        private void get_screen_dimensions() {
#if FOR_WAYLAND
            // wlroots-based compositors (labwc among them) don't
            // implement Gdk's "primary monitor" concept, so use
            // libxfce4windowing instead - same approach as showtime's
            // PositionPickerDialog.
            var xfw_screen = libxfce4windowing.Screen.get_default();
            var mon = xfw_screen.get_primary_monitor();
            if (mon != null) {
                var workarea = mon.get_workarea();
                screen_width = workarea.width;
                screen_height = workarea.height;
                return;
            }

            // shouldn't get here - but set via magic numbers a width and height
            screen_width = 1920;
            screen_height = 1080;
#else
            var display = Gdk.Display.get_default();
            Gdk.Monitor? monitor = display.get_primary_monitor();
            if (monitor == null && display.get_n_monitors() > 0) {
                monitor = display.get_monitor(0);
            }
            if (monitor != null) {
                var geometry = monitor.get_geometry();
                screen_width = geometry.width;
                screen_height = geometry.height;
            }
            if (screen_width <= 0 || screen_height <= 0) {
                screen_width = 1920;
                screen_height = 1080;
            }
#endif
        }

        private void setup_ui() {
            var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            main_box.set_margin_start(10);
            main_box.set_margin_end(10);
            main_box.set_margin_top(10);
            main_box.set_margin_bottom(10);
            this.add(main_box);

            // Instructions
            var instructions = new Gtk.Label(
                _("Click on the preview below to position WeatherShow.\n") +
                _("The blue rectangle represents your screen.")
            );
            instructions.set_justify(Gtk.Justification.CENTER);
            main_box.pack_start(instructions, false, false, 0);

            // Canvas frame
            var frame = new Gtk.Frame(null);
            frame.set_shadow_type(Gtk.ShadowType.IN);
            main_box.pack_start(frame, true, true, 0);

            // Drawing area
            canvas = new Gtk.DrawingArea();
            canvas.set_size_request(canvas_width, canvas_height);
            canvas.draw.connect(on_draw);
            frame.add(canvas);

            // Add mouse events
            canvas.add_events(
                Gdk.EventMask.BUTTON_PRESS_MASK |
                Gdk.EventMask.POINTER_MOTION_MASK |
                Gdk.EventMask.LEAVE_NOTIFY_MASK
            );
            canvas.button_press_event.connect(on_button_press);
            canvas.motion_notify_event.connect(on_motion);
            canvas.leave_notify_event.connect(on_leave);

            // Info label
            var info_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
            main_box.pack_start(info_box, false, false, 0);

            var info_label = new Gtk.Label("");
            info_label.set_markup(
                "<small>" +
                _("Screen: %d × %d | Click to select | ESC to cancel").printf(
                    screen_width, screen_height
                ) +
                "</small>"
            );
            info_box.pack_start(info_label, true, true, 0);

            // Position entry fields
            var coords_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            main_box.pack_start(coords_box, false, false, 0);

            var x_label = new Gtk.Label(_("X:"));
            coords_box.pack_start(x_label, false, false, 0);

            var x_spin = new Gtk.SpinButton.with_range(0, screen_width, 10);
            x_spin.set_value(selected_x);
            x_spin.value_changed.connect(() => {
                selected_x = (int)x_spin.get_value();
                canvas.queue_draw();
            });
            coords_box.pack_start(x_spin, false, false, 0);
            this.x_spin = x_spin;

            var y_label = new Gtk.Label(_("Y:"));
            coords_box.pack_start(y_label, false, false, 0);

            var y_spin = new Gtk.SpinButton.with_range(0, screen_height, 10);
            y_spin.set_value(selected_y);
            y_spin.value_changed.connect(() => {
                selected_y = (int)y_spin.get_value();
                canvas.queue_draw();
            });
            coords_box.pack_start(y_spin, false, false, 0);
            this.y_spin = y_spin;

            // Buttons
            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            button_box.set_halign(Gtk.Align.END);
            main_box.pack_start(button_box, false, false, 0);

            var cancel_button = new Gtk.Button.with_label(_("Cancel"));
            cancel_button.clicked.connect(() => { this.close(); });
            button_box.pack_start(cancel_button, false, false, 0);

            var apply_button = new Gtk.Button.with_label(_("Apply Position"));
            apply_button.get_style_context().add_class("suggested-action");
            apply_button.clicked.connect(() => {
                position_selected(selected_x, selected_y);
                this.close();
            });
            button_box.pack_start(apply_button, false, false, 0);

            // Keyboard shortcuts
            this.key_press_event.connect((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    this.close();
                    return true;
                }
                return false;
            });

            this.show_all();
        }

        private bool on_draw(Widget widget, Cairo.Context ctx) {
            // Background
            ctx.set_source_rgb(0.1, 0.1, 0.1);
            ctx.paint();

            // Calculate centered screen rectangle
            int rect_width = (int)(screen_width * scale_factor);
            int rect_height = (int)(screen_height * scale_factor);
            int rect_x = (canvas.get_allocated_width() - rect_width) / 2;
            int rect_y = (canvas.get_allocated_height() - rect_height) / 2;

            // Draw screen outline
            ctx.set_source_rgb(SELECTION_COLOR_R, SELECTION_COLOR_G, SELECTION_COLOR_B);
            ctx.set_line_width(2.0);
            ctx.rectangle(rect_x, rect_y, rect_width, rect_height);
            ctx.stroke();

            // Draw grid
            ctx.set_source_rgba(GRID_COLOR_R, GRID_COLOR_G, GRID_COLOR_B, 0.3);
            ctx.set_line_width(1.0);

            int grid_spacing = 50;
            for (int x = 0; x < screen_width; x += grid_spacing) {
                int canvas_x = rect_x + (int)(x * scale_factor);
                ctx.move_to(canvas_x, rect_y);
                ctx.line_to(canvas_x, rect_y + rect_height);
            }
            for (int y = 0; y < screen_height; y += grid_spacing) {
                int canvas_y = rect_y + (int)(y * scale_factor);
                ctx.move_to(rect_x, canvas_y);
                ctx.line_to(rect_x + rect_width, canvas_y);
            }
            ctx.stroke();

            // Draw hover preview
            if (mouse_over) {
                draw_weathershow_preview(ctx, rect_x, rect_y, hover_x, hover_y,
                                 HOVER_COLOR_R, HOVER_COLOR_G, HOVER_COLOR_B, 0.5);
            }

            // Draw selected position
            draw_weathershow_preview(ctx, rect_x, rect_y, selected_x, selected_y,
                             SELECTION_COLOR_R, SELECTION_COLOR_G, SELECTION_COLOR_B, 0.8);

            return false;
        }

        private void draw_weathershow_preview(Cairo.Context ctx, int rect_x, int rect_y,
                                       int pos_x, int pos_y,
                                       double r, double g, double b, double alpha) {
            // Always top-left anchored: (pos_x, pos_y) is the box's top-left corner.
            int canvas_x = rect_x + (int)(pos_x * scale_factor);
            int canvas_y = rect_y + (int)(pos_y * scale_factor);
            int canvas_w = (int)(preview_width * scale_factor);
            int canvas_h = (int)(preview_height * scale_factor);

            // Draw weathershow preview rectangle
            ctx.set_source_rgba(r, g, b, alpha);
            ctx.rectangle(canvas_x, canvas_y, canvas_w, canvas_h);
            ctx.fill();

            // Draw outline
            ctx.set_source_rgba(r, g, b, 1.0);
            ctx.set_line_width(2.0);
            ctx.rectangle(canvas_x, canvas_y, canvas_w, canvas_h);
            ctx.stroke();

            // Draw crosshair at the anchor point (top-left corner)
            ctx.set_source_rgba(1.0, 1.0, 1.0, 0.8);
            ctx.set_line_width(1.5);
            ctx.move_to(canvas_x - 5, canvas_y);
            ctx.line_to(canvas_x + 5, canvas_y);
            ctx.move_to(canvas_x, canvas_y - 5);
            ctx.line_to(canvas_x, canvas_y + 5);
            ctx.stroke();

            // Draw label
            ctx.set_source_rgba(1.0, 1.0, 1.0, alpha);
            ctx.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            ctx.set_font_size(10);
            string label = "%d, %d".printf(pos_x, pos_y);
            ctx.move_to(canvas_x + 5, canvas_y + 15);
            ctx.show_text(label);
        }

        private bool on_button_press(Gdk.EventButton event) {
            int rect_width = (int)(screen_width * scale_factor);
            int rect_height = (int)(screen_height * scale_factor);
            int rect_x = (canvas.get_allocated_width() - rect_width) / 2;
            int rect_y = (canvas.get_allocated_height() - rect_height) / 2;

            // Convert click position to screen coordinates
            int click_x = (int)((event.x - rect_x) / scale_factor);
            int click_y = (int)((event.y - rect_y) / scale_factor);

            // Clamp to screen bounds
            if (click_x < 0) click_x = 0;
            if (click_x > screen_width) click_x = screen_width;
            if (click_y < 0) click_y = 0;
            if (click_y > screen_height) click_y = screen_height;

            selected_x = click_x;
            selected_y = click_y;

            // keep the spin buttons in sync so the visible X/Y fields
            // actually reflect what was clicked - this is the bit that
            // was missing and made clicks look like they did nothing.
            x_spin.set_value(selected_x);
            y_spin.set_value(selected_y);

            canvas.queue_draw();
            return true;
        }

        private bool on_motion(Gdk.EventMotion event) {
            int rect_width = (int)(screen_width * scale_factor);
            int rect_height = (int)(screen_height * scale_factor);
            int rect_x = (canvas.get_allocated_width() - rect_width) / 2;
            int rect_y = (canvas.get_allocated_height() - rect_height) / 2;

            // Check if mouse is over screen area
            if (event.x >= rect_x && event.x <= rect_x + rect_width &&
                event.y >= rect_y && event.y <= rect_y + rect_height) {
                mouse_over = true;
                hover_x = (int)((event.x - rect_x) / scale_factor);
                hover_y = (int)((event.y - rect_y) / scale_factor);
            } else {
                mouse_over = false;
            }

            canvas.queue_draw();
            return true;
        }

        private bool on_leave(Gdk.EventCrossing event) {
            mouse_over = false;
            canvas.queue_draw();
            return false;
        }
    }
}
