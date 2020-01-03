
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

// valac --pkg gio-2.0 --pkg gdk-x11-3.0 --pkg gtk+-3.0 -X -lm


namespace GridAll {

    ShufflerInfoClient client;

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        //  public abstract int getactivewin () throws Error;
        public abstract HashTable<string, Variant> get_tiles (string mon, int cols, int rows) throws Error;
        public abstract void move_window (int wid, int x, int y, int width, int height) throws Error;
        public abstract int get_yshift (int w_id) throws Error;
        public abstract string getactivemon_name () throws Error;
        public abstract int[] get_grid () throws Error;
    }

    private int get_stringindex (string s, string[] arr) {
        // get index of a string in an array
        for (int i=0; i < arr.length; i++) {
            if(s == arr[i]) return i;
        } return -1;
    }

    private string[] make_tilekeys (int cols, int rows) {
        /*
        / we receieve the hastable keys in an unordered manner
        / so we need to reconstruc an ordered one to work with
        */
        string[] key_arr = {};

        for (int r=0; r< rows; r++) {
            for (int c=0; c < cols; c++) {
                key_arr += @"$c*$r";
            }
        }
        return key_arr;
    }

    private string[] remove_arritem (string s, string[] arr) {
        // remove a string from an array (window id in this case)
        string[] newarr = {};
        foreach (string item in arr) {
            if (item != s) {
                newarr += item;
            }
        }
        return newarr;
    }

    private double get_distance (double x1, double y1, double x2, double y2) {
        // calc distance between two coords
        double x_comp = Math.pow(x1 - x2, 2);
        double y_comp = Math.pow(y1 - y2, 2);
        return Math.pow(x_comp + y_comp, 0.5);
    }


    private int get_windowindex (
        double x, double y, string[] id_array, HashTable<string, Variant> wins
    ) {
        // get index of nearest window in window id list
        int curr_index = 0;
        int current_nearest = 0;
        double distance = 10000000;
        foreach (string id in id_array) {
            Variant currsubj = wins[id];
            double currx = (double)(int)currsubj.get_child_value(3);
            double curry = (double)(int)currsubj.get_child_value(4);
            double newdistance = get_distance(x, y, currx, curry);
            if (newdistance < distance) {
                distance = newdistance;
                current_nearest = curr_index;
            }
            curr_index += 1;
        }
        return current_nearest;
    }

    private void grid_allwindows (int[] geo_args) {
        // split args for readability please

        /*
        / 1. make array of window ids. then:
        / 2. create sorted key list from args
        / 3. per tile, see what window is closest (lookup distance -from- id-array -in- hashtable)
        / 4. move window, remove id from array
        /
        / repeat until out of windows (id array is empty, cycle through tiles if needed)
        */
        HashTable<string, Variant>? tiles = null;
        HashTable<string, Variant>? wins = null;
        // get monitor name
        string mon_name = "none";
        try {
            // get active monitorname by active window ("" if null)
            mon_name = client.getactivemon_name();
            tiles = client.get_tiles(
                mon_name, geo_args[0], geo_args[1]
            );
        }
        catch (Error e) {
        }
        // 1. get valid windows, populate id_array
        string[] id_array = {};
        try {
            wins = client.get_winsdata();
            foreach (string k in wins.get_keys()) {
                Variant got_data = wins[k];
                // on current workspace?
                bool exclude = (string)got_data.get_child_value(0) == "Gridwindows";
                bool onthisws = (string)got_data.get_child_value(1) == "true";
                // on active monitor?
                bool onthismon = (string)got_data.get_child_value(2) == mon_name;
                if (onthisws && onthismon && !exclude) { //////////////////////////////////////////
                    id_array += k;
                }
            }
        }
        catch (Error e) {
        }
        // 2. create sorted tile list
        string[] ordered_keyarray = make_tilekeys(geo_args[0], geo_args[1]);
        // 2a. fetch unordered tiles-hashtable to look up from
        if (tiles != null) {
            // insert from test
            int ntiles = ordered_keyarray.length;
            int i_tile = 0;
            while (id_array.length > 0) {
                string currtile = ordered_keyarray[i_tile];
                // get xy on current tile:
                Variant tilevar = tiles[currtile];
                double x = (double)(int)tilevar.get_child_value(0);
                double y = (double)(int)tilevar.get_child_value(1);
                // now look through windows for nearest, remove match from id_array afterwards
                int neares_wid = get_windowindex(x, y, id_array, wins);
                string window_id = id_array[neares_wid];
                // NB index is calculated nearest from tile -> hastable x-y and windowid -> wins hastable
                // now move
                int num_wid = int.parse(window_id);
                int yshift = 0;
                try {
                    yshift = client.get_yshift(num_wid);
                }
                catch (Error e) {
                }
                try {
                    client.move_window(
                        num_wid, (int)x, (int)y - yshift,
                        (int)tilevar.get_child_value(2),
                        (int)tilevar.get_child_value(3)
                    );
                }
                catch (Error e) {
                }
                // here the removal is done:
                id_array = remove_arritem(window_id, id_array);
                i_tile += 1;
                if (i_tile == ntiles) {
                    i_tile = 0;
                }
            }
        }
    }

    public static void main(string[] args) {
        try {
            client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );
            int[] grid = client.get_grid ();
            string[] arglist = {
                "--cols", "--rows", "--left", "--right", "--top", "--bottom"
            };
            int[] passedargs = {grid[0], grid[1], 0, 0, 0, 0};

            int i = 0;
            foreach (string s in args) {
                int argindex = get_stringindex(s, arglist);
                if (argindex != -1 ) {
                    int fetch_arg = i+1;
                    if (fetch_arg < args.length) {
                        int val = int.parse(args[fetch_arg]);
                        passedargs[argindex] = val;
                    }
                    else {
                        print(@"missing value of: $s\n");
                    }
                }
                i += 1;
            }
            // last four args still need to be implemented in daemon!
            // (if we want to be able to set margins to area)
            grid_allwindows({
                passedargs[0],
                passedargs[1],
                passedargs[2],
                passedargs[3],
                passedargs[4],
                passedargs[5]
            });
        }

        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }
}