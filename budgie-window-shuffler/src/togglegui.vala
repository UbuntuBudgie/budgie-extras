/*
* ShufflerII
* Author: Jacob Vlijm
* Copyright © 2017-2020 Ubuntu Budgie Developers
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

namespace ToggleShufflerGUI {

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

    public static void main (string[] args) {
        string user = Environment.get_user_name();
        File gridtrigger = File.new_for_path(
            "/tmp/".concat(user, "_gridtrigger")
        );
        bool gridtriggerexists = gridtrigger.query_exists();
        if (!gridtriggerexists) {
             create_trigger(gridtrigger);
            }
        else {
            try {
                gridtrigger.delete();
            }
            catch (Error e) {
            }
        }
    }
}