using Gtk;
using Gdk;
using Math;
using libxfce4windowing;


/*
* BudgieShowTimeII
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
*/

/*
Note:
if showtime window exists on primary -> don't recreate on primary, but make
it move to the right position (set_position()) from within the window.
so:
- no action from applet
- move window from itself
*/


namespace BudgieShowTimeWidget {

    private string moduledir;
    private int n_monitors;
    GLib.Settings showtime_settings;
    string winpath;
    libxfce4windowing.Screen xfw_screen;
    bool surpass_primary;

    private bool onprimary_exists () {
        // Use libxfce4windowing to check for window
        libxfce4windowing.Screen xfw_screen = libxfce4windowing.Screen.get_default();
        unowned var windows = xfw_screen.get_windows();

        foreach (var w in windows) {
            if (w.get_name() == "Showtime") {
                return true;
            }
        }
        return false;
    }

    private int[] getwindata () {
        // Can't query window geometry on Wayland
        // Return settings + estimated dimensions
        int x = showtime_settings.get_int("xposition");
        int y = showtime_settings.get_int("yposition");
        int w = 150;  // Estimated width
        int h = 80;   // Estimated height
        return {x, y, w, h};
    }

    private void create_windows (
        libxfce4windowing.Screen? screen = null, bool? surpass_primary = null
     ) {
        if (screen == null) {
            screen = xfw_screen;
        }

        unowned var monitors = screen.get_monitors();
        n_monitors = 0;
        libxfce4windowing.Monitor? primary_monitor = xfw_screen.get_primary_monitor();

        // Count monitors
        if (monitors != null)
            n_monitors = (int)monitors.length();

        bool allmonitors = showtime_settings.get_boolean("allmonitors");

        foreach (var m in monitors) {
            if (primary_monitor !=null && m == primary_monitor) {
                // Primary: window is autonomous
                if (surpass_primary != true && !onprimary_exists()) {
                    open_window();
                }
            }
            else if (allmonitors) {
                // Secondary showtime windows positioned in bottom-right
                var workarea = m.get_workarea();
                int xpos = workarea.x + workarea.width - 150;
                int ypos = workarea.y + workarea.height - 150;
                open_window(
                    m.get_description() ?? "monitor",
                    xpos.to_string(),
                    ypos.to_string()
                );
            }
        }
        surpass_primary = false;
    }

    private void open_window(
        string? wname = null, string? xpos = null, string? ypos = null
        ) {
        // call the desktop showtime window;
        string cmd = winpath;
        if (wname != null) {
            cmd = winpath.concat(" ", wname, " ", xpos, " ", ypos);
        }

        try {
            print("TRIED \n");
            Process.spawn_command_line_async(cmd);
        }
        catch (SpawnError e) {
            print("tried and failed\n");
            /* nothing to be done */
        }
    }


    public class BudgieShowTimeSettings : Gtk.Grid {

        /* Budgie Settings -section */
        GLib.Settings? settings = null;
        Button dragbutton;
        RadioButton[] anchorbuttons;
        string[] anchors;
        string curr_anchor;
        CheckButton leftalign;
        CheckButton twelve_hrs;
        Gtk.FontButton timefontbutton;
        Gtk.FontButton datefontbutton;
        Gtk.ColorButton timecolor;
        Gtk.ColorButton datecolor;
        Gtk.SpinButton linespacing;
        Label draghint;
        string dragposition;
        string fixposition;
        Grid anchorgrid;
        CheckButton autopos;
        CheckButton allmonitors;
        Label spinlabel;
        Gdk.Screen gdkscreen;


