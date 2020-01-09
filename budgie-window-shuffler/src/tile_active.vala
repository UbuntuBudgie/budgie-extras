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

// valac --pkg gio-2.0

/*
/ args:
/ |--x/y--| |--cols/rows--|
/  int int      int int
/ or:
/ |--x/y--| |--cols/rows--| |--xspan/yspan--|
/  int int      int int          int int
/ or:
/ maximize
/ optional -last arg- custom numeric window id (instead of active):
/ id=12345678 <- no hex!
*/

namespace TileActive {

    GLib.HashTable<string, Variant> windata;
    GLib.List<unowned string> windata_keys;

    ShufflerInfoClient? client;
    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        public abstract int getactivewin () throws Error;
        public abstract HashTable<string, Variant> get_tiles (string mon, int cols, int rows) throws Error;
        public abstract void move_window (int wid, int x, int y, int width, int height) throws Error;
        public abstract int get_yshift (int w_id) throws Error;
        public abstract int toggle_maximize (int w_id) throws Error;
        public abstract bool check_ifguiruns () throws Error;
        public abstract int check_windowvalid (int wid) throws Error;
    }

    void main (string[] args) {
        try {
            client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );
            // get data, geo on windows
            windata = client.get_winsdata();
            windata_keys = windata.get_keys();
            // if guiruns, only act on window from args
            bool guiruns = client.check_ifguiruns();
            // check if we should use window from set args
            int activewin;
            string lastarg = args[args.length - 1];
            bool surpass_blocking = lastarg.contains("id=");
            if (surpass_blocking) {
                activewin = int.parse(lastarg.split("=")[1]);
            }
            else {
                activewin = client.getactivewin();
            }
            bool run = (!guiruns || surpass_blocking);
            activewin = client.check_windowvalid(activewin);

            if (run && activewin != -1) {
                if (args.length >= 7) {
                    int ntiles_x = int.parse(args[5]);
                    int ntiles_y = int.parse(args[6]);
                    if (
                        int.parse(args[1]) + ntiles_x <= int.parse(args[3])  &&
                        int.parse(args[2]) + ntiles_y <= int.parse(args[4])
                    ) {
                        grid_window(args, ntiles_x, ntiles_y, activewin);
                    }
                    else {
                        print("size exceeds monitor size\n");
                    }
                }

                else if (args.length >= 5) {
                    if (
                        int.parse(args[1]) < int.parse(args[3]) &&
                        int.parse(args[2]) < int.parse(args[4])
                    ) {
                        grid_window(args, 1, 1, activewin);
                    }
                    else {
                        print("position is outside monitor\n");
                    }
                }

                else if (args.length >= 2) {
                    string arg = (args[1]);
                    if (arg == "maximize") {
                        // ok, for the sake of simplicity,
                        // let's allow one internal action
                        int win_id = client.getactivewin();
                        client.toggle_maximize(win_id);
                    }
                    else {
                        print(@"Unknown argument: $arg\n");
                    }
                }
            }
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    void grid_window (
        string[] args, int ntiles_x, int ntiles_y, int activewin
        ) {
        // fetch info from daemon, do the job with it
        try {
            // vars
            int yshift = 0;
            string winsmonitor = "";
            foreach (string s in windata_keys) {
                if (int.parse(s) == activewin) {
                    yshift = client.get_yshift(activewin);
                    Variant currwindata = windata[s];
                    winsmonitor = (string)currwindata.get_child_value(2);
                }
            }
            // get tiles -> matching tile
            HashTable<string, Variant> tiles = client.get_tiles(
                winsmonitor, int.parse(args[3]), int.parse(args[4])
            );
            GLib.List<unowned string> tilekeys = tiles.get_keys();
            int orig_width = (int)tiles["tilewidth"];
            int orig_height = (int)tiles["tileheight"];
            foreach (string tilename in tilekeys) {
                // if key matches -> get tile pos & size -> move
                if (args[1].concat("*", args[2]) == tilename) {
                    Variant currtile = tiles[tilename];
                    int tile_x = (int)currtile.get_child_value(0);
                    int tile_y = (int)currtile.get_child_value(1);
                    int tile_wdth = orig_width * ntiles_x;
                    int tile_hght = orig_height * ntiles_y;
                    client.move_window(
                        activewin, tile_x, tile_y - yshift,
                        tile_wdth, tile_hght
                    );
                }
            }
        }
        catch (Error e) {
                stderr.printf ("%s\n", e.message);
        }
    }
}