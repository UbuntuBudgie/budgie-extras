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
    const string panel_schema="com.solus-project.budgie-panel";
    const string crystal_dock_global_path="/usr/share/applications/crystal-dock.desktop";
    const string appmenu_budgie_schema="org.ubuntubudgie.plugins.budgie-appmenu";
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

        private void stop_crystal_dock () {
            run_cmd("killall crystal-dock");

            string autostart_file = Environment.get_home_dir() +
                "/.config/autostart/crystal-dock.desktop";

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

        private void start_crystal_dock(bool centered=false) {
            stop_crystal_dock();

            if (! FileUtils.test(crystal_dock_global_path, FileTest.EXISTS)) {
                debug("does not exist %s", crystal_dock_global_path);
                return;
            }

            try {
                string autostart_folder = Environment.get_home_dir() +
                    "/.config/autostart/";

                if (! FileUtils.test (autostart_folder, FileTest.IS_DIR)) {
                    File folder = File.new_for_path(autostart_folder);
                    folder.make_directory();
                }

                File file = File.new_for_path(crystal_dock_global_path);
                File dest = File.new_for_path(autostart_folder + "crystal-dock.desktop");
                file.copy(dest, FileCopyFlags.OVERWRITE);
            }
            catch (Error e) {
                warning("Cannot copy: %s", e.message);
            }

            run_cmd("nohup crystal-dock &>/dev/null", true);
        }

        private void appmenu_powerstrip(bool enable) {
            var schema = GLib.SettingsSchemaSource.get_default ().lookup (appmenu_budgie_schema, true);
            if (schema == null)
                return;
            var settings = new GLib.Settings(appmenu_budgie_schema);
            settings.set_boolean("enable-powerstrip", enable);
        }

        private void appmenu_sidebar(bool enable) {
            var schema = GLib.SettingsSchemaSource.get_default ().lookup (appmenu_budgie_schema, true);
            if (schema == null)
                return;
            var settings = new GLib.Settings(appmenu_budgie_schema);
            settings.set_boolean("enable-favorites", enable);
        }

        private void appmenu_categoryview(bool show_category) {
            var schema = GLib.SettingsSchemaSource.get_default ().lookup (appmenu_budgie_schema, true);
            if (schema == null)
                return;
            var settings = new GLib.Settings(appmenu_budgie_schema);
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
            run_cmd ("nohup budgie-panel --reset --reset-raven --replace &>/dev/null", true);
        }

        public void reset(string layout_name) {

            stop_crystal_dock();
            appmenu_powerstrip(false);
            appmenu_categoryview(false);
            appmenu_sidebar(false);
            leftside_buttons(false);
            show_nemo_menu(false);

            switch (layout_name) {
                case "ubuntubudgie": {
                    start_crystal_dock(true);
                    appmenu_sidebar(true);
                    break;
                }
                case "classicubuntubudgie": {
                    start_crystal_dock(true);
                    break;
                }
                case "cupertino": {
                    start_crystal_dock(true);
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
                case "eleven": {
                    appmenu_powerstrip(true);
                    break;
                }
                case "chrome": {
                    // no customisations needed
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
