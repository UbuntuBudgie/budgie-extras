using Gdk.X11;
using Cairo;
using Gtk;
using Gdk;
using Math;

/*
* ShufflerIII
* Author: Jacob Vlijm
* Copyright © 2017-2021 Ubuntu Budgie Developers
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

// valac --pkg gio-2.0 --pkg gdk-x11-3.0 --pkg gtk+-3.0 --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE" -X -lm


namespace GetWindowRules {

    HashTable<string, Variant> newrules;

    private bool endswith (string str, string tail ) {
        int str_len = str.length;
        int tail_len = tail.length;
        if (tail_len  <= str_len) {
            if (str[str_len-tail_len:str_len] == tail) {
                return true;
            }
        }
        return false;
    }

    private bool startswith (string str, string substr ) {
        int str_len = str.length;
        int field_len = substr.length;
        if (field_len  <= str_len) {
            if (str[0:field_len] == substr) {
                return true;
            }
        }
        return false;
    }

    private void read_rule (string rulesdir, string fname) {
        // read file & add resulting Variant to HashTable
        // since wm_class is filename, it's key. No need to make it a field
        string monitor = "";
        string xposition = "";
        string yposition = "";
        string rows = "";
        string cols = "";
        string xspan = "1";
        string yspan = "1";

        var file = File.new_for_path (rulesdir.concat("/", fname));
        string[] fields = {
            "Monitor", "XPosition", "YPosition",
            "Rows", "Cols", "XSpan", "YSpan"
        };

        try {
            var dis = new DataInputStream (file.read ());
            string line;
            // walk through lines, fetch arguments
            while ((line = dis.read_line (null)) != null) {
                int fieldindex = 0;
                foreach (string field in fields) {
                    if (startswith(line, field)) {
                        string new_value = line.split("=")[1];
                        switch (fieldindex) {
                            case 0:
                                monitor = new_value;
                                break;
                            case 1:
                                xposition = new_value;
                                break;
                            case 2:
                                yposition = new_value;
                                break;
                            case 3:
                                rows = new_value;
                                break;
                            case 4:
                                cols = new_value;
                                break;
                            case 5:
                                xspan = new_value;
                                break;
                            case 6:
                                yspan = new_value;
                                break;
                        }
                    }
                    fieldindex += 1;
                }
            }
        }
        catch (Error e) {
            error ("%s", e.message);
        }
        // populate HashTable here
        Variant newrule = new Variant(
            "(sssssss)" , monitor, xposition,
            yposition, rows, cols, xspan, yspan
        );
        newrules.insert(fname.split(".")[0], newrule);
    }

    public HashTable<string, Variant> find_rules (string rulesdir) {
        newrules = new HashTable<string, Variant> (str_hash, str_equal);
        // walk through files, collect rules
        try {
            var dr = Dir.open(rulesdir);
            string? filename = null;
            // walk through relevant files
            while ((filename = dr.read_name()) != null) {
                if (endswith(filename, ".windowrule")) {
                    read_rule (rulesdir, filename);
                }
            }
        }
        catch (Error e) {
            error ("%s", e.message);
        }
        return newrules;
    }
}


namespace ShufflerEssentialInfo {

    // monitordata-dict
    HashTable<string, Variant> monitorgeo;
    // windowrules directory
    string windowrule_location;
    // rules monitor
    FileMonitor monitor_ruleschange;
    // windowdata-dict
    HashTable<string, Variant> window_essentials;
    // rulesdata-dict
    HashTable<string, Variant> windowrules;
    // misc.
    unowned Wnck.Screen wnckscr;
    Gdk.Display gdkdisplay;
    int n_monitors;
    Gdk.X11.Window timestamp_window;
    // scale
    int scale;
    // dconf
    GLib.Settings shuffler_settings;
    GLib.Settings desktop_settings;
    bool desktop_animations_set;
    bool soft_move;
    bool use_windowrules;
    bool show_warning;
    int setcols;
    int setrows;
    int padding;
    int marginleft;
    int marginright;
    int margintop;
    int marginbottom;
    int greyshade;
    bool swapgeometry;
    bool gridguiruns;
    bool stickyneighbors;
    Gtk.Window? showtarget = null;
    int remaining_warningtime = 0;
    File layout_busy;

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    public class ShufflerInfoServer : Object {

        public int getactivewin () throws Error {
            // get active window id
            Wnck.Window? curr_activewin = wnckscr.get_active_window();
            if (curr_activewin != null) {
                int candidate = (int)curr_activewin.get_xid();
                // do the validity test
                return check_windowvalid(candidate);
            }
            return -1;
        }

        public HashTable<string, Variant> get_rules () throws Error {
            // get rules externally
            foreach (string k in windowrules.get_keys()) {
            }
            return windowrules;
        }

        public int check_windowvalid (int winid) throws Error {
            foreach (string k in window_essentials.get_keys()) {
                if (k == @"$winid") {
                    return winid;
                }
            }
            return -1;
        }

        public bool check_ifguiruns () throws Error {
            return gridguiruns;
        }

        public int show_warningage () throws Error {
            return remaining_warningtime;
        }

        public int get_greyshade () throws Error {
            return greyshade;
        }

        public void toggle_maximize (int w_arg) throws Error {
            Wnck.Window? w = get_matchingwnckwin(w_arg);
            if (w != null) {
                bool state = w.is_maximized();
                if (state) {
                    w.unmaximize();
                }
                else {
                    w.maximize();
                }
            }
        }

        public void move_toworkspace (int w_id, int workspace) throws Error {
            Wnck.Window? w = get_matchingwnckwin(w_id);
            if (w != null) {
                unowned GLib.List<Wnck.Workspace> spaces = wnckscr.get_workspaces();
                foreach (Wnck.Workspace ws in spaces) {
                    if (ws.get_number() == workspace) {
                        GLib.Timeout.add(50, ()=> {
                            w.move_to_workspace(ws);
                            return false;
                        });
                        break;
                    }
                }
            }
        }

        public HashTable<string, Variant> get_winsdata () throws Error {
            // window data, send through
            get_windata();
            return window_essentials;
        }

        private Wnck.Window? get_matchingwnckwin (int wid) {
            unowned GLib.List<Wnck.Window> wlist = wnckscr.get_windows();
            foreach (unowned Wnck.Window w in wlist) {
                if (w.get_xid() == wid) {
                    return w;
                }
            }
            return null;
        }

        public void activate_window (int win_id) throws Error {
            Wnck.Window? w = get_matchingwnckwin(win_id);
            if (w != null) {
                w.activate(get_now());
            }
        }

        public void activate_window_byname (string wname) throws Error {
            Wnck.Window? w = get_matchingwnckwin_byname(wname);
            if (w != null) {
                w.activate(get_now());
            }
        }

        private Wnck.Window? get_matchingwnckwin_byname (string wname) {
            unowned GLib.List<Wnck.Window> wlist = wnckscr.get_windows();
            foreach (unowned Wnck.Window w in wlist) {
                if (w.get_name() == wname) {
                    return w;
                }
            }
            return null;
        }

        public void show_awarning () throws Error {
            if (show_warning) {
                if (remaining_warningtime == 0) {
                    remaining_warningtime = 1000;
                    string cmd = Config.SHUFFLER_DIR + "/sizeexceeds_warning";
                    try {
                        Process.spawn_command_line_async (cmd);
                    }
                    catch (Error e) {
                        stderr.printf ("%s\n", e.message);
                    }
                    GLib.Timeout.add (100, ()=> {
                        if (remaining_warningtime <= 0) {
                            return false;
                        }
                        else {
                            remaining_warningtime -= 100;
                            try {
                                activate_window_byname("sizeexceedswarning");
                            }
                            catch (Error e) {
                                stderr.printf ("%s\n", e.message);
                            }
                            return true;
                        }
                    });
                }
                else {
                    remaining_warningtime = 1000;
                }
            }
        }

        public bool winistoolarge (int w_id, int targetw, int targeth) throws Error {
            int[] specs = get_winspecs(w_id);
            // allow a tiny oversize
            if (targetw + 1 < specs[1] || targeth + 1 < specs[2]) {
                return true;
            }
            return false;
        }

        public void move_window (
            int w_id, int x, int y, int width, int height, bool nowarning = false
        ) throws Error {
            // move window, (also) external connection
            Wnck.Window? w = get_matchingwnckwin(w_id);
            if (w != null) {
                now_move(w, x, y, width, height);
            }
            if (!nowarning) {
                if (winistoolarge(w_id, width, height)) {
                    show_awarning();
                }
            }
        }

        public void move_window_animated (
            int w_id, int x, int y, int width, int height
        ) throws Error {
            // move window, animated
            /*
            / if move is initiated from here, softmove disables warnings
            / in move_window to prevent repeted warnings on the same move
            / action
            */
            string cm = Config.SHUFFLER_DIR + "/softmove ".concat(
            //  string cm = "/usr/lib/budgie-window-shuffler" + "/softmove ".concat(
                @" $w_id $x $y $width $height"
            );
            try {
                Process.spawn_command_line_async(cm);
            }
            catch (SpawnError e) {
            }
            if (winistoolarge(w_id, width, height)) {
                show_awarning();
            }
        }

        private void now_move (
            Wnck.Window tomove, int x, int y, int width, int height
        ) {
            // executed version
            tomove.unmaximize();
            tomove.unminimize(get_now());
            tomove.set_geometry(
                Wnck.WindowGravity.NORTHWEST,
                Wnck.WindowMoveResizeMask.X |
                Wnck.WindowMoveResizeMask.Y |
                Wnck.WindowMoveResizeMask.WIDTH |
                Wnck.WindowMoveResizeMask.HEIGHT,
                x, y, width - padding, height - padding
            );
        }

        private uint get_now () {
            // timestamp
            return Gdk.X11.get_server_time(timestamp_window);
        }

        public HashTable<string, Variant> get_tiles (
            string mon_name, int cols, int rows
        ) throws Error {
            /* tiledata.keys:
            / "x_anchors" (as string)
            / "y_anchors" (as string)
            / "tilewidth" (int)
            / "tileheight" (int)
            / additionally per tile "col*row" (Variant), representing:
            / - x, y, width, height (iiiis)
            / having info -per tile- and general info on the very same level
            / doesn't seem brilliantly elegant on second thought. fix if we
            / ever have too mutch time.
            */

            // get the list of tiles, properties
            var tiledata = new HashTable<string, Variant> (str_hash, str_equal);
            int[] xpositions = {};
            int[] ypositions = {};
            for (int i=0; i < n_monitors; i++) {
                Gdk.Monitor? monitorsubj = gdkdisplay.get_monitor(i);
                if (monitorsubj == null) {
                    print("monitor cannot be detected\n");
                }
                else if (monitorsubj.get_model()  == mon_name) {
                    Gdk.Rectangle mon_wa = monitorsubj.get_workarea();
                    int fullwidth = (mon_wa.width * scale) - (marginleft + marginright) + padding;
                    int tilewidth = (int)(round(fullwidth/cols));
                    int fullheight = (mon_wa.height * scale) - (margintop + marginbottom) + padding;
                    int tileheight = (int)(round(fullheight/rows));
                    int NEx = (mon_wa.x * scale) + marginleft;
                    int origx = NEx;
                    while (NEx < origx + fullwidth - marginright) {
                        xpositions += NEx;
                        NEx += tilewidth;
                    }
                    int NEy = (mon_wa.y * scale) + margintop;
                    int origy = NEy;
                    while (NEy < origy + fullheight - marginbottom) {
                        ypositions += NEy;
                        NEy += tileheight;
                    }
                    string[] xpositions_str = {};
                    string[] ypositions_str = {};

                    foreach (int xp in xpositions) {
                        xpositions_str += @"$xp";
                    }
                    foreach (int yp in ypositions) {
                        ypositions_str += @"$yp";
                    }
                    tiledata.insert("x_anchors", string.joinv(" ", xpositions_str));
                    tiledata.insert("y_anchors", string.joinv(" ", ypositions_str));
                    /*
                    / ok, width/height is already in tiledata, but for jump r/l, we need it separatly.
                    / optimize, or are we lazy? nah, leave it. We need to calc tiles anyway.
                    */
                    tiledata.insert("tilewidth", tilewidth);
                    tiledata.insert("tileheight", tileheight);
                    // now create tiles
                    int col = 0;

                    foreach (int nx in xpositions) {
                        int row = 0;
                        foreach (int ny in ypositions) {
                            string tilekey = @"$col*$row";
                            Variant newtile = new Variant(
                                "(iiiis)", nx, ny, tilewidth, tileheight, tilekey
                            );
                            tiledata.insert(tilekey, newtile);
                            row += 1;
                        }
                        col += 1;
                    }
                }
            }
            return tiledata;
        }

        public int[] get_margins ()  throws Error {
            return {margintop, marginleft, marginright, marginbottom, padding};
        }

        public int[] get_grid() throws Error {
            return {setcols, setrows};
        }

        public bool get_softmove() throws Error {
            return soft_move;
        }

        public bool get_stickyneighbors() throws Error {
            return stickyneighbors;
        }

        public bool get_general_animations_set () throws Error {
            return desktop_animations_set;
        }

        public bool swapgeo() throws Error {
            return swapgeometry;
        }

        public HashTable<string, Variant> get_monitorgeometry() throws Error {
            return monitorgeo;
        }

        public void set_grid (int cols, int rows) throws Error {
            shuffler_settings.set_int("cols", cols);
            shuffler_settings.set_int("rows", rows);
        }

        public void set_greyshade (int newbrightness) throws Error {
            // sets the gsettings brightness for the gui grid
            shuffler_settings.set_int("greyshade", newbrightness);
        }

        public void kill_tilepreview () throws Error {
            // kill preview
            if (showtarget != null) {
                showtarget.destroy();
                showtarget = null;
            }
        }

        public void show_tilepreview (
            int col, int row, int width = 1, int height = 1
        ) throws Error {
            int x = 0;
            int y = 0;
            int w = 0;
            int h = 0;
            string currmon = getactivemon_name();
            HashTable<string, Variant> currtiles = get_tiles(currmon, setcols, setrows);
            foreach (string tk in currtiles.get_keys()) {
                if (tk.contains("*")) {
                    string[] xy = tk.split("*");
                    if (int.parse(xy[0]) == col && int.parse(xy[1]) == row) {
                        Variant v = currtiles[tk];
                        // remember, Gtk uses scaled numbers!
                        x = (int)v.get_child_value(0)/scale;
                        y = (int)v.get_child_value(1)/scale;
                        w = (width * ((int)round((int)v.get_child_value(2))/scale)) - (int)round(padding/scale);
                        h = (height * ((int)round((int)v.get_child_value(3))/scale)) - (int)round(padding/scale);
                        break;
                    }
                }
            }
            // create window
            showtarget = new PreviewWindow(x, y, w, h);
        }

        public int[] get_winspecs (int w_id) throws Error {
            /*
            / get yshift & minimumsize
            / in case a window has property NET_FRAME_EXTENTS, we need to
            / position the window according to y-extent
            / to get -real- minimum size, in case of NET_FRAME_EXTENTS, we
            / need to -add- FRAME_EXTENTS in case of NET_FRAME_EXTENTS,
            / but -subtract- in case of GTK_FRAME_EXTENTS.
            */
            int yshift = 0; int minwidth = 0; int minheight = 0;
            int ext_hor = 0; int ext_vert = 0;
            string winsubj = @"$w_id";
            //  string cmd = Config.PACKAGE_BINDIR + "/xprop -id ".concat(
            string cmd = "/usr/bin" + "/xprop -id ".concat(
                winsubj, " _NET_FRAME_EXTENTS ",
                "WM_NORMAL_HINTS", " _GTK_FRAME_EXTENTS"
            );

            string? output = null;
            try {
                GLib.Process.spawn_command_line_sync(cmd, out output);
            }
            catch (SpawnError e) {
                // nothing to do
            }

            if (output != null) {
                string[] lookfordata = output.split("\n");
                foreach (string s in lookfordata) {
                    if (s.contains("minimum size")) {
                        string[] linecont = s.split(" ");
                        int n_str = linecont.length;
                        minwidth = int.parse(linecont[n_str - 3]);
                        minheight = int.parse(linecont[n_str - 1]);
                    }
                    else if (s.contains("FRAME_EXTENTS") && s.contains("=")) {
                        string[] ext_data = s.split(" = ")[1].split(", ");
                        ext_hor = int.parse(ext_data[0]) + int.parse(ext_data[1]);
                        ext_vert = int.parse(ext_data[2]) + int.parse(ext_data[3]);
                        if (s.contains("_NET")) {
                            yshift = int.parse(ext_data[2]);
                            ext_hor = ext_hor * -1; ext_vert = ext_vert * -1;
                        }
                    }
                }
            }
            minwidth = minwidth - ext_hor;
            minheight = minheight - ext_vert;
            return {yshift, minwidth , minheight};
        }

        public string getactivemon_name () throws Error {
            // get the monitor with active window or ""
            string activemon_name = "";
            Wnck.Window curr_activew = wnckscr.get_active_window();
            if (curr_activew != null) {
                int x;
                int y;
                int w;
                int h;
                curr_activew.get_geometry(out x, out y, out w, out h);
                Gdk.Monitor activemon = gdkdisplay.get_monitor_at_point(x, y);
                activemon_name = activemon.get_model();
            }
            return activemon_name;
        }

        public Variant extracttask_fromfile (string? path) throws Error {
            // read taskfile
            string[] fields = {
                "Exec", "XPosition", "YPosition", "Cols", "Rows",
                "XSpan", "YSpan", "WMClass", "WName", "Monitor",
                "TryExisting"
            };
            // let's set some defaults
            string command = "";
            string x_ongrid = "0";
            string y_ongrid = "0";
            string cols = "2";
            string rows = "2";
            string xspan = "1";
            string yspan = "1";
            string wmclass = "";
            string wname = "";
            string monitor = "";
            string tryexisting = "false";
            DataInputStream? dis = null;
            try {
                var file = File.new_for_path (path);
                if (file.query_exists ()) {
                    dis = new DataInputStream (file.read ());
                    string line;
                    while ((line = dis.read_line (null)) != null) {
                        int fieldindex = 0;
                        foreach (string field in fields) {
                            if (GetWindowRules.startswith (line, field)) {
                                string new_value = line.split("=")[1];
                                switch (fieldindex) {
                                case 0:
                                    command = new_value;
                                    break;
                                case 1:
                                    x_ongrid = new_value;
                                    break;
                                case 2:
                                    y_ongrid = new_value;
                                    break;
                                case 3:
                                    cols = new_value;
                                    break;
                                case 4:
                                    rows = new_value;
                                    break;
                                case 5:
                                    xspan = new_value;
                                    break;
                                case 6:
                                    yspan = new_value;
                                    break;
                                case 7:
                                    wmclass = new_value.down();
                                    break;
                                case 8:
                                    wname = new_value.down();
                                    break;
                                case 9:
                                    monitor = new_value;
                                    break;
                                case 10:
                                    tryexisting = new_value;
                                    break;
                                }
                            }
                            fieldindex += 1;
                        }
                    }
                }
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
            return new Variant(
                "(sssssssssss)" , command, x_ongrid, y_ongrid, cols, rows, 
                xspan, yspan, wmclass, wname, monitor, tryexisting
            );
        }
    }

    private void getscale() {
        // get scale factor of primary (which we are using)
        Gdk.Monitor? monitorsubj = gdkdisplay.get_primary_monitor();
        if (monitorsubj != null) {
            scale = monitorsubj.get_scale_factor();
        }
    }

    private void get_monitors () {
        // N.B. curently, only applied use of function below is get n_monitors
        // keep the rest (monitorgeo) for future use though
        // maintaining function
        // collect data on connected monitors: real numbers! (unscaled)
        monitorgeo = new HashTable<string, Variant> (str_hash, str_equal);
        n_monitors = gdkdisplay.get_n_monitors();
        for (int i=0; i < n_monitors; i++) {
            Gdk.Monitor? newmonitor = gdkdisplay.get_monitor(i);
            if (newmonitor != null) {
                string? mon_name = newmonitor.get_model();
                if (mon_name != null) {
                    Gdk.Rectangle? mon_geo = newmonitor.get_workarea();;
                    int? sf = newmonitor.get_scale_factor ();
                    int? x = mon_geo.x * sf;
                    int? y = mon_geo.y * sf;
                    int? width = mon_geo.width * sf;
                    int? height = mon_geo.height * sf;
                    Variant geodata = new Variant(
                        "(iiii)", x , y, width, height
                    );
                    monitorgeo.insert(mon_name, geodata);
                }
            }
        }
    }

    // setup dbus
    void on_bus_acquired (DBusConnection conn) {
        // register the bus
        try {
            conn.register_object ("/org/ubuntubudgie/shufflerinfodaemon",
                new ShufflerInfoServer ());
        }
        catch (IOError e) {
            stderr.printf ("Could not register service\n");
        }
    }

    public void setup_dbus () {
        Bus.own_name (
            BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
            BusNameOwnerFlags.NONE, on_bus_acquired,
            () => {}, () => stderr.printf ("Could not acquire name\n"));
    }

    private void run_command (string cmd) {
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

    private void acton_latestwin (Wnck.Window newwin) {
        int win_xid = (int)newwin.get_xid();
        get_windata();
        run_windowchangecommand("newwindowaction", win_xid);
        run_windowrules(newwin, win_xid); // new, make depend on gsettings
    }

    private void run_windowrules (Wnck.Window newwin, int? xid) {
        // first check if run_layout is active, possibly need to overrule below
        bool layout_isbusy = layout_busy.query_exists ();
        if (use_windowrules && !layout_isbusy) {
            string groupname = newwin.get_class_group_name();
            string cmnd = Config.SHUFFLER_DIR + @"/run_rule $groupname $xid";
            run_command(cmnd);
            /*
            / run execute_rule executable here with these args ^^^
            / executable then fetches relevant window rule and moves window
            */
        }
    }

    private void run_windowchangecommand (string actiontype, int? newwin = null) {
        string cmd = shuffler_settings.get_string(actiontype);
        if (cmd != "") {
            string window_arg = "";
            if (newwin != null) {
                window_arg = (@" $newwin");
            }
            run_command(cmd + window_arg);
        }
    }

    private void get_windata () {
        /*
        / maintaining function
        / get windowlist, per window:
        / xid = key. then: name, onthisworspace, monitor-of-window, geometry, minimized, wmclass
        */
        var winsdata = new HashTable<string, Variant> (str_hash, str_equal);
        unowned GLib.List<Wnck.Window> wlist = wnckscr.get_windows();
        foreach (Wnck.Window w in wlist) {
            Wnck.WindowType type = w.get_window_type ();
            if (type == Wnck.WindowType.NORMAL) {
                string name = w.get_name();
                bool onthisws = wnckscr.get_active_workspace() == w.get_workspace ();
                int x;
                int y;
                int width;
                int height;
                w.get_geometry(out x, out y, out width, out height);
                string winsmonitor = gdkdisplay.get_monitor_at_point(
                    (int)(round (x/scale)), (int)(round(y/scale))
                ).get_model();
                ulong xid = w.get_xid();
                bool minimized = w.is_minimized();
                string? wmclass = w.get_class_group_name();
                if (wmclass == null) {
                    wmclass = "";
                }
                Variant windowdata = new Variant(
                    "(sssiiiiss)", name, @"$onthisws", winsmonitor,
                    x, y, width, height, @"$minimized", wmclass
                );
                winsdata.insert(@"$xid", windowdata);
            }
        }
        window_essentials = winsdata;
    }


    private class PreviewWindow: Gtk.Window {

        bool warning;

        public PreviewWindow (int x, int y, int w, int h, bool warning = false) {
            // transparency
            this.warning = warning;
            this.title = "shuffler_shade";
            var screen = this.get_screen();
            this.set_app_paintable(true);
            var visual = screen.get_rgba_visual();
            this.set_visual(visual);
            this.draw.connect(on_draw);
            this.set_decorated(false);
            this.title = "tilingpreview";
            this.set_skip_taskbar_hint(true);
            this.resize(w, h);
            this.move(x, y);
            this.set_focus_on_map(true);
            this.show_all();
        }

        private bool on_draw (Widget da, Context ctx) {
            // optimize please, also in warning
            // needs to be connected to transparency settings change
            ctx.set_source_rgba(0.0, 0.30, 0.50, 0.40);
            ctx.set_operator(Cairo.Operator.SOURCE);
            ctx.paint();
            ctx.set_operator(Cairo.Operator.OVER);
            return false;
        }

    }

    private GLib.Settings get_settings (string path) {
        // make settings
        var settings = new GLib.Settings(path);
        return settings;
    }

    private void update_settings (){
        // fetch dconf values
        setcols = shuffler_settings.get_int("cols");
        setrows = shuffler_settings.get_int("rows");
        swapgeometry = shuffler_settings.get_boolean("swapgeometry");
        greyshade = shuffler_settings.get_int("greyshade");
        marginleft = shuffler_settings.get_int("marginleft");
        marginright = shuffler_settings.get_int("marginright");
        margintop = shuffler_settings.get_int("margintop");
        marginbottom = shuffler_settings.get_int("marginbottom");
        padding = shuffler_settings.get_int("padding");
        soft_move = shuffler_settings.get_boolean("softmove");
        show_warning = shuffler_settings.get_boolean("showwarning");
        stickyneighbors = shuffler_settings.get_boolean("stickyneighbors");
        use_windowrules = shuffler_settings.get_boolean("windowrules");
        set_rulesmonitor ();
    }

    private string create_dirs_file (string subpath) {
        // defines, and if needed, creates directory for rules
        string homedir = Environment.get_home_dir();
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

    private void update_rulesdata () {
        windowrules = GetWindowRules.find_rules(windowrule_location);
        foreach (string k in windowrules.get_keys()) {
        }
    }

    private void set_rulesmonitor () {
        if (use_windowrules) {
            // setup monitor
            File rulesdir = File.new_for_path(windowrule_location);
            try {
                monitor_ruleschange = rulesdir.monitor(FileMonitorFlags.NONE, null);
                monitor_ruleschange.changed.connect(update_rulesdata);
                // oh, and update now please
                update_rulesdata();
            }
            catch (Error e) {
            }
        }
        else {
            if (monitor_ruleschange != null) {
                monitor_ruleschange.cancel();
            }
        }
    }

    private void actonfile(File file, File? otherfile, FileMonitorEvent event) {
        if (event == FileMonitorEvent.CREATED) {
            gridguiruns = true;
        }
        else if (event == FileMonitorEvent.DELETED) {
            gridguiruns = false;
        }
    }

    private void update_desktopsettings () {
        desktop_animations_set = desktop_settings.get_boolean("enable-animations");
    }

    private void create_warningbg () {
        // on startup of the daemon, create a bg image for the warning
        // Create a context:
        Cairo.ImageSurface surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, 490, 65); // image size
        Cairo.Context context = new Cairo.Context (surface);
        create_box (surface, context, {0, 0, 490, 65}, {0, 0.3, 0.5, 0.8});
        create_box (surface, context, {40, 30, 16, 16}, {1, 1, 1, 1});
        create_box (surface, context, {30, 20, 8, 8}, {1, 1, 1, 1});
        create_box (surface, context, {30, 30, 8, 8}, {1, 1, 1, 1});
        create_box (surface, context, {40, 20, 8, 8}, {1, 1, 1, 1});
        // Save the image:
        surface.write_to_png ("/tmp/shuffler-warning.png");
    }

    private void create_box (
        Cairo.ImageSurface surface, Cairo.Context context,
        int[] geo, double[] rgba)
        {
            context.set_source_rgba (rgba[0], rgba[1], rgba[2], rgba[3]);
            context.rectangle (geo[0], geo[1], geo[2], geo[3]);
            context.fill ();
    }

    public static int main (string[] args) {

        // create warning image
        create_warningbg();
        Gtk.init(ref args);
        // FileMonitor stuff, see if gui runs (disable jump & tileactive)
        gridguiruns = false;
        FileMonitor monitor;
        string user = Environment.get_user_name();
        // layout_busy triggerfile for run_layout
        layout_busy = File.new_for_path (
            "/tmp/".concat(user, @"_running_layout")
        );
        // and one for grid
        File gridtrigger = File.new_for_path(
            "/tmp/".concat(user, "_gridtrigger")
        );
        try {
            monitor = gridtrigger.monitor(FileMonitorFlags.NONE, null);
            monitor.changed.connect(actonfile);
        }
        catch (Error e) {
        }
        // settings stuff
        shuffler_settings = get_settings("org.ubuntubudgie.windowshuffler");
        windowrule_location = create_dirs_file(".config/budgie-extras/shuffler/windowrules");
        windowrules = new HashTable<string, Variant> (str_hash, str_equal);
        shuffler_settings.changed.connect(update_settings);
        update_settings();
        desktop_settings = get_settings("org.gnome.desktop.interface");
        desktop_settings.changed["enable-animations"].connect(update_desktopsettings);
        update_desktopsettings();
        // X11 stuff, non-dynamic part
        unowned X.Window xwindow = Gdk.X11.get_default_root_xwindow();
        unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
        Gdk.X11.Display display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
        timestamp_window = new Gdk.X11.Window.foreign_for_display(display, xwindow);
        // misc.
        wnckscr = Wnck.Screen.get_default();
        wnckscr.force_update();
        monitorgeo = new HashTable<string, Variant> (str_hash, str_equal);

        window_essentials = new HashTable<string, Variant> (str_hash, str_equal);
        gdkdisplay = Gdk.Display.get_default();
        Gdk.Screen gdkscreen = Gdk.Screen.get_default();
        get_monitors();
        getscale();
        gdkscreen.monitors_changed.connect(get_monitors);
        gdkscreen.monitors_changed.connect(getscale);
        get_windata();
        wnckscr.window_opened.connect(acton_latestwin);
        wnckscr.window_closed.connect(()=> {
            if (showtarget != null && gridguiruns == false) {
                showtarget.destroy();
                showtarget = null;
            }
            get_windata();
            run_windowchangecommand("closedwindowaction");
        });
        setup_dbus();
        Gtk.main();
        return 0;
    }
}