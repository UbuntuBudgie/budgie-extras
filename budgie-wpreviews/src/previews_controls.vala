using Gtk;

/*
Budgie WindowPreviews
Author: Jacob Vlijm
Copyright © 2017-2020 Ubuntu Budgie Developers
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

namespace PreviewsControls {

    GLib.Settings prvsettings;

    class ControlsWindow : Gtk.Window {

        Grid maingrid;
        ToggleButton toggle_previews;
        Label instruct;
        bool daemonruns;

        public ControlsWindow () {

            // check if previews runs
            daemonruns = procruns("previews_daemon");
            // bunch of styling stuff
            string previews_stylecss = """
            .explanation {
                font-style: italic;
                color: red;
            }
            """;
            Gdk.Screen screen = this.get_screen();
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(previews_stylecss);
                Gtk.StyleContext.add_provider_for_screen(
                    screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }
            // message label: log out/in
            instruct = new Label("");
            instruct.set_xalign(0);
            var sct = instruct.get_style_context();
            sct.add_class("explanation");

            this.set_position(Gtk.WindowPosition.CENTER);
            this.title = _("Previews Control");
            maingrid = new Gtk.Grid();
            this.add(maingrid);
            set_margins();
            toggle_previews = new Gtk.CheckButton.with_label(
                _("Run Previews")
            );
            var toggle_allworkspaces = new Gtk.CheckButton.with_label(
                _("Show windows of all workspaces")
            );
            var ok_button = new Button.with_label("Close");
            ok_button.clicked.connect(Gtk.main_quit);
            var empty = new Label("");
            maingrid.attach(toggle_previews, 1, 1, 1, 1);
            maingrid.attach(toggle_allworkspaces, 1, 2, 1, 1);
            maingrid.attach(empty, 1, 3, 1, 1);
            maingrid.attach(instruct, 1, 4, 1, 1);
            toggle_previews.set_active(get_currsetting("enable-previews"));
            toggle_allworkspaces.set_active(get_currsetting("allworkspaces"));
            toggle_previews.toggled.connect ( () => {
                update_settings(toggle_previews, "enable-previews");
                bool newactive = toggle_previews.get_active();
                if (newactive) {
                    check_firstrunwarning();
                }
                else {
                    instruct.set_label("");
                }
            });
            toggle_allworkspaces.toggled.connect ( () => {
                update_settings(toggle_allworkspaces, "allworkspaces");
            });

            maingrid.attach(ok_button, 99, 99, 1, 1);
            this.destroy.connect(Gtk.main_quit);
        }

        private void check_firstrunwarning() {
            /*
            / 0.1 dec after gsettings change check if process is running
            / if not -> show message in label
            */
            print("warning called\n");
            string home = Environment.get_home_dir();
            string subdir = home.concat("/.config/budgie-extras/previews/");
            File trigerdir = File.new_for_path (subdir);
            File firstrun_trigger = File.new_for_path (subdir.concat("previews_firstrun"));
            bool ranbefore = firstrun_trigger.query_exists ();

            GLib.Timeout.add(100, () => {
                if (!daemonruns && !ranbefore) {
                    instruct.set_label(_("Please log out/in to initialize"));
                    // set_textstyle(warninglabel, {"warning", "explanation"});
                    try {
                        trigerdir.make_directory_with_parents();
                        firstrun_trigger.create (FileCreateFlags.PRIVATE);
                    }
                    catch (Error e) {
                        print("Cannot create triggerfile\n");
                    }
                }
                return false;
            });
        }

        private bool procruns (string processname) {
            string cmd = @"/usr/bin/pgrep -f $processname";
            string output;
            try {
                GLib.Process.spawn_command_line_sync(cmd, out output);
                if (output == "") {
                    return false;
                }
            }
            /* on an unlike to happen exception, return true */
            catch (SpawnError e) {
                return true;
            }
            return true;
        }

        private bool get_currsetting (string key) {
            return prvsettings.get_boolean(key);
        }

        private void update_settings (ToggleButton button, string key) {
            prvsettings.set_boolean(key, button.get_active());
        }

        private void set_margins () {
            // I admit, lazy layout
            int[,] corners = {
                {0, 0}, {100, 0}, {2, 0}, {0, 100}, {100, 100}
            };
            int lencorners = corners.length[0];
            for (int i=0; i < lencorners; i++) {
                var spacelabel = new Label("\t");
                //spacelabel.set_text("");
                maingrid.attach(
                    spacelabel, corners[i, 0], corners[i, 1], 1, 1
                );
            }
        }
    }

    public static void main (string[] args) {
        Gtk.init(ref args);
        prvsettings = new GLib.Settings(
            "org.ubuntubudgie.budgie-wpreviews"
        );
        var controls = new ControlsWindow();
        controls.show_all();
        Gtk.main();
    }
}