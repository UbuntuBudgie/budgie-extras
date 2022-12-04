using Wnck;
using Gdk;
using Gtk;


namespace WatchResize {


    class WatchWindow {

        Wnck.Window? curr_active = null;
        bool resize_runs = false;
        ulong? curr_connection = null;

        void wait_for_release(Gdk.Device gdkpointer, Gdk.Window rootwin) {
            if (!resize_runs) {
                print("waiting for release\n");
                resize_runs = true;
                Timeout.add(100, ()=> {
                    Gdk.ModifierType? buttonstate;
                    gdkpointer.get_state(rootwin, null, out buttonstate);
                    if (buttonstate != Gdk.ModifierType.BUTTON1_MASK) {
                        print(@"button released\n");
                        GetClosest.getgoing();
                        resize_runs = false;
                        return false;
                    }
                    return true;
                });
            }
        }

        void setup_watch_window(
            Wnck.Screen wnckscr, Gdk.Device pointer, Gdk.Window rootwin
        ) {
            /* need to disconnect? */
            if (curr_connection != null) {
                curr_active.disconnect(curr_connection);
            }
            /* so, on active window change */
            curr_active = wnckscr.get_active_window();
            curr_active = wnckscr.get_active_window();
            if (curr_active.get_window_type() == Wnck.WindowType.NORMAL) {
                curr_connection = curr_active.geometry_changed.connect(()=> {
                    wait_for_release(pointer, rootwin);
                });
                print(@"connect id: $curr_connection\n");
                resize_runs = false;
                print("pretty normal window here\n");
            }
        }

        public WatchWindow(string[] args) {
            /* so, let's get going */
            Gtk.init(ref args);
            /* root window */
            Gdk.Window rootwin = Gdk.get_default_root_window();
            /* get pointer device */
            Gdk.Display gdkdisp = Gdk.Display.get_default();
            Gdk.Seat gdkseat = gdkdisp.get_default_seat();
            Gdk.Device gdkpointer = gdkseat.get_pointer();
            /* window action */
            Wnck.Screen wnckscr = Wnck.Screen.get_default();
            wnckscr.active_window_changed.connect(()=> {
                print("window changing\n");
                setup_watch_window(wnckscr, gdkpointer, rootwin);
            });

            Gtk.main();
        }
    }

    public static int main(string[] args) {
        new WatchWindow(args);
        return 0;
    }
}


namespace GetClosest {

    /*
    This snippet is to be used as a building block in shuffler. its
    purpose is to evaluate how a window, roughly placed, possibly
    manually, would fit in a grid. Since we don't know what gridsize
    would be the best fit, grids up to an arbitrary n-cells (either colls
    or rows) will be evaluated.
    In shuffler, this will give us the option to add the active window's
    position as a rule, or to add it to a layout, without having to define
    the position manually in the rules or layouts dialogue window. Fine tuning
    will still be possible though for those who want or need to, e.g. to set
    target workspace or monitor, or to call the window by a specific command.
    */