        public BudgieShowTimeSettings(GLib.Settings? settings) {
            this.settings = settings;

            // Initialize libxfce4windowing for Wayland
            xfw_screen = libxfce4windowing.Screen.get_default();

            // Monitor changes on Wayland
            xfw_screen.monitors_changed.connect(() => {
                unowned var monitors = xfw_screen.get_monitors();
                n_monitors = 0;
                foreach (var m in monitors) {
                    n_monitors++;
                }
                bool newsensitive = (n_monitors > 1);
                if (n_monitors == 1) {
                    allmonitors.set_active(false);
                }
                allmonitors.set_sensitive(newsensitive);
                create_windows(xfw_screen);
            });
            // translated strings
            dragposition = (_("Drag position"));
            fixposition = (_("Save position"));
            string stsettings_css = ".st_header {font-weight: bold;}";
            string dragtext = (_(
                "Enable Super + drag to set time position. Click ´Save position´ to save."
            ));

            var screen = this.get_screen();
            // window content
            this.set_row_spacing(10);
            var position_header = new Gtk.Label(_("Position & anchor"));
            position_header.xalign = 0;
            this.attach(position_header, 0, 0, 10, 1);
            // automatic positioning
            var positionbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.attach(positionbox, 0, 1, 10, 1);
            autopos = new CheckButton.with_label((_("Automatic")));
            allmonitors = new CheckButton.with_label((_("On all monitors")));
            positionbox.pack_start(autopos, false, false, 0);
            positionbox.pack_start(allmonitors, false, false, 0);
            // drag button
            dragbutton = new Gtk.Button();
            dragbutton.set_tooltip_text(dragtext);
            dragbutton.set_label(_("Drag position"));
            dragbutton.set_size_request(150, 10);
            draghint = new Gtk.Label("");
            draghint.xalign = (float)0.5;
            // anchor section
            anchorgrid = new Gtk.Grid();
            var leftspace = new Gtk.Label("\t");
            var centerlabel = new Gtk.Label("\t");
            anchorgrid.attach(leftspace, 1, 0, 1, 1);
            anchorgrid.attach(centerlabel, 3, 1, 1, 1);
            // group leader
            var nw = new RadioButton(null);
            // group
            anchors = {"nw", "ne", "se", "sw"};
            var ne = new RadioButton(nw.get_group());
            var se = new RadioButton(nw.get_group());
            var sw = new RadioButton(nw.get_group());
            anchorgrid.attach(nw, 2, 0, 1, 1);
            anchorgrid.attach(ne, 4, 0, 1, 1);
            anchorgrid.attach(se, 4, 2, 1, 1);
            anchorgrid.attach(sw, 2, 2, 1, 1);
            anchorgrid.attach(dragbutton, 0, 1, 1, 1);
            anchorgrid.attach(draghint, 0, 0, 1, 1);
            this.attach(anchorgrid, 0, 2, 2, 1);
            // group stuff
            anchorbuttons = {nw, ne, se, sw};
            foreach (RadioButton b in anchorbuttons) {
                b.set_tooltip_text(
                    _("Anchor, time will expand/shrink in/from opposite direction.")
                );
            }
            anchors = {"nw", "ne", "se", "sw"};
            curr_anchor = showtime_settings.get_string("anchor");
            anchorbuttons[
                get_stringindex(anchors, curr_anchor)
            ].set_active(true);
            // time font settings -> boxed!!
            var time_header = new Gtk.Label(_("Time font, size & color"));
            time_header.xalign = 0;
            this.attach(time_header, 0, 6, 10, 1);
            var timebox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.attach(timebox, 0, 7, 10, 1);
            timefontbutton = new FontButton();
            timebox.pack_start(timefontbutton, false, false, 0);
            timecolor = new Gtk.ColorButton();
            timebox.pack_start(timecolor, false, false, 0);
            var spacelabel3 = new Gtk.Label("");
            this.attach(spacelabel3, 1, 8, 1, 1);
            // date font settings
            var date_header = new Gtk.Label(_("Date font, size & color"));
            date_header.xalign = 0;
            this.attach(date_header, 0, 10, 10, 1);
            var datebox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.attach(datebox, 0, 11, 10, 1);
            datefontbutton = new FontButton();
            datebox.pack_start(datefontbutton, false, false, 0);
            datecolor = new Gtk.ColorButton();
            datebox.pack_start(datecolor, false, false, 0);
            var spacelabel5 = new Gtk.Label("");
            this.attach(spacelabel5, 1, 12, 1, 1);
            // miscellaneous section
            var general_header = new Gtk.Label(_("Miscellaneous"));
            general_header.xalign = 0;
            this.attach(general_header, 0, 20, 10, 1);
            leftalign = new Gtk.CheckButton.with_label(_("Left align text"));
            this.attach(leftalign, 0, 21, 10, 1);
            twelve_hrs = new Gtk.CheckButton.with_label(_("Use 12hr time format"));
            this.attach(twelve_hrs, 0, 22, 10, 1);
            var spacelabel6 = new Gtk.Label("");
            this.attach(spacelabel6, 1, 23, 1, 1);
            Gtk.Box linespacebox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            this.attach(linespacebox, 0, 30, 3, 1);
            linespacing = new Gtk.SpinButton.with_range (-50, 50, 1);
            linespacebox.pack_start(linespacing, false, false, 0);
            spinlabel = new Gtk.Label(_("Linespacing"));
            linespacebox.pack_start(spinlabel, false, false, 0);
            // Set style on headers
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(stsettings_css);
                Gtk.StyleContext.add_provider_for_screen(
                    screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (GLib.Error e) {
            }
            Label[] boldones = {
                time_header, date_header, general_header, position_header
            };
            foreach (Label l in boldones) {
                l.get_style_context().add_class("st_header");
            };
            set_initialvals();
            connect_widgets();
            this.show_all();
        }

        private void show_position_picker() {
            var picker = new PositionPickerDialog(showtime_settings);
            picker.set_transient_for(this.get_toplevel() as Gtk.Window);

            picker.position_selected.connect((x, y, anchor) => {
                // Update settings with selected position
                showtime_settings.set_int("xposition", x);
                showtime_settings.set_int("yposition", y);
                showtime_settings.set_string("anchor", anchor);

                // Update anchor radio buttons
                int anchor_index = get_stringindex(anchors, anchor);
                if (anchor_index >= 0) {
                    anchorbuttons[anchor_index].set_active(true);
                }

                // Trigger window reposition
                create_windows(xfw_screen);
            });

            picker.show();
        }

        private int get_stringindex (string[] arr, string lookfor) {
            // get index of string in list
            for (int i=0; i < arr.length; i++) {
                if(lookfor == arr[i]) return i;
            }
            return -1;
        }

        private void set_anchor (ToggleButton button) {
            // Position Picker will handle full position setting
            // Just update the anchor preference
            int n = 0;
            string newanchor = "se";
            foreach (ToggleButton b in anchorbuttons) {
                if (b == button) {
                    newanchor = anchors[n];
                }
                n += 1;
            }
            // Just set anchor, don't recalculate position
            showtime_settings.set_string("anchor", newanchor);
        }

        private void set_newlinespacing (SpinButton button, string setting) {
            // get current settings from button, set gsetings
            int newval = (int)button.get_value();
            showtime_settings.set_int(setting, newval);
        }

        private void set_initialvals () {
            // fetch current settings, set widgets
            set_initiallinespacing(linespacing, "linespacing");
            set_initialdrag();
            set_initialcolor(timecolor, "timefontcolor");
            set_initialcolor(datecolor, "datefontcolor");
            set_initialcheck(leftalign, "leftalign");
            set_initialcheck(twelve_hrs, "twelvehrs");
            set_initialfont(timefontbutton, "timefont");
            set_initialfont(datefontbutton, "datefont");
            set_initialautopos();
            set_initialallmonitors();
        }

        public void set_initialallmonitors () {
            bool newval = showtime_settings.get_boolean("allmonitors");
            allmonitors.set_active(newval);
            bool newautopos = showtime_settings.get_boolean("autoposition");
            allmonitors.set_sensitive(newautopos);
        }

        public void set_initialautopos () {
            bool newval = showtime_settings.get_boolean("autoposition");
            autopos.set_active(newval);
            anchorgrid.set_sensitive(!newval);
        }

        private void set_initialfont (FontButton button, string setting) {
            // color to show on the button
            string currval = showtime_settings.get_string(setting);
            button.set_font(currval);
        }

        private void set_initiallinespacing (SpinButton button, string setting) {
            // color to show on the button
            int currval = showtime_settings.get_int(setting);
            button.set_value(currval);
        }

        private void set_initialcheck (CheckButton button, string setting) {
            // checkboxes - initials
            bool currval = showtime_settings.get_boolean(setting);
            button.set_active(currval);
        }

        private void connect_widgets () {
            // as the name sais
            autopos.toggled.connect(toggle_autopos);
            allmonitors.toggled.connect(toggle_allmonitors);


            linespacing.value_changed.connect (() => {
                set_newlinespacing(linespacing, "linespacing");
            });
            dragbutton.clicked.connect(toggle_drag);
            timecolor.color_set.connect (() => {
                set_hexcolor(timecolor, "timefontcolor");
            });
            datecolor.color_set.connect (() => {
                set_hexcolor(datecolor, "datefontcolor");
            });
            timefontbutton.font_set.connect (() => {
                set_newfont(timefontbutton, "timefont");
            });
            datefontbutton.font_set.connect (() => {
                set_newfont(datefontbutton, "datefont");
            });
            leftalign.toggled.connect (() => {
                toggle_value(leftalign, "leftalign");
            });
            twelve_hrs.toggled.connect (() => {
                toggle_value(twelve_hrs, "twelvehrs");
            });
            // connect anchors
            foreach (RadioButton b in anchorbuttons) {
                b.toggled.connect (() => {
                    filter_active(b);
                });
            }
        }

        private void filter_active (ToggleButton button) {
            // only act on activating button, not on deactivating
            if (button.get_active()) {
                set_anchor(button);
            }
        }

        private void toggle_allmonitors (ToggleButton button) {
            bool val = button.get_active();
            showtime_settings.set_boolean("allmonitors", val);
            create_windows(xfw_screen, surpass_primary = true);
        }

        private void toggle_autopos (ToggleButton button) {
            bool val = button.get_active();
            bool curr_allmons = allmonitors.get_active();
            if (!val) {
                // Switching to manual positioning
                // Can't read current window position on Wayland
                // Use existing manual position or default to bottom-right
                int curr_x = showtime_settings.get_int("xposition");
                int curr_y = showtime_settings.get_int("yposition");

                // If never set (0,0), use default bottom-right position
                if (curr_x == 0 && curr_y == 0) {
                    var mon = xfw_screen.get_primary_monitor();
                    var workarea = mon.get_workarea();
                    showtime_settings.set_int("xposition", workarea.width - 150);
                    showtime_settings.set_int("yposition", workarea.height - 150);

                }
                showtime_settings.set_string("anchor", "se");
            }
            else {
                create_windows(xfw_screen, surpass_primary = true);
            }
            if (n_monitors != 1) {
                allmonitors.set_sensitive(val);
            }
            else {
                allmonitors.set_sensitive(false);
            }
            anchorbuttons[2].set_active(true);
            anchorgrid.set_sensitive(!val);
            showtime_settings.set_boolean("autoposition", val);
        }

        private void set_hexcolor(ColorButton button, string setting) {
            Gdk.RGBA c = button.get_rgba();
            string s =
            "#%02x%02x%02x"
            .printf((uint)(Math.round(c.red*255)),
                    (uint)(Math.round(c.green*255)),
                    (uint)(Math.round(c.blue*255))).up();
            showtime_settings.set_string(setting, s);
        }

        private void set_newfont(FontButton button, string newfont) {
            showtime_settings.set_string(newfont, button.get_font());
        }

        private void toggle_value (CheckButton button, string setting) {
            // toggle callback
            bool newval = button.get_active();
            showtime_settings.set_boolean(setting, newval);
        }

        private void set_initialcolor (ColorButton button, string setting) {
            // get current settings from gsetting, set button color
            Gdk.RGBA currcolor = Gdk.RGBA();
            currcolor.parse(showtime_settings.get_string(setting));
            button.set_rgba(currcolor);
        }

        private void set_initialdrag () {
            // get current settings from gsettinsg, set dragbutton label
            bool curr_draggable = showtime_settings.get_boolean("draggable");
            toggle_sensitive(!curr_draggable);
            dragbutton.set_label(dragposition);
            if (curr_draggable) {
                dragbutton.set_label(fixposition);
            }
        }

        private void toggle_sensitive (bool active) {
            autopos.set_sensitive(active);
            foreach (RadioButton b in anchorbuttons) {
                b.set_sensitive(active);
            }
            datefontbutton.set_sensitive(active);
            datecolor.set_sensitive(active);
            timefontbutton.set_sensitive(active);
            timecolor.set_sensitive(active);
            leftalign.set_sensitive(active);
            twelve_hrs.set_sensitive(active);
            linespacing.set_sensitive(active);
            spinlabel.set_sensitive(active);
        }

        private void toggle_drag () {
           show_position_picker();
        }
    }

