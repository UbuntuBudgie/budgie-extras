/*
* Layouts
* Author: David Mohammed
* Copyright © 2020 Ubuntu Budgie Developers
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

namespace Layouts {

    const string plank_schema="net.launchpad.plank";
    const string plank_settings_schema="net.launchpad.plank.dock.settings";
    const string plank_path="/net/launchpad/plank/docks/xyz/";
    const string panel_schema="com.solus-project.budgie-panel";
    const string plank_global_path="/usr/share/applications/plank.desktop";
    const string appmenu_elementary_schema="io.elementary.desktop.wingpanel.applications-menu";
    const string budgiewm_schema="com.solus-project.budgie-wm";
    const string nemo_window_schema="org.nemo.window-state";
    const string nemo_preferences_schema="org.nemo.preferences";

    public class LayoutsManager : Object {

        private void run_cmd(string commandline, bool async=false) {
            try {
                if (async) {
                    GLib.Process.spawn_command_line_async (commandline);
                }
                else {
                    GLib.Process.spawn_command_line_sync (commandline);
                }

            } catch (SpawnError e) {
                warning("Issue when executing %s", e.message);
            }

        }

        private void stop_plank () {
            run_cmd("killall plank");

            string autostart_file = Environment.get_home_dir() +
                "/.config/autostart/plank.desktop";

            if (! FileUtils.test(autostart_file, FileTest.EXISTS)) {
                debug("does not exist %s", autostart_file);
                return;
            }

            try {
                File file = File.new_for_path(autostart_file);
                file.delete();
            }
            catch (Error e) {
                warning("Cannot delete: %s", e.message);
            }
        }

        private void show_nemo_menu(bool show_menu) {
            var schema = GLib.SettingsSchemaSource.get_default ().lookup (nemo_window_schema, true);
            if (schema == null)
                return;
            var preference_settings = new GLib.Settings(nemo_preferences_schema);
            preference_settings.set_boolean("disable-menu-warning", true);
            GLib.Timeout.add(500, () => {
                /* add a little wait to allow nemo to chew on the previous dconf change */
                var window_settings = new GLib.Settings(nemo_window_schema);
                window_settings.set_boolean("start-with-menu-bar", show_menu);
                preference_settings.set_boolean("disable-menu-warning", false);
                return false;
            });
        }

        private void start_plank(bool centered=false) {
            stop_plank();

            if (! FileUtils.test(plank_global_path, FileTest.EXISTS)) {
                debug("does not exist %s", plank_global_path);
                return;
            }

            if (centered) {
                var plank_settings = new GLib.Settings(plank_schema);
                var docks = plank_settings.get_strv("enabled-docks");

                foreach (string dock in docks) {
                    var path = plank_path.replace("xyz", dock);
                    var settings = new GLib.Settings.with_path(plank_settings_schema, path);

                    settings.set_string("position", "bottom");
                    settings.set_string("theme", "Transparent");
                    settings.set_int("icon-size", 32);
                    settings.set_int("hide-delay", 500);
                    settings.set_string("hide-mode", "window-dodge");
                    settings.set_boolean("zoom-enabled", true);
                    break; // we assume the first dock is the primary
                }
            }

            try {
                string autostart_folder = Environment.get_home_dir() +
                    "/.config/autostart/";

                if (! FileUtils.test (autostart_folder, FileTest.IS_DIR)) {
                    File folder = File.new_for_path(autostart_folder);
                    folder.make_directory();
                }

                File file = File.new_for_path(plank_global_path);
                File dest = File.new_for_path(autostart_folder + "plank.desktop");
                file.copy(dest, FileCopyFlags.OVERWRITE);
            }
            catch (Error e) {
                warning("Cannot copy: %s", e.message);
            }

            run_cmd("nohup plank &>/dev/null", true);
        }

        private void appmenu_powerstrip(bool enable) {
            var schema = GLib.SettingsSchemaSource.get_default ().lookup (appmenu_elementary_schema, true);
            if (schema == null)
                return;
            var settings = new GLib.Settings(appmenu_elementary_schema);
            settings.set_boolean("enable-powerstrip", enable);
        }

        private void appmenu_categoryview(bool show_category) {
            var schema = GLib.SettingsSchemaSource.get_default ().lookup (appmenu_elementary_schema, true);
            if (schema == null)
                return;
            var settings = new GLib.Settings(appmenu_elementary_schema);
            settings.set_boolean("use-category", show_category);
        }

        private void leftside_buttons(bool leftside=true) {
            var settings = new GLib.Settings(budgiewm_schema);
            if (leftside) {
                settings.set_string("button-style", "left");
            }
            else {
                settings.set_string("button-style", "traditional");
            }
        }

        private void reset_panel() {
            run_cmd ("nohup budgie-panel --reset --replace &>/dev/null", true);
        }

        public void reset(string layout_name) {

            stop_plank();
            appmenu_powerstrip(false);
            appmenu_categoryview(false);
            leftside_buttons(false);
            show_nemo_menu(false);

            switch (layout_name) {
                case "ubuntubudgie": {
                    start_plank(true);
                    break;
                }
                case "classicubuntubudgie": {
                    start_plank(true);
                    break;
                }
                case "cupertino": {
                    start_plank(true);
                    appmenu_powerstrip(true);
                    appmenu_categoryview(true);
                    leftside_buttons();
                    show_nemo_menu(true);
                    break;
                }
                case "theone": {
                    leftside_buttons();
                    show_nemo_menu(true);
                    break;
                }
                case "redmond": {
                    appmenu_powerstrip(true);
                    appmenu_categoryview(true);
                    break;
                }
                default: {
                    break;
                }
            }
            var settings = new GLib.Settings(panel_schema);
            settings.set_string("layout", layout_name);
            Timeout.add_seconds(1, () => {
                reset_panel();
                return false;
            });
        }
    }
}
