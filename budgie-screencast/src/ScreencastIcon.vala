/*
* Budgie Screencast
* Author: Sam Lane
* Copyright © 2026 Ubuntu Budgie Developers
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
 * This creates a video recorder icon with a small blinking
 * red dot to indicate when the recording is active
 */

public class ScreencastIcon : Gtk.EventBox {
    private Gtk.Overlay overlay;
    private Gtk.Image base_icon;
    private Gtk.DrawingArea dot;

    private uint timeout_id = 0;
    private bool flash_state = true;

    public ScreencastIcon (string icon_name = "camera-video-symbolic") {
        this.set_visible_window(false);

        overlay = new Gtk.Overlay();
        this.add(overlay);
        base_icon = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.BUTTON);
        overlay.add(base_icon);

        // Little red blinking dot to indicate when recording
        dot = new Gtk.DrawingArea();
        dot.set_size_request(8, 8);
        dot.set_halign(Gtk.Align.END);
        dot.set_valign(Gtk.Align.END);
        dot.set_margin_bottom(10);
        dot.set_margin_end(0);
        dot.draw.connect((cr) => {
            cr.arc(4, 4, 3.5, 0, 2 * Math.PI);
            cr.set_source_rgb(1.0, 0.0, 0.0);
            cr.fill();
            return false;
        });
        overlay.add_overlay(dot);
        this.show_all();
        dot.hide();
    }

    public void set_recording (bool recording) {
        if (recording) {
            dot.show();
            start_flashing();
        } else {
            stop_flashing();
            dot.hide();
        }
    }

    private void start_flashing () {
        if (timeout_id != 0)
            return;

        timeout_id = GLib.Timeout.add(500, () => {
            flash_state = !flash_state;
            dot.set_visible(flash_state);
            return true;
        });
    }

    private void stop_flashing () {
        if (timeout_id != 0) {
            GLib.Source.remove(timeout_id);
            timeout_id = 0;
        }
    }
}