
/*
Budgie WindowPreviews
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


namespace previews_triggers {

    /*
    possible args:
    - "current" (show only current apps)
    - "previous" (go one tile reverse)

    this executable first creates a trigger file -allappstrigger- if no arg is
    set, or -triggercurrent- if the arg "current" is set. this file will
    trigger the previews daemon to show previews of all apps or only current

    if the previews window exists however (and either one of the above
    triggers), this executabel creates an additional -nexttrigger- if not
    "previous" is set as arg, or -previoustrigger- if "previous" is set as arg
     */


    public static void main (string[] args) {

        // user
        string user = Environment.get_user_name();
        // files
        File allappstrigger = File.new_for_path(
            "/tmp/".concat(user, "_prvtrigger_all")
        );
        File nexttrigger = File.new_for_path(
            "/tmp/".concat(user, "_nexttrigger")
        );
        File previoustrigger = File.new_for_path(
            "/tmp/".concat(user, "_previoustrigger")
        );
        File triggercurrent = File.new_for_path(
            "/tmp/".concat(user, "_prvtrigger_current")
        );

        File trg = nexttrigger;
        if (allappstrigger.query_exists() || triggercurrent.query_exists()) {
            trg = nexttrigger;
            if (check_args (args, "previous")) {
                trg = previoustrigger;
            }
        }
        else {
            trg = allappstrigger;
            if (check_args(args, "current")) {
                trg = triggercurrent;
            }
        }
        create_trigger(trg);
    }

    private bool check_args (string[] args, string arg) {
        foreach (string s in args) {
            if (s == arg) {
                return true;
            }
        }
        return false;
    }

    private void create_trigger (File trigger) {
        try {
            FileOutputStream createtrigger = trigger.create (
                FileCreateFlags.PRIVATE
            );
            createtrigger.write("".data);
        }
        catch (Error e) {
        }
    }
}