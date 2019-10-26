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
no files in set dir -> set to default wallpaper *
*/

namespace WallStreet {

    Settings settings;
    Settings wallpapersettings;
    Settings locksettings;
    int n_images;
    string currwall;
    bool lockscreen_sync;
    FileMonitor walldir_monitor;
    string[] getlist;
    int currindex;
    string wallpaperfolder;
    int curr_seconds;
    int switchinterval;
    bool randomwall;


    public static int main (string[] args) {

        // mainloop
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

        // wait for settings change
        settings.changed.connect(update_settings);

        // fetch initial settings values
        switchinterval = settings.get_int("switchinterval");
        wallpaperfolder = settings.get_string("wallpaperfolder");
        randomwall = settings.get_boolean("random");
        lockscreen_sync = settings.get_boolean("lockscreensync");

        // loop start at zero
        curr_seconds = 0;

        // pick up from previously set wallpaper on startup (if in list):
        getlist = walls(wallpaperfolder);
        currindex = get_initialwallpaperindex(getlist);
        set_wallpaper(getlist[currindex]);
        currindex += 1;

        // initiate FileMonitor
        walldir_monitor = getwallmonitor(wallpaperfolder);
        walldir_monitor.changed.connect(rescan_currdir);

        GLib.Timeout.add_seconds(1, ()=> {

            // after switchinterval, change wallpaper
            if (curr_seconds >= switchinterval) {
                if (randomwall) {
                    int random_int = Random.int_range(0, n_images);
                    currwall = getlist[random_int];
                }
                else {
                    currwall = getlist[currindex];
                }
                set_wallpaper(currwall);
                currindex += 1;
                curr_seconds = 0;
            }
            // after loop cycle, start over
            if (currindex >= n_images) {
                currindex = 0;
            }
            curr_seconds += 1;
            return true;
        });
        wallstreetloop.run();
        return 0;
    }

    private void update_settings (string path) {
        switch (path) {
            case "wallpaperfolder":
                wallpaperfolder = settings.get_string("wallpaperfolder");
                update_wallpaperlist();
                break;
            case "switchinterval":
                switchinterval = settings.get_int("switchinterval");
                break;
            case "random":
                randomwall = settings.get_boolean("random");
                break;
            case "lockscreensync":
                lockscreen_sync = settings.get_boolean("lockscreensync");
                break;
        }
    }

    private FileMonitor? getwallmonitor (string directory) {
        File triggerdir = File.new_for_path(directory);
        try {
            walldir_monitor = triggerdir.monitor(FileMonitorFlags.NONE, null);
            return walldir_monitor;
        }
        catch (Error e) {
            return null;
        }
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

    private void rescan_currdir () {
        getlist = walls(wallpaperfolder);
        currindex = get_initialwallpaperindex(getlist);
    }

    private void update_wallpaperlist () {
        // scan wallpapers on gsettings dir change
        walldir_monitor = getwallmonitor(wallpaperfolder);
        walldir_monitor.changed.connect(rescan_currdir);
        getlist = walls(wallpaperfolder);
        currindex = 0;
        curr_seconds = 0;
        currwall = getlist[currindex];
        set_wallpaper(currwall);
        currindex += 1;
    }

    private int get_stringindex (string s, string[] arr) {
        for (int i=0; i < arr.length; i++) {
            if(s == arr[i]) return i;
        } return -1;
    }

    private int get_initialwallpaperindex (string[] gotlist) {
        // on start, see if we can pick up wallpaper index from where we were
        currwall = wallpapersettings.get_string("picture-uri").replace(
            "file:///", ""
        );
        int index = get_stringindex(currwall, gotlist);
        if (index == -1) {
            index = 0;
        }
        return index;
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