    /*
    how we decide:
    to make an educated guess about the best fit in a grid of x colls or rows,
    we are looking at two things: the distance to the targeted grid-position,
    and the necessary resize to fit into n-cellspan. the algorithm used is
    simply to sum up these two, and evaluate what gives us the smallest,
    considering all cellspans and gridsizes up to a max gridsize.
    */


    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        public abstract string getactivemon_name () throws Error;
        public abstract GLib.HashTable<string, Variant> get_monitorgeometry () throws Error;
        public abstract int getactivewin () throws Error;
    }

    class GetDesktopInfo {

        ShufflerInfoClient client;

        public ShufflerInfoClient? get_client () {
            try {
                client = Bus.get_proxy_sync (
                    BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                    ("/org/ubuntubudgie/shufflerinfodaemon")
                );
                return client;
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return null;
            }
        }

        public int get_activewindow (ShufflerInfoClient? client) {
            /* get active window from daemon */
            try {
                return client.getactivewin();
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return -1;
            }
        }

        private HashTable<string, Variant>? get_monitordata (ShufflerInfoClient? client) {
            /* get monitordata from daemon (all monitors) */
            try {
                return client.get_monitorgeometry();
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return null;
            }
        }

        private string? get_activemonitorname (ShufflerInfoClient? client) {
            /* get_active monitorname from daemon */
            try {
                return client.getactivemon_name();
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return "none";
            }
        }

        public HashTable<string, Variant>? get_validwindows (
            ShufflerInfoClient? client, int runmode
        ) {
            /* get_windowdata of normal and visible windows on current workspace from daemon */
            var relevantwins = new HashTable<string, Variant> (str_hash, str_equal);
            int activewin = -1;
            activewin = get_activewindow(client);
            try {
                HashTable<string, Variant> allvalidwins = client.get_winsdata();
                allvalidwins.foreach ((key, val) => {
                    if (
                        (key == @"$activewin" || runmode == 1) &&
                        (string)val.get_child_value(7) == "false" &&
                        (string)val.get_child_value(1) == "true"
                    ) {
                        relevantwins.insert(key, val);
                    }
                });
                return relevantwins;
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return null;
            }
        }

        public int[] get_activemonitorgeometry (ShufflerInfoClient? client) {
            /* get_active monitor geometry from daemon */
            HashTable<string, Variant> mondata = get_monitordata(client);
            /* let's bail out if daemon apparently doesn't run */
            if (mondata == null) {
                message("Can't get monitordata, is Shuffler running?");
                Process.exit(0);
            }
            string monname = get_activemonitorname(client);
            int wa_width = -1;
            int wa_height = -1;
            int monx = -1;
            int mony = -1;
            foreach (string monkey in mondata.get_keys()) {
                if (monname == monkey) {
                    Variant currmon = mondata[monname];
                    wa_width = (int)currmon.get_child_value(2);
                    wa_height = (int)currmon.get_child_value(3);
                    monx = (int)currmon.get_child_value(0);
                    mony = (int)currmon.get_child_value(1);
                }
            }
            return {wa_width, wa_height, monx, mony};
        }
    }

    private GLib.Settings get_settings (string path) {
        // make settings
        var settings = new GLib.Settings(path);
        return settings;
    }

    public int getgoing () {

        int runmode = 0;

        /* setup client stuff */
        GetDesktopInfo getinfo = new GetDesktopInfo();
        ShufflerInfoClient? dbusclient = getinfo.get_client();

        /* get monitorgeometry */
        int[]? mongeo = getinfo.get_activemonitorgeometry(dbusclient);
        int wa_width = mongeo[0];
        int wa_height = mongeo[1];
        int monx = mongeo[2];
        int mony = mongeo[3];
        print(@"working area origin: $monx, $mony\n");
        print(@"monitorsize: $wa_width, $wa_height\n");
        /* get max-grid settings */
        GLib.Settings shufflersettings = get_settings(
            "org.ubuntubudgie.windowshuffler"
        );
        int maxcols = shufflersettings.get_int("roundposmaxcols");
        int maxrows = shufflersettings.get_int("roundposmaxrows");
        print(@"maxgrid: $maxcols, $maxrows\n");

        /* get window data, depending on runmode: active or all visible */
        HashTable<string, Variant>? validwindows = getinfo.get_validwindows(dbusclient, runmode);
        /* get target position on grid + wmclass and move if needed*/
        string[] processdata = move_window(
            dbusclient, validwindows, monx, mony, wa_width, wa_height,
            runmode, maxcols, maxrows
        );
        string positiondata = processdata[0];
        /* additional actions? */
        switch (runmode) {
            case 2:
            // here we will connect to making a new rule + dialog window, values will be preset
            print(@"create new rule + dialog. data: $positiondata\n");
            break;
            case 3:
            // here we will connect to making layout or add to existing + dialog window, values will be preset
            print(@"add to layout or create new + dialog. data: $positiondata\n");
            break;
            case 4:
            // just deliver the optimized position, no further actions
            print(@"only data. data: $positiondata\n");
            break;
        }
        return 0;
    }

    private string[] move_window(
        /* move window, return the position & size on grid if requested */
        ShufflerInfoClient dbusclient, HashTable<string, Variant> windata,
        int monx, int mony, int wa_width, int wa_height, int runmode,
        int maxcols, int maxrows
    ) {
        int xpos = -1;
        int ypos = -1;
        int xsize = -1;
        int ysize = -1;
        string wmc = "";
        string? griddata = null; ////////////
        windata.foreach ((key, val) => {
            xpos = (int)val.get_child_value(3) - monx;
            ypos = (int)val.get_child_value(4) - mony;
            xsize = (int)val.get_child_value(5);
            ysize = (int)val.get_child_value(6);
            int[] targetposx = getbestgrid(xsize, xpos, wa_width, maxcols);
            int[] targetposy = getbestgrid(ysize, ypos, wa_height, maxrows);
            int cellx = targetposx[1];
            int celly = targetposy[1];
            int cols = targetposx[0];
            int rows = targetposy[0];
            int spanx = targetposx[2];
            int spany = targetposy[2];
            wmc = (string)val.get_child_value(8);
            griddata = @"$cellx $celly $cols $rows $spanx $spany";
            if (runmode != 4) {
                print(@"moving $key ($wmc) to position: $cellx, $celly, grid: $cols $rows span: $spanx, $spany \n");
                string cmd = "/usr/lib/budgie-window-shuffler" + "/tile_active ".concat(
                    " ", @"$griddata", " ", @"id=$key "
                );
                run_command(cmd);
                Thread.usleep(150000);
            }
        });
        if (runmode > 1) {
            print(@"positiondata for action: $griddata\n");
            return {griddata, wmc};
        }
        return {};
    }

    void run_command (string command) {
        try {
            Process.spawn_command_line_async(command);
        }
        catch (SpawnError e) {
        }
    }

    int[] get_min_distance (
        int scrsize, int cellsize, int ncells, int wsize, int wpos
    ) {
        /*
        for given gridsize (ncells), calculate cellposition with smallest
        difference.
        */
        int diff = 100000;
        int foundpos = -1;

        for (int n=0; n<ncells; n++) {
            int spansize = n*cellsize;
            int currdiff = (wpos - spansize).abs();
            if (currdiff < diff) {
                diff = currdiff;
                /* update best cellspan */
                foundpos = n;
            }
            else {break;}
        }
        return {diff, foundpos};
    }

    int[] get_min_celldiff (
        int scrsize, int cellsize, int ncells, int wsize, int start=1
    ) {
        /*
        for given gridsize (ncells), calculate cellspan with smallest difference.
        */
        int diff = 100000;
        int foundspan = -1;
        for (int n=start; n<=ncells; n++) {
            int spansize = n*cellsize;
            int currdiff = (wsize - spansize).abs();
            if (currdiff < diff) {
                diff = currdiff;
                /* update best cellspan */
                foundspan = n;
            }
        }
        return {diff, foundspan};
    }

    int[] getbestgrid (int size, int pos, int screensize, int maxcells) {
        /*
        per gridsize, find optimal (so minimal) diff.
        */
        int gridsize = -1;
        int span = -1;
        int position = -1;
        int sum_divergence = 100000;
        for (int i=1; i<=maxcells; i++) {
            /* get cellsize for current gridsize (=i) */
            int cellsize = (int)((float)screensize/(float)i);
            /* get data on current 'suggested gridsize' */
            int[] min_celldiff = get_min_celldiff(screensize, cellsize, i, size);
            int[] min_psdif = get_min_distance(screensize, cellsize, i, size, pos);
            int curr_divergence = min_celldiff[0] + min_psdif[0];
            if (curr_divergence < sum_divergence) {
                sum_divergence = curr_divergence;
                gridsize = i;
                position = min_psdif[1];
                span = min_celldiff[1];
            }
        }
        return {gridsize, position, span};
    }
}





// 321
