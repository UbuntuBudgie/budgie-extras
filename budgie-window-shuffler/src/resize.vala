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
    HashTable<string, Variant> tiledata;
    HashTable<string, Variant> windata;
    int activewin;
    bool stickyneighbors;

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        public abstract HashTable<string, Variant> get_tiles (string mon, int cols, int rows) throws Error;
        public abstract string getactivemon_name () throws Error;
        public abstract int[] get_grid () throws Error;
        public abstract int getactivewin () throws Error;
        public abstract void activate_window (int curr_active) throws Error;
        public abstract bool get_stickyneighbors () throws Error;
    }

    private Variant? check_ifongrid (int x, int y) {
        foreach (string s in tiledata.get_keys()) {
            if ("*" in s) {
                Variant tile = tiledata[s];
                int tile_x = (int)tile.get_child_value(0);
                int tile_y = (int)tile.get_child_value(1);
                /*
                / due to rounding differences and (more likely) window default's
                / resize step size on specific resolutions and/or windows,
                / allow a 2px deviation, considering if a window is on grid or not
                */
                if (x - 3 < tile_x < x + 3  && y - 3 < tile_y < y + 3) {
                  return tile;
                }
            }
        }
        return null;
    }

    private bool check_overlap (int a1, int a2, int b1, int b2) {
        // function to see if two lines, in a single dimension, have a common
        // length (> a mathematic dot)
        bool check_below = a1 <= b1 && a1 <= b2 && a2 <= b1 && a2 <= b2;
        bool check_above = a1 >= b1 && a1 >= b2 && a2 >= b1 && a2 >= b2;
        return (check_below || check_above);
    }

    private void resize_validadjacent (
        int[] adjacents, int tilewidth, int tileheight, string action,
        int gridcols, int gridrows, string xid_active,
        int main_curr_gridposx, int main_curr_gridposy, int main_xspan, int main_yspan
    ) {
        // adjecents are: adjacent_left, adjacent_right, adjacent_top, adjacent_bottom
        // just for testing during develpoment:
        //
        int curr_index = 0;
        int found_adjacent = -1;
        foreach (int n in adjacents) {
            if (n != -1) {
                found_adjacent = n;
                break;
            }
            curr_index += 1;
        }

        /*
        / if (index == 0) -> look for windows on the left, that is:
        / -right- side of window is found_adjacent, resize: -x or +x (y- overlap test / fits in current rows/cols?)
        / else if (index == 1) -> look for windows on the right, that is:
        / -left- side of window is found_adjacent, resize: -x-left or +x-left (y- overlap test / fits in current rows/cols?)
        / else if (index == 2) -> look for windows above, that is:
        / -top- side of window is found_adjacent, resize: -y or +y (x- overlap test / fits in current rows/cols?)
        / else if (index == 3) -> look for windows below, that is:
        / -bottom- side of window is found_adjacent, resize: -y-top or +y-top (x- overlap test / fits in current rows/cols?)
        */

        foreach (string winkey in windata.get_keys()) {
            // windata: xid = key. then: name, onthisworspace, monitor-of-window, geometry, minimized, wmclass
            // retrieve needed type of action on secundary windows from the -adjacents- index and the argument -action-
            Variant winvar = windata[winkey];
            int winx = (int)winvar.get_child_value(3);
            int winy = (int)winvar.get_child_value(4);
            bool onthisworspace = (string)winvar.get_child_value(1) == "true";
            bool minimized = (string)winvar.get_child_value(7) == "true";
            Variant tilevar = check_ifongrid(winx, winy);
            // if other windows are on grid, check if they are subject to checking
            if (tilevar != null && onthisworspace && !minimized && xid_active != winkey) {
                // tiledata: cols/rows
                // left, top
                string gridpos_key = (string)tilevar.get_child_value(4);
                string[] posdata = gridpos_key.split("*");
                int gridx = int.parse(posdata[0]);
                int gridy = int.parse(posdata[1]);
                // right, bottom
                double winwidth = (double)(int)winvar.get_child_value(5);
                double winheight = (double)(int)winvar.get_child_value(6);
                double xspan = Math.round(winwidth/tilewidth);
                double yspan = Math.round(winheight/tileheight);
                // so, resuming -> needed for overlap check
                int left = gridx;
                int right = (int)(gridx + xspan);
                int top = gridy;
                int bottom = (int)(gridy + yspan);
                string cm = "";
                bool overlap = false;
                bool resize_neighbour = false;
                // here we go
                // note: left, right, top, bottom is about secundary window(!) right?
                switch (curr_index) {
                    case 0:
                        if (right == found_adjacent) {
                            if (xspan > 1 && action == "+x-left") {
                                xspan = xspan -1;
                                resize_neighbour = true;
                            }
                            else if (action == "-x-left") {
                                xspan = xspan +1;
                                resize_neighbour = true;
                            }
                        }
                        // check overlap
                        int windowtop = main_curr_gridposy;
                        int windowbottom = main_curr_gridposy + main_yspan;
                        overlap = !check_overlap(top, bottom, windowtop, windowbottom);
                        break;
                    case 1:
                        if (left == found_adjacent) {
                            if (xspan > 1 && action == "+x") {
                                xspan = xspan - 1;
                                gridx = gridx + 1;
                                resize_neighbour = true;
                            }
                            else if (action == "-x") {
                                xspan = xspan + 1;
                                gridx = gridx - 1;
                                resize_neighbour = true;
                            }
                        }
                        // check overlap
                        int windowtop = main_curr_gridposy;
                        int windowbottom = main_curr_gridposy + main_yspan;
                        overlap = !check_overlap(top, bottom, windowtop, windowbottom);
                        break;

                    case 2:
                        if (bottom == found_adjacent) {
                            if (yspan > 1 && action == "+y-top") {
                                yspan = yspan -1;
                                resize_neighbour = true;
                            }
                            else if (action == "-y-top") {
                                yspan = yspan +1;
                                resize_neighbour = true;
                            }
                        }
                        // check overlap
                        int windowleft = main_curr_gridposx;
                        int windowright = main_curr_gridposx + main_xspan;
                        overlap = !check_overlap(left, right, windowleft, windowright);
                        break;
                    case 3:
                        if (top == found_adjacent) {
                            if (yspan > 1 && action == "+y") {
                                yspan = yspan - 1;
                                gridy = gridy + 1;
                                resize_neighbour = true;
                            }
                            else if (action == "-y") {
                                yspan = yspan + 1;
                                gridy = gridy - 1;
                                resize_neighbour = true;
                            }
                        }
                        // check overlap
                        int windowleft = main_curr_gridposx;
                        int windowright = main_curr_gridposx + main_xspan;
                        overlap = !check_overlap(left, right, windowleft, windowright);
                        break;
                }
                if (overlap && resize_neighbour) {
                    cm = Config.SHUFFLER_DIR + "/tile_active ".concat(
                    //  cm = "/usr/lib/budgie-window-shuffler/tile_active ".concat(
                            @"$gridx $gridy $gridcols ",
                            @"$gridrows $xspan $yspan nosoftmove id=$winkey"
                    );
                    try {
                        Process.spawn_command_line_sync(cm, null, null, null);
                    }
                    catch (SpawnError e) {
                    }
                }
            }
        }
        Thread.usleep(15000);
        try {
            client.activate_window (activewin);
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    private void resize_window (
        int x, int y, Variant cellvar, Variant winvar,
        int gridcols, int gridrows, string xid_str, string key
    ) {
        // we -need- to take the current x/y position into account -and-
        // need to set on exact cell size
        int curr_gridposx = int.parse(key.split("*")[0]);
        int curr_gridposy = int.parse(key.split("*")[1]);
        int tilewidth = (int)cellvar.get_child_value(2);
        int tileheight = (int)cellvar.get_child_value(3);
        double winwidth = (double)(int)winvar.get_child_value(5);
        double winheight = (double)(int)winvar.get_child_value(6);
        double xspan = Math.round(winwidth/tilewidth);
        double yspan = Math.round(winheight/tileheight);
        bool resize = false;
        // adjecents are positions on all sides of the main subject window
        // to take into account
        int adjacent_right = -1;
        int adjacent_bottom = -1;
        int adjacent_left = -1;
        int adjacent_top = -1;

        switch (action) {
            case "-x":
                if (xspan > 1) {
                    adjacent_right = (int)(curr_gridposx + xspan);
                    xspan = xspan - 1;
                    resize = true;
                }
                break;
            case "+x":
                if (xspan + curr_gridposx < gridcols) {
                    adjacent_right = (int)(curr_gridposx + xspan);
                    xspan = xspan + 1;
                    resize = true;
                }
                break;
            case "-y":
                if (yspan > 1) {
                    adjacent_bottom = (int)(curr_gridposy + yspan);
                    yspan = yspan - 1;
                    resize = true;
                }
                break;
            case "+y":
                if (yspan + curr_gridposy < gridrows) {
                    adjacent_bottom = (int)(curr_gridposy + yspan);
                    yspan = yspan + 1;
                    resize = true;
                }
                break;
            case "+x-left":
                if (curr_gridposx != 0) {
                    adjacent_left = curr_gridposx;
                    xspan = xspan + 1;
                    curr_gridposx = curr_gridposx -1;
                    resize = true;
                }
                break;
            case "-x-left":
                if (xspan > 1) {
                    adjacent_left = curr_gridposx;
                    xspan = xspan - 1;
                    curr_gridposx = curr_gridposx + 1;
                    resize = true;
                }
                break;
            case "+y-top":
                if (curr_gridposy != 0) {
                    adjacent_top = curr_gridposy;
                    yspan = yspan + 1;
                    curr_gridposy = curr_gridposy - 1;
                    resize = true;
                }
                break;
            case "-y-top":
                if (yspan > 1) {
                    adjacent_top = curr_gridposy;
                    yspan = yspan - 1;
                    curr_gridposy = curr_gridposy + 1;
                    resize = true;
                }
                break;
        }

        if (resize) {
            // just keep for standalone testing + quick compile:
            string cm = Config.SHUFFLER_DIR + "/tile_active ".concat(
            //  string cm = "/usr/lib/budgie-window-shuffler/tile_active ".concat(
                @"$curr_gridposx $curr_gridposy $gridcols ",
                @"$gridrows $xspan $yspan"
            );
            try {
                Process.spawn_command_line_sync(cm, null, null, null);
            }
                catch (SpawnError e) {
            }
            // I know, many args but hey, I need them and I already got them
            if (stickyneighbors) {
                resize_validadjacent(
                    {adjacent_left, adjacent_right, adjacent_top, adjacent_bottom},
                    tilewidth, tileheight, action, gridcols, gridrows, xid_str,
                    curr_gridposx, curr_gridposy, (int)xspan, (int)yspan
                );
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
            // get stickyneighbours settings
            stickyneighbors = client.get_stickyneighbors();
            // get active window
            activewin = client.getactivewin();
            // look up monitorname, tiledata
            string monname = client.getactivemon_name();
            int[] colsrows = client.get_grid();
            int gridcols = colsrows[0];
            int gridrows = colsrows[1];
            tiledata = client.get_tiles(
                monname, gridcols, gridrows
            );
            // get data on (normal) windows, look up active
            windata = client.get_winsdata();
            foreach (string winkey in windata.get_keys()) {
                /*
                / get data on all windows here? more efficient, but nah,
                / let's keep it simple, get data on adjacent windows separated,
                / dbus is fast. long live dbus.
                */
                if (winkey == @"$activewin") {
                    Variant winvar = windata[winkey];
                    int xpos = (int)winvar.get_child_value(3);
                    int ypos = (int)winvar.get_child_value(4);
                    Variant matching_cell = check_ifongrid(xpos, ypos);
                    if (matching_cell != null) {
                        string tilekey = (string)matching_cell.get_child_value(4);
                        resize_window(
                            xpos, ypos, matching_cell,
                            winvar, gridcols, gridrows, winkey, tilekey
                        );
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