    public class PositionPickerDialog : Gtk.Window {

        private Gtk.DrawingArea canvas;
        private GLib.Settings settings;
        private int selected_x;
        private int selected_y;
        private int preview_width = 120;
        private int preview_height = 60;
        private bool mouse_over = false;
        private int hover_x = 0;
        private int hover_y = 0;
        private string current_anchor;

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

        public signal void position_selected(int x, int y, string anchor);

        public PositionPickerDialog(GLib.Settings showtime_settings) {
            this.settings = showtime_settings;
            this.title = _("Choose ShowTime Position");
            this.set_default_size(700, 550);
            this.set_modal(true);
            this.set_position(Gtk.WindowPosition.CENTER);
            this.destroy_with_parent = true;

            // Get current settings
            selected_x = settings.get_int("xposition");
            selected_y = settings.get_int("yposition");
            current_anchor = settings.get_string("anchor");

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
            // Use Xfw for Wayland
            var xfw_screen = libxfce4windowing.Screen.get_default();
            var mon = xfw_screen.get_primary_monitor();
            if (mon != null) {
                var workarea = mon.get_workarea();
                screen_width = workarea.width;
                screen_height = workarea.height;
                return;
            }

            // shouldn't get here - but set via magic numbers a width and height
            screen_width = 800;
            screen_height = 600;
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
                _("Click on the preview below to position ShowTime.\n") +
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

            // Anchor selection
            var anchor_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            main_box.pack_start(anchor_box, false, false, 0);

            var anchor_label = new Gtk.Label(_("Anchor:"));
            anchor_box.pack_start(anchor_label, false, false, 0);

            // Anchor radio buttons
            var nw_radio = new Gtk.RadioButton.with_label(null, _("↖ NW"));
            var ne_radio = new Gtk.RadioButton.with_label_from_widget(nw_radio, _("↗ NE"));
            var sw_radio = new Gtk.RadioButton.with_label_from_widget(nw_radio, _("↙ SW"));
            var se_radio = new Gtk.RadioButton.with_label_from_widget(nw_radio, _("↘ SE"));

            nw_radio.set_tooltip_text(_("Anchor top-left, ShowTime expands right/down"));
            ne_radio.set_tooltip_text(_("Anchor top-right, ShowTime expands left/down"));
            sw_radio.set_tooltip_text(_("Anchor bottom-left, ShowTime expands right/up"));
            se_radio.set_tooltip_text(_("Anchor bottom-right, ShowTime expands left/up"));

            anchor_box.pack_start(nw_radio, false, false, 0);
            anchor_box.pack_start(ne_radio, false, false, 0);
            anchor_box.pack_start(sw_radio, false, false, 0);
            anchor_box.pack_start(se_radio, false, false, 0);

            // Set current anchor
            switch (current_anchor) {
                case "nw": nw_radio.set_active(true); break;
                case "ne": ne_radio.set_active(true); break;
                case "sw": sw_radio.set_active(true); break;
                case "se": se_radio.set_active(true); break;
            }

            // Connect anchor changes
            nw_radio.toggled.connect(() => { if (nw_radio.get_active()) { current_anchor = "nw"; canvas.queue_draw(); } });
            ne_radio.toggled.connect(() => { if (ne_radio.get_active()) { current_anchor = "ne"; canvas.queue_draw(); } });
            sw_radio.toggled.connect(() => { if (sw_radio.get_active()) { current_anchor = "sw"; canvas.queue_draw(); } });
            se_radio.toggled.connect(() => { if (se_radio.get_active()) { current_anchor = "se"; canvas.queue_draw(); } });

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

            var y_label = new Gtk.Label(_("Y:"));
            coords_box.pack_start(y_label, false, false, 0);

            var y_spin = new Gtk.SpinButton.with_range(0, screen_height, 10);
            y_spin.set_value(selected_y);
            y_spin.value_changed.connect(() => {
                selected_y = (int)y_spin.get_value();
                canvas.queue_draw();
            });
            coords_box.pack_start(y_spin, false, false, 0);

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
                position_selected(selected_x, selected_y, current_anchor);
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
            //var alloc = canvas.get_allocation();

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
                draw_showtime_preview(ctx, rect_x, rect_y, hover_x, hover_y,
                                 HOVER_COLOR_R, HOVER_COLOR_G, HOVER_COLOR_B, 0.5);
            }

