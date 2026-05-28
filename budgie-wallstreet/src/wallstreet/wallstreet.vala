/*
Budgie WallStreet
Author: Jacob Vlijm
Copyright © 2017 Ubuntu Budgie Developers
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
    DBusConnection? system_bus;
    int n_images;
    string currwall;
    bool lockscreen_sync;
    FileMonitor walldir_monitor;
    GenericArray<string> getlist;
    uint currindex;
    string wallpaperfolder;
    int curr_seconds;
    int switchinterval;
    bool randomwall;
    bool timeofday_enabled;
    string daytime_wallpaper;
    string nighttime_wallpaper;
    int daytime_start;
    int nighttime_start;
    bool last_was_daytime;

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
        timeofday_enabled = settings.get_boolean("timeofday-enabled");
        daytime_wallpaper = settings.get_string("daytime-wallpaper");
        nighttime_wallpaper = settings.get_string("nighttime-wallpaper");
        daytime_start = settings.get_int("daytime-start");
        nighttime_start = settings.get_int("nighttime-start");
        last_was_daytime = is_daytime();

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

        // apply time-of-day wallpaper after resume from suspend or on start
        if (timeofday_enabled) {
            apply_timeofday();
            setup_sleep_monitor();
        }

        GLib.Timeout.add_seconds(1, ()=> {
            // check for time-of-day wallpaper transition
            if (timeofday_enabled) {
                check_timeofday();
            }

            // after switchinterval, change wallpaper (skip if timeofday is active)
            if (!timeofday_enabled && curr_seconds >= switchinterval) {
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
            case "timeofday-enabled":
                timeofday_enabled = settings.get_boolean("timeofday-enabled");
                if (timeofday_enabled) {
                    apply_timeofday();
                    setup_sleep_monitor();
                }
                break;
            case "daytime-wallpaper":
                daytime_wallpaper = settings.get_string("daytime-wallpaper");
                break;
            case "nighttime-wallpaper":
                nighttime_wallpaper = settings.get_string("nighttime-wallpaper");
                break;
            case "daytime-start":
                daytime_start = settings.get_int("daytime-start");
                break;
            case "nighttime-start":
                nighttime_start = settings.get_int("nighttime-start");
                break;
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

    private void apply_timeofday () {
        bool currently_daytime = is_daytime();
        last_was_daytime = currently_daytime;
        string target = currently_daytime ? daytime_wallpaper : nighttime_wallpaper;
        if (target != "") {
            set_wallpaper(target);
            curr_seconds = 0;
        }
    }

    private bool is_daytime () {
        int hour = new DateTime.now_local().get_hour();
        return hour >= daytime_start && hour < nighttime_start;
    }

    private void check_timeofday () {
        bool currently_daytime = is_daytime();
        if (currently_daytime == last_was_daytime) {
            return;
        }
        apply_timeofday();
    }

    private void setup_sleep_monitor () {
        try {
            if (system_bus != null) {
                return;
            }
            system_bus = Bus.get_sync(BusType.SYSTEM);
            system_bus.signal_subscribe(
                "org.freedesktop.login1",
                "org.freedesktop.login1.Manager",
                "PrepareForSleep",
                "/org/freedesktop/login1",
                null,
                DBusSignalFlags.NONE,
                on_prepare_for_sleep
            );
        } catch (Error e) {
            warning("Could not subscribe to sleep signal: %s\n", e.message);
        }
    }

    private void on_prepare_for_sleep (DBusConnection conn, string? sender,
                                       string path, string iface, string signal,
                                       Variant params) {
        bool going_to_sleep;
        params.get("(b)", out going_to_sleep);
        if (!going_to_sleep && timeofday_enabled) {
            // waking up — reapply after a short delay to let the desktop settle
            GLib.Timeout.add(2000, () => {
                apply_timeofday();
                return false;
            });
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

    private uint get_initialwallpaperindex (GenericArray<string> gotlist) {
        // on start, see if we can pick up wallpaper index from where we were
        currwall = wallpapersettings.get_string("picture-uri").replace(
            "file:///", ""
        );
        uint index = 0;
        bool found = gotlist.find_with_equal_func(currwall, str_equal, out index);
        if (!found) {
            index = 0;
        }
        return index;
    }

    private GenericArray<string> walls(string directory) {
        // get wallpapers from dir
        var images=new GenericArray<string>();
        try {
            var dr = Dir.open(directory);
            string ? filename = null;
            while ((filename = dr.read_name()) != null) {
              string addpic = Path.build_filename(directory, filename);
              images.add(addpic);
            }
        } catch (FileError err) {
            // on error (dir not found), reset wallpaperfolder
            warning(err.message);
            settings.reset("wallpaperfolder");
            images = new GenericArray<string>();
        }
        n_images = images.length;
        if (n_images == 0) {
            images.add(settings.get_string("fallbackwallpaper"));
        }
        else {
            images.sort(strcmp);
        }
        return images;
    }
}