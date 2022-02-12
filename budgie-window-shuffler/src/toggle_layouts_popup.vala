/*
* ShufflerIII
* Author: Jacob Vlijm
* Copyright © 2017-2022 Ubuntu Budgie Developers
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

// valac --pkg gio-2.0

namespace ToggleShufflerGUI {

    private void create_trigger (File trigger, bool fromcontrol) {
        string arg = "";
        if (fromcontrol) {
            arg = "fromcontrol";
        }
        try {
            FileOutputStream createtrigger = trigger.create (
                FileCreateFlags.PRIVATE
            );
            createtrigger.write(arg.data);
        }
        catch (Error e) {
        }
    }

    private string create_dirs_file (string subpath, bool ishome = false) {
        // defines, and if needed, creates directory for layouts
        string homedir = "";
        if (ishome) {
            homedir = Environment.get_home_dir();
        }
        string fullpath = GLib.Path.build_path(
            GLib.Path.DIR_SEPARATOR_S, homedir, subpath
        );
        GLib.File file = GLib.File.new_for_path(fullpath);
        try {
            file.make_directory_with_parents();
        }
        catch (Error e) {
            /* the directory exists, nothing to be done */
        }
        return fullpath;
    }

    public static void main (string[] args) {
        bool fromcontrol = args.length != 1 && args[1] == "fromcontrol";
        print(@"$fromcontrol\n");

        // make sure triggerdir exists
        string username = Environment.get_user_name();
        string triggerpath = create_dirs_file(
            "/tmp/".concat(username, "_shufflertriggers")
        );
        // then define trigger
        File popuptrigger = File.new_for_path(triggerpath.concat("/layoutspopup"));
        bool popuptriggerexists = popuptrigger.query_exists();
        if (!popuptriggerexists) {
             create_trigger(popuptrigger, fromcontrol);
            }
        else {
            try {
                popuptrigger.delete();
            }
            catch (Error e) {
            }
        }
    }
}