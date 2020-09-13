
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


namespace NewTileActive {


    ShufflerInfoClient? client;
    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        public abstract int getactivewin () throws Error;
        public abstract HashTable<string, Variant> get_tiles (string mon, int cols, int rows) throws Error;
        public abstract void move_window (int wid, int x, int y, int width, int height, bool nowarning = false) throws Error;
        public abstract void move_window_animated (int wid, int x, int y, int width, int height) throws Error;
        public abstract int[] get_winspecs (int w_id) throws Error;
        public abstract bool check_ifguiruns () throws Error;
        public abstract int check_windowvalid (int wid) throws Error;
        public abstract bool get_softmove () throws Error;
        public abstract bool get_general_animations_set () throws Error;
        public abstract int[] get_margins () throws Error;
        public abstract void toggle_maximize (int w_arg) throws Error;
        public abstract GLib.HashTable<string, Variant> get_monitorgeometry () throws Error;
    }

    private bool string_inlist (string lookfor, string[] arr) {
        for (int i=0; i < arr.length; i++) {
            if (lookfor == arr[i]) {
                return true;
            }
        }
        return false;
    }

    private bool monitor_isvalid (

        // check if the set monitor argument is valid (monitor exists and is connected)
        ShufflerInfoClient client, string monitor, GLib.HashTable<string, Variant> monitordata
    ) {
        // see if monitor arg is valid (monitor connected)
        string[] found_monitors = {};
        foreach (string k in monitordata.get_keys()) {
            found_monitors += k;
        }
        if (string_inlist(monitor, found_monitors)) {
            return true;
        }
        return false;
    }

    private bool[] check_position_isequal (int[] origin, int[] target, int[] margins) {

        /*
        / if target position is equal to current (size isn't) ->
        / switch off softmove (not in this method though)
        / if also size is equal, do nothing
         */
        bool pos_isequal = true;
        bool size_isequal = true;
        int padding = margins[4];
        bool[] checks = {
            origin[0] == target[0],
            origin[1] == target[1],
            /*
            for reasons of minimum resize steps per application, making
            Wnck resize a window to size x pixels, occasionally results
            in x+1 pixels. that is an issue when we want to check if the
            window already is moved & sized to a certain q-tile or not.
            therefore, we allow a difference of max 2 px, which does most
            likely exist -ever- coincidentally, and assuming window is
            already moved to position is safe.
            */
            (origin[2] - (target[2] - padding)).abs() < 3,
            (origin[3] - (target[3] - padding)).abs() < 3
        };
        for (int i = 0; i < 2; i++) {
            if (checks[i] == false) {
                pos_isequal = false;
            }
        }
        for (int i = 2; i < 4; i++) {
            if (checks[i] == false) {
                size_isequal = false;
            }
        }
        bool[] tests = {pos_isequal, size_isequal};
        return tests;
    }

    private int? try_isint (string stringarg) {
        int foundint = int.parse (stringarg);
        if (foundint != 0 ||(stringarg == "0" && foundint == 0)) {
            return foundint;
        }
        return null;
    }

    public static void main(string[] args) {

        int x_ongrid = 0;
        int y_ongrid = 0;
        int gridcols = 2;
        int gridrows = 2;
        int xspan = 1;
        int yspan = 1;
        bool maximize = false;
        // monitor is what we eventually use
        string monitor = "";
        // set_monitor is the possibly set argument
        string set_monitor = "";
        bool set_nosoftmove = false;
        bool call_fromwindowrule = false;
        bool call_fromgrid = false;
        // xid is what we eventually use
        int xid = -1;
        // set_xid is the possibly set argument
        int set_xid = -1;
        // parse args, first four or six are int
        int argindex = 0;
        foreach (string arg in args[1:args.length]) {
            int? new_arg = try_isint(arg);
            if (new_arg != null) {
                switch (argindex) {
                    case 0:
                    // targeted xposition in grid
                    x_ongrid = new_arg;
                    break;
                    case 1:
                    // targeted yposition in grid
                    y_ongrid = new_arg;
                    break;
                    case 2:
                    // grid size hor
                    gridcols = new_arg;
                    break;
                    case 3:
                    // grid size vert
                    gridrows = new_arg;
                    break;
                    case 4:
                    // span xsize of targeted windowposition
                    xspan = new_arg;
                    break;
                    case 5:
                    // span ysize of targeted windowposition
                    yspan = new_arg;
                    break;
                }
            }
            else {
                if (arg == "maximize") {
                    // whether to use maximize instead of move
                    maximize = true;
                }
                else if (arg.contains("monitor=")) {
                    // whether we should use alternative target monitor
                    set_monitor = arg.split("=")[1];
                }
                else if (arg.contains("nosoftmove")) {
                    // whether to skip (possible) animation.
                    // this is a.o. for secondary windows if sticky windows is set
                    set_nosoftmove = true;
                }
                if (arg == "windowrule") {
                    // why was this again? ->
                    call_fromwindowrule = true;
                }
                if (arg == "fromgrid") { // arg is set from gui grid, applied?
                    // why was this again? -> because then we need to run, despite the fact that gui runs
                    call_fromgrid = true;
                }
                else if (arg.contains("id=")) {
                    set_xid = int.parse(arg.split("=")[1]);
                }
            }
            argindex += 1;
        }
        // tilename (key) to find matching tile
        string target_tilekey = @"$x_ongrid" + "*" + @"$y_ongrid";
        // additional args & data, from daemon
        try {
            client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );
            GLib.HashTable<string, Variant> windata = client.get_winsdata ();
            //  windata = client.get_winsdata ();
            GLib.List<unowned string> windata_keys = windata.get_keys ();
            //  windata_keys = windata.get_keys ();
            int[] margins = client.get_margins ();
            // decide which window is subject
            xid = set_xid;
            if (set_xid == -1) {
                xid = client.getactivewin();
            }
            if (maximize) {;
                client.toggle_maximize(xid);
                Process.exit(0);
            }
            // and get its yshift
            int yshift = 0;
            yshift = client.get_winspecs(xid)[0];
            // now find winsubject_data on subject window for further processing
            Variant winsubject_data = new Variant (
                "(sssiiiiss)", "", "", "", -1, -1, -1, -1, "", ""
            );
            foreach (string s in windata_keys) {
                if (@"$xid" == s) {;
                    winsubject_data = windata[s];
                }
            }
            // decide which monitor to use, check if set monitor is valid (& connected)
            monitor = (string)winsubject_data.get_child_value(2);
            GLib.HashTable<string, Variant> monitordata = client.get_monitorgeometry ();
            if (set_monitor != "" && monitor_isvalid(client, set_monitor, monitordata)) {
                monitor = set_monitor;
            }
            // if guiruns (= desktop grid gui), switch off tiling
            // -unless- "fromgrid" is set as arg, then: move without animation
            bool guiruns = client.check_ifguiruns();
            // positioncheck here, to decide on sofmove & run at all
            // tile (target) position & size
            HashTable<string, Variant> tiles = client.get_tiles(
                monitor, gridcols, gridrows
            );
            // get target width/height
            int target_width = (int)tiles["tilewidth"] * xspan;
            int target_height = (int)tiles["tileheight"] * yspan;
            // get x / y
            int tile_x = 0;
            int tile_y = 0;
            foreach (string k in tiles.get_keys()) {
                if (k == target_tilekey) {
                    Variant target_tile = tiles[k];
                    tile_x = (int)target_tile.get_child_value(0);
                    tile_y = (int)target_tile.get_child_value(1);
                }
            }
            int[] tilepos_data = {tile_x, tile_y, target_width, target_height};
            // window current position & size
            int[] winpos_data = {};
            int[] pos_indices = {3, 4, 5, 6};
            foreach (int i in pos_indices) {
                winpos_data += (int)winsubject_data.get_child_value(i);
            }
            bool[] checked_equal = check_position_isequal(winpos_data, tilepos_data, margins);
            foreach (bool test in checked_equal) {
            }
            bool nosoftmove_forpositionarg = false;
            bool norun_forpositionarg = false;


            if (checked_equal[0] == true && checked_equal[1] == false) {
                nosoftmove_forpositionarg = true;
            }
            else if (checked_equal[0] == true && checked_equal[1] == true) {
                norun_forpositionarg = true;
            }
            // see if any disqualifying args for softmove
            bool use_softmove = true;
            bool global_animation = client.get_softmove();
            if (!global_animation || set_nosoftmove || nosoftmove_forpositionarg) {
                use_softmove = false;
            }
            /*
            / see if any disqualifying args to run at all
            / if guiruns (= desktop grid gui), don't run
            / -unless- "fromgrid" is set as arg, then: move without animation
            / "nosoftmove" should then be set from grid, see above)
            */
            bool run = true;
            if ((guiruns && !call_fromgrid) || norun_forpositionarg) {
                run = false;
            }
            // finally, let's get the job done, it's been long enough
            if (run) {
                if (use_softmove) {
                    client.move_window_animated(
                        xid, tile_x, tile_y - yshift,
                        target_width, target_height
                    );
                }
                else {
                    client.move_window(
                        xid, tile_x, tile_y - yshift,
                        target_width, target_height
                    );
                }
            }
            // add if samepos && samesize here -> done
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }
}