            // Draw selected position
            draw_showtime_preview(ctx, rect_x, rect_y, selected_x, selected_y,
                             SELECTION_COLOR_R, SELECTION_COLOR_G, SELECTION_COLOR_B, 0.8);

            return false;
        }

        private void draw_showtime_preview(Cairo.Context ctx, int rect_x, int rect_y,
                                       int pos_x, int pos_y,
                                       double r, double g, double b, double alpha) {
            int canvas_x = rect_x + (int)(pos_x * scale_factor);
            int canvas_y = rect_y + (int)(pos_y * scale_factor);
            int canvas_w = (int)(preview_width * scale_factor);
            int canvas_h = (int)(preview_height * scale_factor);

            // Adjust for anchor
            if (current_anchor.contains("e")) {
                canvas_x -= canvas_w;
            }
            if (current_anchor.contains("s")) {
                canvas_y -= canvas_h;
            }

            // Draw showtime preview rectangle
            ctx.set_source_rgba(r, g, b, alpha);
            ctx.rectangle(canvas_x, canvas_y, canvas_w, canvas_h);
            ctx.fill();

            // Draw outline
            ctx.set_source_rgba(r, g, b, 1.0);
            ctx.set_line_width(2.0);
            ctx.rectangle(canvas_x, canvas_y, canvas_w, canvas_h);
            ctx.stroke();

            // Draw crosshair at anchor point
            int anchor_x = canvas_x;
            int anchor_y = canvas_y;
            if (current_anchor.contains("e")) {
                anchor_x += canvas_w;
            }
            if (current_anchor.contains("s")) {
                anchor_y += canvas_h;
            }

            ctx.set_source_rgba(1.0, 1.0, 1.0, 0.8);
            ctx.set_line_width(1.5);
            ctx.move_to(anchor_x - 5, anchor_y);
            ctx.line_to(anchor_x + 5, anchor_y);
            ctx.move_to(anchor_x, anchor_y - 5);
            ctx.line_to(anchor_x, anchor_y + 5);
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
            //var alloc = canvas.get_allocation();
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

            canvas.queue_draw();
            return true;
        }

