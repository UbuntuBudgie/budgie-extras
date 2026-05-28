using Gtk;
using Math;

// valac -X -lm --pkg gtk+-3.0

/*
Budgie WallStreet
Author: Jacob Vlijm
Copyright © 2017 Ubuntu Budgie Developers
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

namespace WallStreetControls {

    GLib.Settings wallstreet_settings;

    class ControlsWindow : Gtk.Window {

        SpinButton hours_spin;
        SpinButton minutes_spin;
        SpinButton seconds_spin;
        Entry dir_entry;
        string default_folder;
        Button set_customtwalls;
        ToggleButton toggle_random;
        ToggleButton toggle_synclockscreen;
        ToggleButton toggle_wprunner;
        CheckButton toggle_timeofday;
        Entry daytime_entry;
        Entry nighttime_entry;
        Button browse_daytime;
        Button browse_nighttime;
        SpinButton daytime_start_spin;
        SpinButton nighttime_start_spin;
        Grid timeofday_grid;
        Grid rotation_grid;
        string runinstruction;

        public ControlsWindow () {
            initialiseLocaleLanguageSupport();
            this.set_position(Gtk.WindowPosition.CENTER);
            // define the name of the application
            this.title = (_("WallStreet Control"));
            var maingrid = new Gtk.Grid();
            this.add(maingrid);
            set_margins(maingrid);
            // misc
            default_folder = wallstreet_settings.get_default_value(
                "wallpaperfolder"
            ).get_string();
            // instruction to autostart the application

            runinstruction = (_("Run WallStreet"));
            toggle_wprunner = new Gtk.CheckButton.with_label(
                runinstruction
            );
            maingrid.attach(toggle_wprunner, 1, 1, 100, 1);

            toggle_synclockscreen = new Gtk.CheckButton.with_label(
                (_("Sync to lock-screen"))
            );

            maingrid.attach(toggle_synclockscreen, 1, 2, 1, 1);

            // rotation-specific widgets in their own grid
            rotation_grid = new Gtk.Grid();
            rotation_grid.set_row_spacing(6);
            maingrid.attach(rotation_grid, 1, 3, 99, 1);

            var rotation_separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            rotation_grid.attach(rotation_separator, 0, 0, 99, 1);

            toggle_random = new Gtk.CheckButton.with_label(
                (_("Use random wallpaper"))
            );
            rotation_grid.attach(toggle_random, 0, 1, 1, 1);

            var toggle_defaultwalls = new Gtk.CheckButton.with_label(
                (_("Use default wallpapers"))
            );
            rotation_grid.attach(toggle_defaultwalls, 0, 2, 1, 1);

            // custom folder section
            Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            rotation_grid.attach(box, 0, 3, 99, 1);
            set_customtwalls = new Gtk.Button.with_label(
                (_("Browse"))
            );
            set_customtwalls.clicked.connect(get_directory);
            box.pack_start(set_customtwalls, false, false, 10);
            dir_entry = new Gtk.Entry();
            dir_entry.set_width_chars(35);
            dir_entry.set_editable(false);
            box.pack_start(dir_entry, false, false, 0);
            box.pack_start(new Label("\t"), false, false, 0);

            // time settings section
            var time_label = new Label("\n" + (_("Change interval")) + "\n");
            time_label.set_xalign(0);
            rotation_grid.attach(time_label, 0, 4, 1, 1);
            var timegrid = new Gtk.Grid();
            rotation_grid.attach(timegrid, 0, 5, 2, 3);
            var hours_label = new Label((_("Hours")) + "\t");
            hours_label.set_xalign(0);
            timegrid.attach(hours_label, 0, 0, 1, 1);
            hours_spin = new Gtk.SpinButton.with_range(0, 24, 1);
            timegrid.attach(hours_spin, 1, 0, 1, 1);
            var minutes_label = new Label((_("Minutes")) + "\t");
            minutes_label.set_xalign(0);
            timegrid.attach(minutes_label, 0, 1, 1, 1);
            minutes_spin = new Gtk.SpinButton.with_range(0, 59, 1);
            timegrid.attach(minutes_spin, 1, 1, 1, 1);
            var seconds_label = new Label((_("Seconds")) + "\t");
            seconds_label.set_xalign(0);
            timegrid.attach(seconds_label, 0, 2, 1, 1);
            seconds_spin = new Gtk.SpinButton.with_range(0, 59, 1);
            timegrid.attach(seconds_spin, 1, 2, 1, 1);

            // time of day section
            var timeofday_separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            maingrid.attach(timeofday_separator, 1, 4, 99, 1);

            toggle_timeofday = new Gtk.CheckButton.with_label(
                (_("Use time of day wallpapers"))
            );
            maingrid.attach(toggle_timeofday, 1, 5, 99, 1);

            timeofday_grid = new Gtk.Grid();
            timeofday_grid.set_row_spacing(6);
            timeofday_grid.set_column_spacing(10);
            maingrid.attach(timeofday_grid, 1, 6, 99, 1);

            var daytime_start_label = new Label((_("Daytime starts at hour")) + "\t");
            daytime_start_label.set_xalign(0);
            timeofday_grid.attach(daytime_start_label, 0, 0, 1, 1);
            daytime_start_spin = new Gtk.SpinButton.with_range(0, 23, 1);
            timeofday_grid.attach(daytime_start_spin, 1, 0, 1, 1);

            var nighttime_start_label = new Label((_("Nighttime starts at hour")) + "\t");
            nighttime_start_label.set_xalign(0);
            timeofday_grid.attach(nighttime_start_label, 0, 1, 1, 1);
            nighttime_start_spin = new Gtk.SpinButton.with_range(0, 23, 1);
            timeofday_grid.attach(nighttime_start_spin, 1, 1, 1, 1);

            var daytime_label = new Label((_("Daytime wallpaper")) + "\t");
            daytime_label.set_xalign(0);
            timeofday_grid.attach(daytime_label, 0, 2, 1, 1);
            Box daytime_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            timeofday_grid.attach(daytime_box, 1, 2, 1, 1);
            browse_daytime = new Gtk.Button.with_label((_("Browse")));
            daytime_box.pack_start(browse_daytime, false, false, 0);
            daytime_entry = new Gtk.Entry();
            daytime_entry.set_width_chars(35);
            daytime_entry.set_editable(false);
            daytime_box.pack_start(daytime_entry, false, false, 10);

            var nighttime_label = new Label((_("Nighttime wallpaper")) + "\t");
            nighttime_label.set_xalign(0);
            timeofday_grid.attach(nighttime_label, 0, 3, 1, 1);
            Box nighttime_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            timeofday_grid.attach(nighttime_box, 1, 3, 1, 1);
            browse_nighttime = new Gtk.Button.with_label((_("Browse")));
            nighttime_box.pack_start(browse_nighttime, false, false, 0);
            nighttime_entry = new Gtk.Entry();
            nighttime_entry.set_width_chars(35);
            nighttime_entry.set_editable(false);
            nighttime_box.pack_start(nighttime_entry, false, false, 10);

            // fetch initial values
            bool timeofday_active = wallstreet_settings.get_boolean("timeofday-enabled");
            toggle_timeofday.set_active(timeofday_active);
            daytime_start_spin.set_value(wallstreet_settings.get_int("daytime-start"));
            nighttime_start_spin.set_value(wallstreet_settings.get_int("nighttime-start"));
            string dwall = wallstreet_settings.get_string("daytime-wallpaper");
            if (dwall != "") daytime_entry.set_text(dwall);
            string nwall = wallstreet_settings.get_string("nighttime-wallpaper");
            if (nwall != "") nighttime_entry.set_text(nwall);
            toggle_timeofday_widgets(timeofday_active);

            // connect signals
            toggle_timeofday.toggled.connect(manage_boolean);
            browse_daytime.clicked.connect(get_daytime_wallpaper);
            browse_nighttime.clicked.connect(get_nighttime_wallpaper);
            daytime_start_spin.value_changed.connect(() => {
                wallstreet_settings.set_int(
                    "daytime-start", (int)daytime_start_spin.get_value()
                );
            });
            nighttime_start_spin.value_changed.connect(() => {
                wallstreet_settings.set_int(
                    "nighttime-start", (int)nighttime_start_spin.get_value()
                );
            });

            var ok_button = new Button.with_label((_("Close")));
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
            toggle_wprunner.toggled.connect(manage_boolean);
            // fetch toggle_random
            toggle_random.set_active(
                wallstreet_settings.get_boolean("random")
            );
            toggle_random.toggled.connect(manage_boolean);
            // fetch toggle_synclockscreen
            toggle_synclockscreen.set_active(
                wallstreet_settings.get_boolean("lockscreensync")
            );
            toggle_synclockscreen.toggled.connect(manage_boolean);
        }

        /**
         * Ensure translations are displayed correctly
         * according to the locale
         */
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

        private void manage_boolean (ToggleButton button) {
            if (button == toggle_random) {
                wallstreet_settings.set_boolean(
                    "random", button.get_active()
                );
            }
            else if (button == toggle_synclockscreen) {
                wallstreet_settings.set_boolean(
                    "lockscreensync", button.get_active()
                );
            }
            else if (button == toggle_timeofday) {
                bool active = button.get_active();
                wallstreet_settings.set_boolean("timeofday-enabled", active);
                toggle_timeofday_widgets(active);
            }
            else if (button == toggle_wprunner) {
                bool newsetting = button.get_active();
                wallstreet_settings.set_boolean(
                    "runwallstreet", newsetting
                );
                if (newsetting) {
                    check_firstrunwarning();
                }
                else {
                    toggle_wprunner.set_label(runinstruction);
                }
            }
        }

        private void toggle_timeofday_widgets (bool active) {
            timeofday_grid.set_sensitive(active);
            rotation_grid.set_sensitive(!active);
        }

        private void check_firstrunwarning() {
            /*
            / 0.1 dec after gsettings change check if process is running
            / if not -> show message in label
            */
            GLib.Timeout.add(100, () => {
                bool runs = processruns("/budgie-wallstreet/wallstreet");
                if (!runs) {
                    toggle_wprunner.set_label(
                        runinstruction + "\t" + (_(
                            "Please log out/in to initialize"
                        ))
                    );
                }
                return false;
            });
        }

        private bool processruns (string application) {
            string cmd = Config.PACKAGE_BINDIR + "/pgrep -f " + application;
            string output;
            try {
                GLib.Process.spawn_command_line_sync(cmd, out output);
                if (output != "") {
                    // remove trailing \n, does not count
                    string[] pids = output[0:output.length-1].split("\n");
                    int n_pids = pids.length;
                    if (n_pids >= 2) {
                        return true;
                    }
                    else {
                        return false;
                    }
                }
            }
            /* on an (unlikely to happen) exception, show the message */
            catch (SpawnError e) {
                return false;
            }
            return false;
        }

        private void get_daytime_wallpaper (Button button) {
            string? path = pick_image_file();
            if (path != null) {
                wallstreet_settings.set_string("daytime-wallpaper", path);
               daytime_entry.set_text(path);
            }
        }

        private void get_nighttime_wallpaper (Button button) {
            string? path = pick_image_file();
            if (path != null) {
                wallstreet_settings.set_string("nighttime-wallpaper", path);
                nighttime_entry.set_text(path);
            }
        }

        private string? pick_image_file () {
            string? result = null;
            var chooser = new Gtk.FileChooserDialog(
                (_("Select a wallpaper")),
                null, Gtk.FileChooserAction.OPEN,
                (_("Cancel")), Gtk.ResponseType.CANCEL,
                (_("Use")), Gtk.ResponseType.ACCEPT
            );
            var filter = new Gtk.FileFilter();
            filter.set_filter_name((_("Images")));
            filter.add_mime_type("image/jpeg");
            filter.add_mime_type("image/png");
            filter.add_mime_type("image/svg+xml");
            chooser.add_filter(filter);
            if (chooser.run() == Gtk.ResponseType.ACCEPT) {
                result = chooser.get_file().get_path();
            }
            chooser.close();
            return result;
        }

        private void manage_direntry (ToggleButton button) {
            bool active = button.get_active();
            toggle_customwall_widgets(active);
            if (active) {
                dir_entry.set_text("");
                wallstreet_settings.set_string(
                    "wallpaperfolder", default_folder
                );
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
                (_("Select a directory")),
                null, Gtk.FileChooserAction.SELECT_FOLDER,
                (_("Cancel")), Gtk.ResponseType.CANCEL, (_("Use")),
                Gtk.ResponseType.ACCEPT
                );
                if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                    string newpath = chooser.get_file().get_path();
                    wallstreet_settings.set_string("wallpaperfolder", newpath);
                    dir_entry.set_text(newpath);
                }
		    chooser.close ();
        }
    }

    public static int main (string[] args) {
        Gtk.init(ref args);
        wallstreet_settings = new GLib.Settings(
            "org.ubuntubudgie.budgie-wallstreet"
        );
        var controls = new ControlsWindow();
        controls.show_all();
        Gtk.main();
        return 0;
    }
}