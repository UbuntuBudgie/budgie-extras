using Json;

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
    bool potd_wikipedia_enabled;
    bool potd_bing_enabled;
    string potd_folder_name;
    string potd_wikipedia_last_fetch;
    string potd_bing_last_fetch;
    const string POTD_USER_AGENT = "budgie-wallstreet/1.0 (https://ubuntubudgie.org)";

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
        potd_wikipedia_enabled = settings.get_boolean("potd-wikipedia-enabled");
        potd_bing_enabled = settings.get_boolean("potd-bing-enabled");
        potd_folder_name = settings.get_string("potd-folder-name");
        potd_wikipedia_last_fetch = settings.get_string("potd-wikipedia-last-fetch");
        potd_bing_last_fetch = settings.get_string("potd-bing-last-fetch");

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

        // fetch picture(s) of the day now if due, then recheck hourly
        // N.B. actual network fetch only happens on a
        // date change, so hourly is just to catch the day rolling over
        // while the daemon keeps running)
        check_potd();
        GLib.Timeout.add_seconds(3600, ()=> {
            check_potd();
            return true;
        });

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
            case "potd-wikipedia-enabled":
                potd_wikipedia_enabled = settings.get_boolean("potd-wikipedia-enabled");
                check_potd();
                if (!timeofday_enabled) {
                    rescan_currdir();
                }
                break;
            case "potd-bing-enabled":
                potd_bing_enabled = settings.get_boolean("potd-bing-enabled");
                check_potd();
                if (!timeofday_enabled) {
                    rescan_currdir();
                }
                break;
            case "potd-folder-name":
                potd_folder_name = settings.get_string("potd-folder-name");
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

    private GenericArray<string> list_images_in_dir (string directory) {
        // plain directory lister, no fallback/error-reset side effects -
        // used to fold the picture-of-the-day folder into the rotation
        var images = new GenericArray<string>();
        try {
            var dr = Dir.open(directory);
            string ? filename = null;
            while ((filename = dr.read_name()) != null) {
                images.add(GLib.Path.build_filename(directory, filename));
            }
        } catch (FileError err) {
            // folder not there (yet) - nothing to add
        }
        return images;
    }

    private GenericArray<string> walls(string directory) {
        // get wallpapers from dir
        var images=new GenericArray<string>();
        try {
            var dr = Dir.open(directory);
            string ? filename = null;
            while ((filename = dr.read_name()) != null) {
              string addpic = GLib.Path.build_filename(directory, filename);
              images.add(addpic);
            }
        } catch (FileError err) {
            // on error (dir not found), reset wallpaperfolder
            warning(err.message);
            settings.reset("wallpaperfolder");
            images = new GenericArray<string>();
        }
        // fold picture-of-the-day images into rotation when rotation mode
        // (not time-of-day) is active and at least one source is enabled
        if (!timeofday_enabled && (potd_wikipedia_enabled || potd_bing_enabled)) {
            string? potddir = get_potd_directory();
            if (potddir != null) {
                foreach (string img in list_images_in_dir(potddir)) {
                    images.add(img);
                }
            }
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

    private string get_today_string () {
        return new DateTime.now_local().format("%Y-%m-%d");
    }

    private void check_potd () {
        // each source is fetched independently, gated on its own
        // last-fetch date, so enabling one source doesn't get skipped
        // just because the other already ran today
        if (!potd_wikipedia_enabled && !potd_bing_enabled) {
            return;
        }
        string? potddir = get_potd_directory();
        if (potddir == null) {
            return;
        }
        string today = get_today_string();
        string? new_wikipedia_path = null;
        string? new_bing_path = null;
        if (potd_wikipedia_enabled && potd_wikipedia_last_fetch != today) {
            new_wikipedia_path = fetch_wikipedia_potd(potddir, today);
            if (new_wikipedia_path != null) {
                potd_wikipedia_last_fetch = today;
                settings.set_string("potd-wikipedia-last-fetch", today);
            }
        }
        if (potd_bing_enabled && potd_bing_last_fetch != today) {
            new_bing_path = fetch_bing_potd(potddir, today);
            if (new_bing_path != null) {
                potd_bing_last_fetch = today;
                settings.set_string("potd-bing-last-fetch", today);
            }
        }
        if (new_wikipedia_path == null && new_bing_path == null) {
            return;
        }
        if (!timeofday_enabled) {
            // rotation mode is active - fold the new picture(s) into
            // the rotation pool rather than switching immediately
            rescan_currdir();
        }
        else {
            // not rotating - show the freshest picture right away
            // (set_wallpaper() already syncs the lock screen too, if
            // that option is enabled)
            string newest = new_bing_path != null ? new_bing_path : new_wikipedia_path;
            set_wallpaper(newest);
            curr_seconds = 0;
        }
    }

    private string? get_potd_directory () {
        // resolves to the user's *actual* Pictures folder
        string? picturesdir = Environment.get_user_special_dir(
            UserDirectory.PICTURES
        );
        if (picturesdir == null) {
            warning("Could not determine the user's Pictures folder\n");
            return null;
        }
        string potddir = GLib.Path.build_filename(picturesdir, potd_folder_name);
        File dir = File.new_for_path(potddir);
        try {
            if (!dir.query_exists()) {
                dir.make_directory_with_parents();
            }
        } catch (Error e) {
            warning(
                "Could not create picture of the day folder: %s\n", e.message
            );
            return null;
        }
        return potddir;
    }

    private string? fetch_wikipedia_potd (string potddir, string today) {
        string url = "https://en.wikipedia.org/api/rest_v1/feed/featured/" +
            new DateTime.now_local().format("%Y/%m/%d");
        string? body = http_get_text(url);
        if (body == null) {
            return null;
        }
        try {
            var parser = new Json.Parser();
            parser.load_from_data(body);
            Json.Object root = parser.get_root().get_object();
            if (!root.has_member("image")) {
                // no featured image today for this wiki/date
                return null;
            }
            Json.Object potd_image = root.get_object_member("image");
            if (!potd_image.has_member("image")) {
                return null;
            }
            string imgurl = potd_image.get_object_member(
                "image"
            ).get_string_member("source");
            string destpath = GLib.Path.build_filename(
                potddir, "wikipedia-" + today + get_extension_from_url(imgurl)
            );
            return download_to_file(imgurl, destpath) ? destpath : null;
        } catch (Error e) {
            warning(
                "Could not parse Wikipedia picture of the day: %s\n", e.message
            );
            return null;
        }
    }

    private string? fetch_bing_potd (string potddir, string today) {
        string url =
            "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US";
        string? body = http_get_text(url);
        if (body == null) {
            return null;
        }
        try {
            var parser = new Json.Parser();
            parser.load_from_data(body);
            Json.Object root = parser.get_root().get_object();
            Json.Array images = root.get_array_member("images");
            if (images.get_length() == 0) {
                return null;
            }
            Json.Object first = images.get_element(0).get_object();
            string imgurl = "https://www.bing.com" +
                first.get_string_member("url");
            string destpath = GLib.Path.build_filename(
                potddir, "bing-" + today + get_extension_from_url(imgurl)
            );
            return download_to_file(imgurl, destpath) ? destpath : null;
        } catch (Error e) {
            warning("Could not parse Bing picture of the day: %s\n", e.message);
            return null;
        }
    }

    private string get_extension_from_url (string url) {
        // Bing/Wikimedia URLs can carry query strings after the
        // extension, so match on known extensions rather than trusting
        // Path/basename splitting
        string lowered = url.down();
        string[] known = {".png", ".jpeg", ".jpg"};
        foreach (string ext in known) {
            if (lowered.contains(ext)) {
                return ext == ".jpeg" ? ".jpg" : ext;
            }
        }
        return ".jpg";
    }

    private string? http_get_text (string url) {
        var session = new Soup.Session();
        var message = new Soup.Message("GET", url);
        message.request_headers.append("User-Agent", POTD_USER_AGENT);
#if HAVE_SOUP_3
        message.add_flags(Soup.MessageFlags.NO_REDIRECT);
        try {
            var retbytes = session.send_and_read(message);
            if (retbytes.length == 0 || message.status_code != 200) {
                return null;
            }
            return (string) retbytes.get_data();
        } catch (Error e) {
            return null;
        }
#else
        session.send_message(message);
        if (message.status_code != 200) {
            return null;
        }
        return (string) message.response_body.flatten().data;
#endif
    }

    private bool download_to_file (string url, string destpath) {
        var session = new Soup.Session();
        var message = new Soup.Message("GET", url);
        message.request_headers.append("User-Agent", POTD_USER_AGENT);
#if HAVE_SOUP_3
        message.add_flags(Soup.MessageFlags.NO_REDIRECT);
        try {
            var retbytes = session.send_and_read(message);
            if (retbytes.length == 0 || message.status_code != 200) {
                return false;
            }
            return GLib.FileUtils.set_data(destpath, retbytes.get_data());
        } catch (Error e) {
            warning("Could not download picture of the day: %s\n", e.message);
            return false;
        }
#else
        session.send_message(message);
        if (message.status_code != 200) {
            return false;
        }
        try {
            return GLib.FileUtils.set_data(
                destpath, message.response_body.flatten().data
            );
        } catch (Error e) {
            warning("Could not download picture of the day: %s\n", e.message);
            return false;
        }
#endif
    }
}