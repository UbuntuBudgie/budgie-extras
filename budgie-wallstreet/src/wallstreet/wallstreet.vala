
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

/*
dir does not exist -> default folder (need set directory again to fix)
file is invalid -> black background
file does not exist -> black background *
no files in set dir -> set to default wallpaper *
*/

namespace WallStreet {

    Settings settings;
    Settings wallpapersettings;
    Settings locksettings;
    int n_images;
    string currwall;
    bool lockscreen_sync;

    public static int main (string[] args) {

        // loop
        MainLoop wallstreetloop = new MainLoop();
        // background / mini-app gsettings
        wallpapersettings = new Settings(
            "org.gnome.desktop.background"
        );
        settings = new Settings(
            "org.ubuntubudgie.budgie-wallstreet"
        );
        locksettings = new Settings(
            "org.gnome.desktop.screensaver"
        );
        // loop initial stuff
        int curr_seconds = 0; // cycle
        int checkseconds = 0; // check
        int? switchinterval = null;
        bool randomwall = false;
        lockscreen_sync = false;
        // pick up from previously last wallpaper on startup:
        string wallpaperfolder = settings.get_string("wallpaperfolder"); 
        string[] getlist = walls(wallpaperfolder);
        int currindex = get_initialwallpaperindex() + 1;
        
        GLib.Timeout.add_seconds(1, ()=> {
            // check interval & folder settings once per 5 sec
            if (checkseconds == 0) {
                randomwall = settings.get_boolean("random");
                lockscreen_sync = settings.get_boolean("lockscreensync");
                switchinterval = settings.get_int("switchinterval");
                string previouswalls = wallpaperfolder;
                wallpaperfolder = settings.get_string("wallpaperfolder");
                // on change, scan new folder, start from 0, set first image
                if (wallpaperfolder != previouswalls) {
                    getlist = walls(wallpaperfolder);
                    currindex = 0;
                    currwall = getlist[currindex];
                    set_wallpaper(currwall);
                }
            }
            // check every n-seconds (5)
            checkseconds += 1;
            if (checkseconds == 5) {
                checkseconds = 0;
            }
            // after switchinterval, change wallpaper
            if (curr_seconds >= switchinterval) {
                if (randomwall) {
                    int random_int = Random.int_range(0,n_images);
                    currwall = getlist[random_int];
                }
                else {
                    currwall = getlist[currindex];
                }
                set_wallpaper(currwall);
                currindex += 1;
                curr_seconds = 0;
            }
            // after loop cycle, refresh list and start over
            if (currindex == n_images) {
                currindex = 0;
                getlist = walls(wallpaperfolder);
            }
            curr_seconds += 1;
            return true;
        });
        wallstreetloop.run();
        return 0;
    }

    private void set_wallpaper (string newwall) {
        wallpapersettings.set_string(
            "picture-uri", "file:///" + newwall
        );
        if (lockscreen_sync) {
            locksettings.set_string(
                "picture-uri", "file:///" + newwall
            );
        }
    }

    private int get_stringindex (string s, string[] arr) {
        for (int i=0; i < arr.length; i++) {
            if(s == arr[i]) return i;
        } return -1;
    }

    private int get_initialwallpaperindex () {
        currwall = wallpapersettings.get_string("picture-uri").replace(
            "file:///", ""
        );
        string wallpaperfolder = settings.get_string("wallpaperfolder");
        int currindex = get_stringindex(currwall, walls(wallpaperfolder));
        if (currindex == -1) {
            currindex = 0;
        }
        return currindex;
    }

    private string[] walls(string directory) {
        // get wallpapers from dir
        string[] images = {};
        try {
            var dr = Dir.open(directory);
            string ? filename = null;
            while ((filename = dr.read_name()) != null) {
              string addpic = Path.build_filename(directory, filename);
              images += addpic;
            }
        } catch (FileError err) {
            // on error (dir not found), reset wallpaperfolder
            stderr.printf(err.message);
            settings.reset("wallpaperfolder");
            return {""};
        }
        n_images = images.length;
        if (n_images == 0) {
            string onlywall = settings.get_string("fallbackwallpaper");
            n_images = 1;
            return {onlywall};
        }
        return images;
    }
}