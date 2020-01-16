using Math;

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

// valac --pkg gio-2.0 -X -lm
namespace ExtendWindow {

    string action;
    ShufflerInfoClient client;

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        public abstract HashTable<string, Variant> get_tiles (string mon, int cols, int rows) throws Error;
        public abstract string getactivemon_name () throws Error;
        public abstract int[] get_grid () throws Error;
        public abstract int getactivewin () throws Error;
    }

    private bool check_ifongrid (int x, int y, string key, Variant tile) {
        if (key.contains("*")) {
            int tile_x = (int)tile.get_child_value(0);
            int tile_y = (int)tile.get_child_value(1);
            if (tile_x == x && tile_y == y) {
                return true;
            }
        }
        return false;
    }

    private void extend_horizontally (
        int x, int y, Variant matchingvar, Variant winvar,
        int gridcols, int gridrows, string xid_str, string key
    ) {
        // we -need- to take the current x/y position into account -and-
        // need to set on exact cell size
        int curr_gridposx = int.parse(key.split("*")[0]);
        int curr_gridposy = int.parse(key.split("*")[1]);
        int tilewidth = (int)matchingvar.get_child_value(2);
        int tileheight = (int)matchingvar.get_child_value(3);
        double winwidth = (double)(int)winvar.get_child_value(5);
        double winheight = (double)(int)winvar.get_child_value(6);
        double xspan = Math.round(winwidth/tilewidth);
        double yspan = Math.round(winheight/tileheight);
        bool resize = false;

        switch (action) {
            case "-x":
                if (xspan > 1) {
                    xspan = xspan - 1;
                    resize = true;
                }
                break;
            case "+x":
                if (xspan + curr_gridposx < gridcols) {
                    xspan = xspan + 1;
                    resize = true;
                }
                break;
            case "-y":
                if (yspan > 1) {
                    yspan = yspan - 1;
                    resize = true;
                }
                break;
            case "+y":
                if (yspan + curr_gridposy < gridrows) {
                    yspan = yspan + 1;
                    resize = true;
                }
                break;
        }
        if (resize) {
            string cm = Config.PACKAGE_LIBDIR + "/tile_active ".concat(
                @"$curr_gridposx $curr_gridposy $gridcols ",
                @"$gridrows $xspan $yspan $xid_str"
            );
            try {
                Process.spawn_command_line_async(cm);
            }
                catch (SpawnError e) {
            }
        }
    }

    public static void main (string[] args) {
        action = args[1];
        try {
            client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );
            // get active window
            int activewin = client.getactivewin();
            // get data on (normal) windows, look up active
            HashTable<string, Variant> windata = client.get_winsdata();
            foreach (string k in windata.get_keys()) {
                if (k == @"$activewin") {
                    Variant winvar = windata[k];
                    int xpos = (int)winvar.get_child_value(3);
                    int ypos = (int)winvar.get_child_value(4);
                    // look up monitorname, tiledata
                    string monname = client.getactivemon_name();
                    int[] colsrows = client.get_grid();
                    int gridcols = colsrows[0];
                    int gridrows = colsrows[1];
                    HashTable<string, Variant> tiledata = client.get_tiles(
                        monname, gridcols, gridrows
                    );
                    foreach (string s in tiledata.get_keys()) {
                        Variant matchingvar = tiledata[s];
                        // check if the window is on a gridposition
                        if (check_ifongrid(xpos, ypos, s, matchingvar)) {
                            extend_horizontally(
                                xpos, ypos, matchingvar,
                                winvar, gridcols, gridrows, k, s
                            );
                            break;
                        }
                    }
                    break;
                }
            }
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }
}