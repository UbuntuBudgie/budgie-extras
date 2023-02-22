using Gtk;
using Gdk;
using Gdk.X11;

/*
Budgie WindowPreviews
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

namespace fixpreviews {

    class ShootWindow {

        Gdk.Screen? gdkscr;
        Gdk.X11.Display? gdkdsp = (Gdk.X11.Display)Gdk.Display.get_default();
        double threshold = 260.0/160.0;
        string previewspath;

        public ShootWindow(int? winid = null) {
            make_prvpath();
            gdkscr = Gdk.Screen.get_default();
            select_wins(winid);
        }

        private void make_prvpath () {
            // make previews path
            string user = Environment.get_user_name();
            var tmp = Environment.get_tmp_dir() + "/";
            previewspath = tmp.concat(user, "_window-previews");

            try {
                File file = File.new_for_commandline_arg (previewspath);
                file.make_directory ();
            } catch (Error e) {
                // directory exists, no action needed
            }
        }

        private int[] get_winspecs(Gdk.Window w) {
            /* fetch xid and workspace */
            Gdk.X11.Window x11_w = (Gdk.X11.Window)w;
            int xid = (int)x11_w.get_xid();
            int workspace = (int)x11_w.get_desktop();
            return {xid, workspace};
        }

        private void select_wins(int? winid = null) {
            /* if args are provided, select one, else all valid windows (startup) */
            GLib.List<Gdk.Window> gdk_winlist = gdkscr.get_window_stack();
            foreach (Gdk.Window w in gdk_winlist) {
                int[] needlespecs = get_winspecs(w);
                if (w.get_type_hint() == Gdk.WindowTypeHint.NORMAL) {
                    if (winid != null && needlespecs[0] == winid) {
                        update_preview(w, needlespecs);
                        return;
                    }
                    else if (winid == null) {update_preview(w, needlespecs);}
                }
            }
        }

        private int[] determine_sizes (
            Gdk.Pixbuf? pre_shot, double xsize, double ysize
        ) {
            // calculates targeted sizes
            int targetx = 0;
            int targety = 0;
            double prop = (double)(xsize / ysize);
            // see if we need to pick xsize or ysize as a reference
            if (prop >= threshold) {
                targetx = 260;
                targety = (int)((260 / xsize) * ysize);
            }
            else {
                targety = 160;
                targetx = (int)((160 / ysize) * xsize);
            }
            return {targetx, targety};
        }

        private void update_preview (Gdk.Window window, int[] specs) {
            // no filter on type needed, is done already
            gdkdsp.error_trap_push();
            if (!window.is_viewable()) {return;}
            int width = window.get_width();
            int height = window.get_height();
            Gdk.Pixbuf? currpix = Gdk.pixbuf_get_from_window(window, 0, 0, width, height);
            int name_xid = specs[0]; int name_workspace = specs[1];
            string name = @"$name_xid.$name_workspace.png";
            if (currpix != null) {
                int[] sizes = determine_sizes(currpix, (double)width, (double)height);
                try {
                    currpix.scale_simple(
                        sizes[0], sizes[1] , Gdk.InterpType.BILINEAR
                    ).save(previewspath.concat("/", @"$name"), "png");
                }
                catch (Error e) {
                }
            }
        }
    }

    public static void main(string[] args) {
        Gtk.init(ref args);
        if (args.length == 2) {
            /* if args are provided, shoot single window */
            new ShootWindow(int.parse(args[1]));
        }
        else {
            new ShootWindow();
        }
    }
}

//141