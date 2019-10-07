
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

namespace wallstreet {

    Settings settings;

    public static void main (string[] args) {

        // loop
        MainLoop wallstreetloop = new MainLoop();
        // background / mini-app gsettings
        Settings wallpapersettings = new Settings(
            "org.gnome.desktop.background"
        );
        settings = new Settings(
            "org.ubuntubudgie.budgie-wallstreet"
        );
        // loop initial stuff
        int currindex = 0; // wallpaper index from list
        int curr_seconds = 0; // cycle
        int checkseconds = 0; // check
        int? switchinterval = null;
        string? wallpaperfolder = null;
        string[]? getlist = null;
        
        GLib.Timeout.add_seconds(1, ()=> {
            // check interval & folder settings once per 5 sec
            if (checkseconds == 0) {
                switchinterval = settings.get_int("switchinterval");
                string previouswalls = wallpaperfolder;
                wallpaperfolder = settings.get_string("wallpaperfolder");
                // on change, scan new folder, start from 0, set first image
                if (wallpaperfolder != previouswalls) {
                    getlist = walls(wallpaperfolder);
                    currindex = 0;
                    string currwall = getlist[currindex];
                    wallpapersettings.set_string(
                        "picture-uri", "file:///" + currwall
                    );
                }
            }
            // check every n-seconds (5)
            checkseconds += 1;
            if (checkseconds == 5) {
                checkseconds = 0;
            }
            // after switchinterval, change wallpaper
            if (curr_seconds >= switchinterval) {
                string currwall = getlist[currindex];
                wallpapersettings.set_string(
                    "picture-uri", "file:///" + currwall
                );
                currindex += 1;
                curr_seconds = 0;
            }
            // after loop cycle, refresh list and start over
            if (currindex == getlist.length) {
                currindex = 0;
                getlist = walls(wallpaperfolder);
            }
            curr_seconds += 1;
            return true;
        });
        wallstreetloop.run();
    }

    private string[] walls(string directory) {
        // get wallpapers from dir
        string[] somestrings = {};
        try {
            var dr = Dir.open(directory);
            string ? filename = null;
            while ((filename = dr.read_name()) != null) {
              string addpic = Path.build_filename(directory, filename);
              somestrings += addpic;
            }
        } catch (FileError err) {
            // on error (dir not found), reset wallpaperfolder
            stderr.printf(err.message);
            settings.reset("wallpaperfolder");
            return {""};
        }
        return somestrings;
    }
}