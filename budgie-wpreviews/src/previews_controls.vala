using Gtk;

/*
Budgie WindowPreviews
Author: Jacob Vlijm
Copyright © 2017-2021 Ubuntu Budgie Developers
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

    ExtrasDaemon client;

    [DBus (name = "org.UbuntuBudgie.ExtrasDaemon")]
    interface ExtrasDaemon : Object {
        public abstract bool ReloadShortcuts () throws Error;
    }

    private void setup_client () {
        try {
            client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ExtrasDaemon",
                ("/org/ubuntubudgie/extrasdaemon")
            );
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }


    class ControlsWindow : Gtk.Window {

        Grid maingrid;
        ToggleButton toggle_previews;

        public ControlsWindow () {

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
            var toggle_showtooltips = new Gtk.CheckButton.with_label(
                _("Show window full name in tooltip")
            );
            var ok_button = new Button.with_label("Close");
            ok_button.clicked.connect(Gtk.main_quit);
            var empty = new Label("");
            maingrid.attach(toggle_previews, 1, 1, 1, 1);
            maingrid.attach(toggle_allworkspaces, 1, 2, 1, 1);
            maingrid.attach(toggle_showtooltips, 1, 3, 1, 1);
            maingrid.attach(empty, 1, 3, 1, 1);
            toggle_previews.set_active(get_currsetting("enable-previews"));
            toggle_allworkspaces.set_active(get_currsetting("allworkspaces"));
            toggle_showtooltips.set_active(get_currsetting("showtooltips"));
            toggle_previews.toggled.connect ( () => {
                update_settings(toggle_previews, "enable-previews");
                bool newactive = toggle_previews.get_active();
                check_onpreviews(newactive);
            });
            toggle_allworkspaces.toggled.connect ( () => {
                update_settings(toggle_allworkspaces, "allworkspaces");
            });
            toggle_showtooltips.toggled.connect ( () => {
                update_settings(toggle_showtooltips, "showtooltips");
            });
            maingrid.attach(ok_button, 99, 99, 1, 1);
            this.destroy.connect(Gtk.main_quit);
            setup_client();
        }

        private void check_onpreviews(bool start_services) {

            GLib.Timeout.add(250, () => {
                try {
                    if (start_services) {
                        bool daemonruns = procruns("previews_daemon");
                        bool creatorruns = procruns("previews_creator");
                        bool runpreviews = get_currsetting("enable-previews");
                        if (runpreviews) {
                            if (!daemonruns) {
                                string cm = Config.PREVIEWS_DIR + "/previews_daemon";
                                Process.spawn_command_line_sync(cm);
                            }
                            if (!creatorruns) {
                                string cm = Config.PREVIEWS_DIR + "/previews_creator";
                                Process.spawn_command_line_sync(cm);
                            }
                        }
                    }
                    client.ReloadShortcuts();
                }
                catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
                return false;
            });
        }

        private bool procruns (string processname) {
            string cmd = Config.PACKAGE_BINDIR + @"/pgrep -f $processname";
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