        private bool on_motion(Gdk.EventMotion event) {
            //var alloc = canvas.get_allocation();
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

    public class ShowtimeRavenPlugin : Budgie.RavenPlugin, Peas.ExtensionBase {

        public Budgie.RavenWidget new_widget_instance(string uuid, GLib.Settings? settings) {
            var info = this.get_plugin_info();
            moduledir = info.get_module_dir();
            return new ShowTimeRavenWidget (uuid, settings);
        }

        public bool supports_settings() {
            return true;
        }
    }

    public class ShowTimeRavenWidget : Budgie.RavenWidget {

        public string uuid { public set; public get; }

        public ShowTimeRavenWidget(string uuid, GLib.Settings? settings) {
            var showtime = new ShowTimeMain(uuid, settings);            
            initialiseLocaleLanguageSupport();
        }

        public void initialiseLocaleLanguageSupport() {
            // Initialize gettext
            GLib.Intl.setlocale(GLib.LocaleCategory.ALL, "");
            GLib.Intl.bindtextdomain(
                Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR
            );
            GLib.Intl.bind_textdomain_codeset(
                Config.GETTEXT_PACKAGE, "UTF-8"
            );
            GLib.Intl.textdomain(Config.GETTEXT_PACKAGE);
        }

        public override Gtk.Widget build_settings_ui() {
            return new BudgieShowTimeSettings (get_instance_settings());
        }
    }

    public class ShowTimeMain : Object {

        private string uuid;

        public ShowTimeMain(string uuid, GLib.Settings? settings) {
            this.uuid = uuid;

            showtime_settings = settings;
            // Initialize libxfce4windowing for Wayland
            xfw_screen = libxfce4windowing.Screen.get_default();

            // Get initial monitor count
            unowned var monitors = xfw_screen.get_monitors();
            n_monitors = 0;
            foreach (var m in monitors) {
                n_monitors++;
            }
            winpath = moduledir.concat(@"/showtime-desktop $uuid");
            // Start from Idle so the panel can form before spawning
            Idle.add(() => {
                create_windows(xfw_screen);
                return false;
            });
        }
    }
}


[ModuleInit]
public void peas_register_types(TypeModule module) {
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.RavenPlugin), typeof(BudgieShowTimeWidget.ShowtimeRavenPlugin));
}
