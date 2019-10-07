using Gtk;
using Math;

// valac -X -lm --pkg gtk+-3.0

/*
Budgie WallStreet
Author: Jacob Vlijm
Copyright © 2017-2019 Ubuntu Budgie Developers
Website=https://ubuntubudgie.org
This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or any later version. This
program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details. You
should have received a copy of the GNU General Public License along with this
program.  If not, see <https://www.gnu.org/licenses/>.
*/

namespace WallpaperRunner {

    GLib.Settings wallstreet_settings;
    
    class ControlsWindow : Gtk.Window {

        SpinButton hours_spin;
        SpinButton minutes_spin;
        SpinButton seconds_spin;
        Entry dir_entry;
        string default_folder;
        Button set_customtwalls;

        public ControlsWindow () {
            // window props
            this.set_position(Gtk.WindowPosition.CENTER);
            this.title = "WallStreet Control";
            var maingrid = new Gtk.Grid();
            this.add(maingrid);
            set_margins(maingrid);
            // misc
            default_folder = wallstreet_settings.get_default_value(
                "wallpaperfolder"
            ).get_string();
            // togglebuttons
            var toggle_wprunner = new Gtk.CheckButton.with_label(
                "Run WallStreet"
            );
            maingrid.attach(toggle_wprunner, 1, 1, 1, 1);
            var toggle_defaultwalls = new Gtk.CheckButton.with_label(
                "Use default wallpapers"
            );
            maingrid.attach(toggle_defaultwalls, 1, 2, 1, 1);
            // spacer
            var givemesomespace = new Gtk.Label("");
            maingrid.attach(givemesomespace, 1, 3, 1, 1);
            // custom folder section
            Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            maingrid.attach(box, 1, 4, 99, 1);
            set_customtwalls = new Gtk.Button.with_label(
                "Browse"
            );
            set_customtwalls.clicked.connect(get_directory);
            box.pack_start(set_customtwalls, false, false, 10);
            dir_entry = new Gtk.Entry();
            dir_entry.set_width_chars(35);
            dir_entry.set_editable(false);
            box.pack_start(dir_entry, false, false, 0);
            box.pack_start(new Label("\t"), false, false, 0);
            // spacer
            var empty = new Label("");
            maingrid.attach(empty, 1, 10, 1, 1);
            // time settings section
            var time_label = new Label("\nChange wallpaper every:\n");
            time_label.set_xalign(0);
            maingrid.attach(time_label, 1, 11, 1, 1);
            var timegrid = new Gtk.Grid();
            maingrid.attach(timegrid, 1, 12, 2, 3);
            var hours_label = new Label("Hours\t");
            hours_label.set_xalign(0);
            timegrid.attach(hours_label, 0, 0, 1, 1);
            hours_spin = new Gtk.SpinButton.with_range(0, 24, 1);
            timegrid.attach(hours_spin, 1, 0, 1, 1);
            var minutes_label = new Label("Minutes\t");
            minutes_label.set_xalign(0);
            timegrid.attach(minutes_label, 0, 1, 1, 1);
            minutes_spin = new Gtk.SpinButton.with_range(0, 59, 1);
            timegrid.attach(minutes_spin, 1, 1, 1, 1);
            var seconds_label = new Label("Seconds\t");
            seconds_label.set_xalign(0);
            timegrid.attach(seconds_label, 0, 2, 1, 1);
            seconds_spin = new Gtk.SpinButton.with_range(0, 59, 1);
            timegrid.attach(seconds_spin, 1, 2, 1, 1);
            var ok_button = new Button.with_label("Close");
            maingrid.attach(ok_button, 99, 99, 1, 1);
            ok_button.clicked.connect(Gtk.main_quit);
            this.destroy.connect(Gtk.main_quit);
            // display initial value(s)
            divide_time();
            // connect spin buttons after fetching initial values
            hours_spin.value_changed.connect(get_time);
            minutes_spin.value_changed.connect(get_time);
            seconds_spin.value_changed.connect(get_time);
            // get initial wallpaperfolder default/custom
            string initialwalls = wallstreet_settings.get_string(
                "wallpaperfolder"
            );
            bool testwallfolder = initialwalls == default_folder;
            if (!testwallfolder) {
                dir_entry.set_text(initialwalls);
            }
            toggle_defaultwalls.set_active(testwallfolder);
            toggle_customwall_widgets(testwallfolder);
            // connect afterwards
            toggle_defaultwalls.toggled.connect(manage_direntry);
            // fetch run wallstreet
            toggle_wprunner.set_active(
                wallstreet_settings.get_boolean("runwallstreet")
            );
        }

        private void manage_direntry (ToggleButton button) {
            bool active = button.get_active();
            toggle_customwall_widgets(active);
            if (active) {
                dir_entry.set_text("");
                wallstreet_settings.set_string("wallpaperfolder", default_folder);
            }
        }

        private void toggle_customwall_widgets (bool newstate) {
            dir_entry.set_sensitive(!newstate);
            set_customtwalls.set_sensitive(!newstate);
        }

        private void get_time () {
            /* 
            convert hrs/mins/secs to plain seconds, 
            update time interval setting
            */
            int hrs = (int)hours_spin.get_value();
            int mins = (int)minutes_spin.get_value();
            int secs = (int)seconds_spin.get_value();
            int time_in_seconds = (hrs * 3600) + (mins * 60) + secs;
            // don't allow < 5
            if (time_in_seconds <= 5) {
                time_in_seconds = 5;
            }
            wallstreet_settings.set_int("switchinterval", time_in_seconds);
        }

        private void divide_time () {
            // on window initiation, spread seconds over hrs/mins/secs
            int seconds = wallstreet_settings.get_int("switchinterval");
            int n_hrs = seconds / 3600; //
            int rem_minutes = (int)remainder(seconds, 3600);
            if (rem_minutes < 0) {rem_minutes = 3600 + rem_minutes;}
            int n_mins = rem_minutes / 60; //
            int n_secs = (int)remainder(seconds, 60); //
            if (n_secs < 0) {n_secs = 60 + n_secs;}
            hours_spin.set_value((double)n_hrs);
            minutes_spin.set_value((double)n_mins);
            seconds_spin.set_value((double)n_secs);
        }

        private void set_margins (Grid maingrid) {
            // I admit, lazy layout
            int[,] corners = {
                {0, 0}, {100, 0}, {2, 0}, {0, 100}, {100, 100}
            };
            int lencorners = corners.length[0];
            for (int i=0; i < lencorners; i++) {
                var spacelabel = new Label("\t");
                maingrid.attach(
                    spacelabel, corners[i, 0], corners[i, 1], 1, 1
                );
            }
        }

        private void get_directory (Button button) {
            // filechooser to set new wallpaper dir
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                "Select a directory", null, Gtk.FileChooserAction.SELECT_FOLDER,
                "Cancel", Gtk.ResponseType.CANCEL, "Use",
                Gtk.ResponseType.ACCEPT
                );
                if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                    string newpath = chooser.get_uri ().replace("file://", "");
                    wallstreet_settings.set_string("wallpaperfolder", newpath);
                    dir_entry.set_text(newpath);
                }
		    chooser.close ();
        }
    }

    public static void main (string[] args) {
        Gtk.init(ref args);
        wallstreet_settings = new GLib.Settings(
            "org.ubuntubudgie.budgie-wallstreet"
        );
        var controls = new ControlsWindow();
        controls.show_all();
        Gtk.main();
    }
}