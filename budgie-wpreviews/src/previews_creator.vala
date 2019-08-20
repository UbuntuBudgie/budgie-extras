using Gdk;
using Gtk;

/*
Budgie WindowPreviews
Author: Jacob Vlijm
Copyright © 2017-2019 Ubuntu Budgie Developers
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


namespace create_previews {


    Wnck.Screen wnck_scr;
    Gdk.Screen gdk_scr;
    int curr_refreshindex;
    double threshold;
    Gdk.X11.Display gdkdisp;
    GLib.List<Gdk.Window> gdk_winlist;
    string previewspath;
    bool idle_state;


    public static void main (string[] args) {
        // all valid windows are in queue to be refreshed, starting index o
        curr_refreshindex = 0;
        // if idle exceeds 90 seconds, pauze refreshing
        idle_state = false;
        // decide if we should take xsize or ysize as a reference for resize
        threshold = 260.0/160.0;
        string user = Environment.get_user_name();
        previewspath = "/tmp/".concat(user, "_window-previews");
        try {
            File file = File.new_for_commandline_arg (previewspath);
            file.make_directory ();
        } catch (Error e) {
            // directory exists, no action needed
        }
        Gtk.init(ref args);
        // set sources
        wnck_scr = Wnck.Screen.get_default();
        gdk_scr = Gdk.Screen.get_default();
        gdkdisp = (Gdk.X11.Display)Gdk.Display.get_default();
        update_winlist();
        // for updating gdk window list / clean up
        wnck_scr.window_opened.connect(update_winlist);
        wnck_scr.window_closed.connect(update_winlist);
        // for maintaining new window (refresh after 6 seconds)
        wnck_scr.window_opened.connect(update_new);
        // immediate refresh active window?
        wnck_scr.active_window_changed.connect(() => {
            update_preview(wnck_scr.get_active_window());
        });
        // make phase so that they won't fall together all the time
        int refresh_cycle = 1;
        int refresh_active = 1;
        GLib.Timeout.add_seconds(1, () => {
            gdkdisp.error_trap_push();
            // take care of active window
            if (refresh_active == 1) {
                update_preview(wnck_scr.get_active_window());
            }
            else if (refresh_active == 5) {
                idle_state = get_idle();
                refresh_active = 0;
            }
            refresh_active += 1;
            // general refresh pool
            if (refresh_cycle == 1) {
                unowned GLib.List<Wnck.Window> wnck_winlist = wnck_scr.get_windows();
                uint n_wins = wnck_winlist.length();
                // make sure index does not exceed n-windows
                if (curr_refreshindex >= n_wins) {
                    curr_refreshindex = 0;
                }
                // get matching Gdk.Window from Gdk stack
                int current_check = 0;
                foreach (Wnck.Window w in wnck_winlist) {
                    bool valid = w.get_window_type() == Wnck.WindowType.NORMAL;
                    bool active = w == wnck_scr.get_active_window();
                    if (valid && !active) {
                        if (current_check == curr_refreshindex) {
                            update_preview(w);
                            break;
                        }
                        current_check += 1;
                    }
                }
                curr_refreshindex += 1;
            }
            else if (refresh_cycle == 11) {
                refresh_cycle = 0;
            }
            refresh_cycle += 1;
            return true;
        });
        Gtk.main();
    }

    private bool get_idle () {
        // see if idle exceeds 90 seconds
        string cmd = "xprintidle";
        string output;
        int curridle = 0;
        try {
            GLib.Process.spawn_command_line_sync(cmd, out output);
            curridle = int.parse(output) / 1000;
            if (curridle > 90) {
                return true;
            }
            else {
                return false;
            }
        }
        //on an occasional exception, return false
        catch (SpawnError e) {
            return false;
        }
    }

    private void update_winlist () {
        // refresh wnck winlist, remove obsolete images
        gdk_winlist = gdk_scr.get_window_stack();
        cleanup();
    }

    private void update_new (Wnck.Window w) {
        // create preview on creation of (valid) window,
        // refresh after 6 seconds
        if (w.get_window_type() == Wnck.WindowType.NORMAL) {
            GLib.Timeout.add(500, () => {
                update_preview(w);
                return false;
            });
            GLib.Timeout.add_seconds(6, () => {
                update_preview(w);
                return false;
            });
        }
    }

    private Gdk.Window? get_gdkmatch_fromwnckwin (Wnck.Window curractive) {
        // given a wnck window, find its gdk representative
        // for preview creation
        uint curractive_xid = (uint)curractive.get_xid();
        foreach (Gdk.Window w in gdk_winlist) {
            Gdk.X11.Window winsubj = (Gdk.X11.Window)w;
            uint gdk_xid = (uint)winsubj.get_xid();
            if (gdk_xid == curractive_xid) {
                return w;
            }
        }
        return null;
    }

    private int[] determine_sizes (
        Gdk.Pixbuf pre_shot, double xsize, double ysize
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

    private void update_preview (Wnck.Window? w) {
        /*
        [1] check existence (get_gdkmatch_fromwnckwin(w))
        [2] create the pixbuf
        [3] get xid, workspace
        [4] scale, name and write do disc
        */

        if (w != null && !idle_state) {
            Gdk.Window? gdk_match = get_gdkmatch_fromwnckwin(w);
            if (
                // [1] check existence (get_gdkmatch_fromwnckwin(w))
                gdk_match != null &&
                w.get_window_type() == Wnck.WindowType.NORMAL
            ) {
                // [2] create the pixbuf (the sensitive part)
                int width = gdk_match.get_width();
                int height = gdk_match.get_height();
                Gdk.Pixbuf currpix = Gdk.pixbuf_get_from_window(
                    gdk_match, 0, 0, width, height
                );
                // [3] get the xid, workspace
                Gdk.X11.Window x11_w = (Gdk.X11.Window)gdk_match;
                uint name_xid = (uint)(x11_w.get_xid());
                uint name_workspace = x11_w.get_desktop();
                int[] sizes = determine_sizes(currpix, (double)width, (double)height);
                //resize, write
                string name = @"$name_xid.$name_workspace.png";
                if (currpix != null) {
                    try {
                        currpix.scale_simple(
                            sizes[0], sizes[1] , Gdk.InterpType.BILINEAR
                        ).save(previewspath.concat("/", name), "png");
                    }
                    catch (Error e) {
                    }
                }
            }
        }
    }

    private string[] get_currpreviews () {
        // look up existing previews (files, full names)
        string[] files = {};
        try {
            var dr = Dir.open(previewspath);
            string ? filename = null;
            while ((filename = dr.read_name()) != null) {
            string addpic = Path.build_filename(previewspath, filename);
            files += addpic;
            }
        }
        catch (FileError err) {
            return {};
        }
        return files;
    }

    private bool get_stringindex (string f, string[] existing_xids) {
        // see if string exists another string
        foreach (string xid in existing_xids) {
            if (f.contains(xid)) {
                return true;
            }
        }
        return false;
    }

    private void cleanup () {
        // look over existing images, remove if obsolete
        // get filenames
        string[] filenames = get_currpreviews();
        // get existing xids
        unowned GLib.List<Wnck.Window> latest_list = wnck_scr.get_windows();
        string[] latest_xids = {};
        foreach (Wnck.Window w in latest_list) {
            ulong xid = w.get_xid();
            string name_xid = xid.to_string();
            string lookup = name_xid.to_string();
            latest_xids += lookup;
        }
        foreach (string f in filenames) {
            bool keep = get_stringindex(f, latest_xids);
            if (!keep) {
                File file = File.new_for_path (f);
                try {
                    file.delete();
                }
                catch (Error e) {
                }
            }
        }
    }
}