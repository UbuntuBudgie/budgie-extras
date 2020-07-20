using Gtk;
using Wnck;

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

// valac --pkg gtk+-3.0 --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE"

/*
/ args:
/ command to open the window | WM_CLASS | xpos | ypos | gridsize_hor | gridsize_vert
/ optionally: xspan | yspan
/ if command to open the window includesa spaces, place it between ' '
*/

namespace PlaceWindow {

    Wnck.Screen wnck_scr;
    ulong[] currwindows;
    string groupname;
    string tile_x;
    string tile_y;
    string cols;
    string rows;
    string xspan;
    string yspan;

    private void act_onnewwindow (Wnck.Window newwin) {
        ulong x_id = newwin.get_xid ();
        // check if the window is really new
        bool existed = false;
        foreach (ulong xid in currwindows) {
            if (x_id == xid) {
                existed = true;
            }
        }
        // if it is -and- the new window is from the application we started, move it
        if (
            newwin.get_class_group_name ().down () == groupname.down () &&
            !existed
        ) {
            string[] geo_args = {
                tile_x, tile_y, cols, rows, @"$xspan", @"$yspan", @"id=$x_id"
            };
            //  string command = "/usr/lib/budgie-window-shuffler/tile_active".concat(
            string command = Config.SHUFFLER_DIR.concat (
                "/tile_active", " ", string.joinv(" ", geo_args)
            );
            // print(@"$command");
            try {
                Process.spawn_command_line_async (command);
            }
            catch (Error e) {
                print ("Failed to set position of window\n");
            }
            Gtk.main_quit ();
        }
    }

    public static void main (string[] args) {

        // let's initiate args to run tile_active
        xspan = "";
        yspan = "";
        groupname = args[2];
        tile_x = args[3];
        tile_y = args[4];
        cols = args[5];
        rows = args[6];
        int n_args = args.length;
        if (n_args == 9) {
            xspan = args[7];
            yspan = args[8];
        }
        /*
        / if args are sufficient, proceed. we need at least col + row and
        / grid size (cols/rows). xspan and yspan are optional.
        */
        if (n_args == 7 || n_args == 9) {
            Gtk.init (ref args);
            wnck_scr = Wnck.Screen.get_default ();
            wnck_scr.force_update ();
            // get existing windows first
            unowned GLib.List<Wnck.Window> currwins = wnck_scr.get_windows ();
            foreach (Wnck.Window w in currwins) {
                ulong xid = w.get_xid ();
                currwindows += xid;
            }
            // now watch newly created windows. if the subject appears, move it
            wnck_scr.window_opened.connect (act_onnewwindow);
            // after 10 seconds, give up waiting, exit
            GLib.Timeout.add_seconds (10, ()=> {
                Gtk.main_quit ();
                return false;
            });
            // running the command to open the window in the first place
            try {
                Process.spawn_command_line_async (args[1]);
            }
            catch (Error e) {
                print ("Cannot open new window\n");
            }
            Gtk.main ();
        }
        else {
            print ("insufficient arguments\n");
        }
    }
}