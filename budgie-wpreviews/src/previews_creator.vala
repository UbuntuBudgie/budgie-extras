using Gdk;
using Gtk;

/*
Budgie WindowPreviews
Author: Jacob Vlijm
Copyright © 2017-2020 Ubuntu Budgie Developers
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

/* refresh happens in three layers:
1. new windows are refreshed/created after 0.5 and 6 seconds
2. active window is refreshed every 5 seconds, and immediately on change
3. other windows are in queue, cycle window stack, one per 11 seconds
 */


namespace create_previews {

    uint n_wins;
    uint current_queueindex;
    bool validwins_exist;
    Gdk.X11.Display gdkdisp;
    double threshold;
    string previewspath;
    Wnck.Screen wnck_scr;
    Gdk.Screen gdk_scr;
    GLib.List<Gdk.Window> gdk_winlist;
    bool idle_state;


    public static void main (string[] args) {

        current_queueindex = 0;
        idle_state = false;
        Gtk.init(ref args);
        wnck_scr = Wnck.Screen.get_default();
        gdk_scr = Gdk.Screen.get_default();
        string user = Environment.get_user_name();
        previewspath = "/tmp/".concat(user, "_window-previews");
        update_winlist();
        wnck_scr.window_opened.connect(update_winlist);
        wnck_scr.window_opened.connect(refresh_new);
        wnck_scr.window_closed.connect(update_winlist);
        wnck_scr.active_window_changed.connect(refresh_activewindow);
        gdkdisp = (Gdk.X11.Display)Gdk.Display.get_default();
        int global_cycleindex = 0;
        int active_win_cycleindex = 0;
        threshold = 260.0/160.0;
        // make previews path
        try {
            File file = File.new_for_commandline_arg (previewspath);
            file.make_directory ();
        } catch (Error e) {
            // directory exists, no action needed
        }

        GLib.Timeout.add_seconds(1, () => {
            // setting up cycles
            // queue
            if (global_cycleindex == 11) {
                refresh_queueitem();
                global_cycleindex = 0;
            }
            else {
                global_cycleindex += 1;
            }
            // active window
            if (active_win_cycleindex == 5) {
                refresh_activewindow();
                idle_state = get_idle();
                active_win_cycleindex = 0;
            }
            else {
                active_win_cycleindex += 1;
            }
            return true;
        });
        Gtk.main();
    }

    private void update_nextqueueindex () {
        if (!validwins_exist) {
            // if no valid wins
            current_queueindex = -1;
        }
        // if only one win, which is apparently valid, don't try to iter
        else if (n_wins == 1) {
            current_queueindex = 0;
        }
        else {
            // if multiple, windows, lookup the next valid
            current_queueindex += 1;
            // in unlike closing last valid windows (>1) in the split second between
            // refreshing winlist and update queue-index, don't try forever
            int maxtry = 0;
            while (maxtry < 50) {
                // check if current index is valid
                if (current_queueindex < n_wins) {
                    Gdk.Window checkwindow = gdk_winlist.nth(current_queueindex).data;
                    if (checkwindow.get_type_hint() == Gdk.WindowTypeHint.NORMAL) {
                        break;
                    }
                    else {
                        current_queueindex += 1;
                    }
                }
                else {
                    current_queueindex = 0;
                }
                maxtry += 1;
            }
        }
    }

    private void refresh_queueitem () {
        // as the name sais, refreshing current index from queue
        if (n_wins != 0) {
            update_nextqueueindex();
            // ok, potentially repeated lookup, but for the sake of readability
            if (current_queueindex != -1) {
                Gdk.Window winsubj = gdk_winlist.nth(current_queueindex).data;
                //  print(@"updating $current_queueindex\n");
                update_preview(winsubj);
            }
        }
    }

    private Gdk.Window? get_gdkmactch (ulong wnck_xid) {
        // given an xid, find the (existing) Gdk.Window
        // Gdk.WindowTypeHint.NORMAL - check is done here
        foreach (Gdk.Window gdkwin in gdk_winlist) {
            if (gdkwin.get_type_hint() == Gdk.WindowTypeHint.NORMAL) {
                Gdk.X11.Window x11conv = (Gdk.X11.Window)gdkwin; // check!!!
                ulong x11_xid = x11conv.get_xid();
                if (wnck_xid == x11_xid) {
                    return gdkwin;
                }
            }
        }
        return null;
    }

    private void refresh_activewindow () {
        Wnck.Window? activewin = wnck_scr.get_active_window();
        if (activewin != null) {
            ulong wnckwin_xid = activewin.get_xid();
            Gdk.Window? xid_match = get_gdkmactch(wnckwin_xid);
            if (xid_match != null) {
                update_preview(xid_match);
            }
        }
    }

    private void refresh_new (Wnck.Window newwin) {
        // make sure new window's previews are drawn correctly
        // lookup gdk window
        ulong wnckwin_xid = newwin.get_xid();
        Gdk.Window? xid_match = get_gdkmactch(wnckwin_xid);
        if (xid_match != null) {
            // remove possible previous preview on other ws
            string[] lookuplist = get_currpreviews();
            try {
                foreach (string s in lookuplist) {
                    if (s.contains(@"$wnckwin_xid")) {
                        File rmfile = File.new_for_path(s);
                        rmfile.delete();
                    }
                }
            }
            catch (Error e) {
                // nothing to do
            }
            newwin.workspace_changed.connect(refresh_new);
            GLib.Timeout.add(500, () => {;
                update_preview(xid_match);
                return false;
            });
        }
        // check existence again
        xid_match = get_gdkmactch(wnckwin_xid);
        if (xid_match != null) {
            GLib.Timeout.add_seconds(6, () => {
                update_preview(xid_match);
                return false;
            });
        }
    }

    private void update_preview (Gdk.Window window) {
        // no filter on type needed, is done already
        gdkdisp.error_trap_push();
        if (window.is_viewable() && !idle_state) {
            int width = window.get_width();
            int height = window.get_height();
            Gdk.Pixbuf? currpix = Gdk.pixbuf_get_from_window(
                window, 0, 0, width, height
            );
            // get the xid, workspace
            Gdk.X11.Window x11_w = (Gdk.X11.Window)window;
            uint name_xid = (uint)(x11_w.get_xid());
            uint name_workspace = x11_w.get_desktop();
            int[] sizes = determine_sizes(currpix, (double)width, (double)height);
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

    private void update_winlist () {
        // refresh gdk winlist, remove obsolete images
        gdk_winlist = gdk_scr.get_window_stack();
        n_wins = gdk_winlist.length();
        validwins_exist = false;
        // check if we should fire up refresh anyway
        foreach (Gdk.Window w in gdk_winlist) {
            if (w.get_type_hint() == Gdk.WindowTypeHint.NORMAL) {
                validwins_exist = true;
            }
        }
        cleanup();
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
        string[] filenames = get_currpreviews();
        // get existing xids
        string[] latest_xids = {};
        foreach (Gdk.Window w in gdk_winlist) {
            Gdk.X11.Window x11_w = (Gdk.X11.Window)w;
            ulong xid = x11_w.get_xid();
            latest_xids += xid.to_string();
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

    private bool get_idle () {
        // see if idle exceeds 90 seconds
        string cmd = Config.PACKAGE_BINDIR + "/xprintidle";
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
}