using Gtk;
using Math;

/*
* HotCorners III
* Author: Jacob Vlijm
* Copyright © 2017 Ubuntu Budgie Developers
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

// valac --pkg gtk+-3.0 -X -lm

namespace NewHotcorners {

    /*
    in some cases, we need to temporarily disable hotcorners, e.g. to prevent
    unintended actions with dragsnap edge/corner tiling. to do so, we'll add
    a dbus method.
    */

    bool skip_action = false;

    /* dbus client for freedesktop list names) */
    [DBus (name = "org.freedesktop.DBus")]
    interface FreeDesktopClient : Object {
        public abstract string[] ListNames () throws Error;
    }

    /* dbus client for shufflerdaemon (then skip action) */
    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]
    interface ShufflerInfoClient : Object {
        public abstract bool GetMouseIsdown (int button) throws Error;
    }

    /* dbus client for screensaver (then skip action) */
    [DBus (name = "org.gnome.ScreenSaver")]
    interface ScreensaverClient : Object {
        public abstract bool GetActive () throws Error;
        public signal void ActiveChanged (bool test);
    }

    /* dbus server, to set skip action */
    [DBus (name = "org.UbuntuBudgie.HotCornerSwitch")]
    private class HotCornersServer : GLib.Object {
        public void set_skip_action (bool skip) throws Error {
            skip_action = skip;
        }
    }

    // setup dbus
    void on_bus_acquired (DBusConnection conn) {
        // register the bus
        try {
            conn.register_object ("/org/ubuntubudgie/hotcornerswitch",
                new HotCornersServer ());
        }
        catch (IOError e) {
            stderr.printf ("Could not register service\n");
        }
    }

    private void setup_dbus () {
        Bus.own_name (
            BusType.SESSION, "org.UbuntuBudgie.HotCornerSwitch",
            BusNameOwnerFlags.NONE, on_bus_acquired,
            () => {}, () => stderr.printf ("Could not acquire name\n"));
    }


    class NewHotcornersApp {

        enum ActionArea {
            NONE,
            LEFT,
            TOPLEFT,
            TOP,
            TOPRIGHT,
            RIGHT,
            BOTTOMRIGHT,
            BOTTOM,
            BOTTOMLEFT
        }

        /* monitor description and calculated figures we are working with */
        int left;
        int right;
        int top;
        int bottom;
        int width;
        int height;
        int corner_tolerance;
        int left_innerline;
        int right_innerline;
        int top_innerline;
        int bottom_innerline;
        int scale;
        int curr_area = ActionArea.NONE;

        /* freedesktop client */
        FreeDesktopClient? freed_client;

        /* screensaver client */
        ScreensaverClient? screensaverclient;
        bool screensaver_runs;

        /* ShufflerDaemon client */
        ShufflerInfoClient? shufflerinfoclient;

        /* general state stuff to work with */
        bool fired = false;

        /* settings */
        GLib.Settings hotcornersettings;
        int delay;
        int set_pressure;
        string[] commandlist;

        /* hard coded? */
        int side_margin = 2;
        int corner_margin = 40;

        public NewHotcornersApp() {
            /* get stuff to work with */
            Gdk.Display gdkdsp = Gdk.Display.get_default();
            Gdk.Screen gdkscr = Gdk.Screen.get_default();
            Gdk.Window rootwin = gdkscr.get_root_window();
            Gdk.Seat gdkseat = gdkdsp.get_default_seat();
            Gdk.Device pointer = gdkseat.get_pointer();
            hotcornersettings = new GLib.Settings(
                "org.ubuntubudgie.budgie-extras.HotCorners"
            );

            update_settings();
            setup_dbus();
            get_screensaver_client();
            get_shuffler_client();
            setup_freed_client();

            /* screensaver */
            get_screensaver_active();
            screensaverclient.ActiveChanged.connect((active)=> {
                screensaver_runs = active;
            });
            hotcornersettings.changed.connect(update_settings);
            /*
            make a guess about initial values (if wrong, will be
            updated immediately
            */
            int x = 0; int y = 0; Gdk.ModifierType tp = 0;
            Gdk.Monitor currmon = gdkdsp.get_monitor_at_point(x, y);
            update_monitorgeo(currmon);

            int[] xses = {}; int[] yses = {};

            int cycle = 0;

            /* actual loop */
            Timeout.add(50, ()=> {
                /* get pointer position, store last few to get pressure */
                rootwin.get_device_position(pointer, out x, out y, out tp);
                xses += x; yses += y;
                /* related to pressure. only get pressure if on spot */
                int len = xses.length;
                xses = xses[(len - 3):len];
                yses = yses[(len - 3):len];

                cycle += 1;

                /* once per second, update monitor */
                if (cycle == 20) {
                    Gdk.Monitor newmon = gdkdsp.get_monitor_at_point(x, y);
                    if (newmon != currmon) {
                        currmon = newmon;
                        update_monitorgeo(newmon);
                    }
                    cycle = 0;
                }
                /* check area */
                /*
                in most cases, user moves the mouse towards the corner
                in a "sloppy" manner, most likely first touching one of the
                side-areas. To prevent unintended firing, we set a time of
                125 ms to "reconsider" the right spot. if the spot changes
                within 125ms, the first hit is ignored. if the spot
                stays the same, go for it!
                */

                int new_area = get_area(x, y);;
                if (new_area != curr_area &&
                    !skip_action &&
                    !screensaver_runs
                ) {
                    /*
                    if we're not on the same spot any more, decide what  to do
                    */
                    if (
                        curr_area == ActionArea.NONE &&
                        new_area !=  ActionArea.NONE
                    ) {
                        delayed_action(new_area, xses, yses);
                    }
                    else if (
                        curr_area != ActionArea.NONE &&
                        new_area != ActionArea.NONE
                    ) {
                        if (!fired) {
                            delayed_action(new_area, xses, yses);
                        }
                    }
                    else if (new_area == ActionArea.NONE) {
                        fired = false;
                    }
                    curr_area = new_area;
                }
                return true;
            });
        }

        private void get_screensaver_active () {
            try {
                screensaver_runs = screensaverclient.GetActive();
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                screensaver_runs = false;
            }
        }

        private bool service_ison (string id) {
            string[] names = get_dbus_namelist();
            //  string hotc = "org.UbuntuBudgie.HotCornerSwitch";
            for (int i=0; i<names.length; i++) {
                if (id == names[i]) {
                    return true;
                }
            }
            return false;
        }

        private string[] get_dbus_namelist () {
            try {
                return freed_client.ListNames();
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return {};
            }
        }

        private void get_screensaver_client () {
            try {
                screensaverclient = Bus.get_proxy_sync (
                    BusType.SESSION, "org.gnome.ScreenSaver",
                    ("/org/gnome/ScreenSaver")
                );
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private bool get_mousedown () {
            if (!service_ison("org.UbuntuBudgie.ShufflerInfoDaemon")) {
                return false;
            }
            try {
                return shufflerinfoclient.GetMouseIsdown(1);
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
            return false;
        }

        private void setup_freed_client () {
            try {
                freed_client = Bus.get_proxy_sync (
                    BusType.SESSION, "org.freedesktop.DBus",
                    ("/org/freedesktop/DBus")
                );
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private void get_shuffler_client () {
            try {
                shufflerinfoclient = Bus.get_proxy_sync (
                    BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                    ("/org/ubuntubudgie/shufflerinfodaemon")
                );
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private void run_command (string cmd) {
            /* execute the command */
            try {
                Process.spawn_command_line_async(cmd);
            }
            catch (GLib.SpawnError err) {
                /*
                * in case an error occurs, the command most likely is
                * incorrect not much use for any action
                */
            }
        }

        private void delayed_action (int start_area, int[] xses, int[] yses) {
            if (get_mousedown()) {
                //  print("mouse is down!\n");
                return;
            }
            int realdelay = 125 + (delay * 20);
            int curr_pressure = get_pressure(xses, yses)/scale;
            if (curr_pressure < set_pressure) {
                return;
            }
            Timeout.add(realdelay, ()=> {
                if (curr_area == start_area) {
                    /* run command */
                    string cmd = commandlist[start_area - 1];
                    if (cmd != "") {
                        run_command(cmd);
                    }
                    fired = true;
                }
                return false;
            });
        }

        private void update_settings() {
            delay = hotcornersettings.get_int("delay");
            set_pressure = 2 * hotcornersettings.get_int("pressure");
            commandlist = hotcornersettings.get_strv("commands");
        }

        private int get_area (int x, int y) {
            y = y * scale;
            x = x * scale;
            int area = 0;
            /* on the left side */
            if (x <= left_innerline) {
                area = ActionArea.LEFT;
                if (y < (top + corner_tolerance)) {
                    area = ActionArea.TOPLEFT;
                }
                else if (y > (bottom - corner_tolerance)) {
                    area = ActionArea.BOTTOMLEFT;
                }
            }
            /* on the right side */
            else if (x >= right_innerline) {
                area = ActionArea.RIGHT;
                if (y < (top + corner_tolerance)) {
                    area = ActionArea.TOPRIGHT;
                }
                else if (y > (bottom - corner_tolerance)) {
                    area = ActionArea.BOTTOMRIGHT;
                }
            }
            /* on the top side */
            else if (y <= top_innerline) {
                area = ActionArea.TOP;
                if (x > (right - corner_tolerance)) {
                    area = ActionArea.TOPRIGHT;
                }
                else if (x < (left + corner_tolerance)) {
                    area = ActionArea.TOPLEFT;
                }
            }
            /* and.. bottom side */
            else if (y >= bottom_innerline) {
                area = ActionArea.BOTTOM;
                if (x > (right - corner_tolerance)) {
                    area = ActionArea.BOTTOMRIGHT;
                }
                else if (x < (left + corner_tolerance)) {
                    area = ActionArea.BOTTOMLEFT;
                }
            }
            else {
                area = ActionArea.NONE;
            }
            return area;
        }

        private void update_monitorgeo(Gdk.Monitor mon) {
            scale = mon.get_scale_factor();
            side_margin = side_margin * scale;
            corner_margin = corner_margin * scale;
            var geo = mon.get_geometry();
            width = geo.width * scale;
            height = geo.height * scale;
            left = geo.x * scale;
            top = geo.y * scale;
            bottom = top + height;
            right = left + width;
            left_innerline = left + (side_margin * scale);
            right_innerline = right - (side_margin * scale);
            top_innerline = top + (side_margin * scale);
            bottom_innerline = bottom - (side_margin * scale);
            corner_tolerance = corner_margin * scale;
        }

        private int get_pressure (int[] xses, int[] yses) {
            /*
            good old pythagoras to get the road the pointer travelled in the
            last 1/4 second or so. only run this in case we are in one of the
            activation areas.
            */
            int len = xses.length;
            int firstx = xses[0];
            int lastx = xses[len-1];
            int firsty = yses[0];
            int lasty = yses[len-1];
            double xspan = Math.pow((firstx - lastx), 2.0);
            double yspan = Math.pow((firsty - lasty), 2.0);
            int travel = (int)Math.pow(xspan + yspan, 0.5);
            return (int)travel;
        }

        public static int main(string[] args) {
            Gtk.init(ref args);
            new NewHotcornersApp();
            Gtk.main();
            return 0;
        }
    }
}