using Gdk;
using Gtk;

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

/* refresh happens in three layers:
1. new windows are refreshed/created after 1 and 6 seconds
2. active window is refreshed every 5 seconds, and immediately on focus change
3. other windows are in queue, cycle window stack, one per 11 seconds
*/


namespace create_previews {

    [DBus (name = "org.gnome.Mutter.IdleMonitor")]
    interface MutterClient : Object {
        public abstract uint64 GetIdletime () throws Error;
    }

    uint n_wins;
    uint current_queueindex;
    bool validwins_exist;
    Gdk.X11.Display gdkdisp;
    double threshold;
    string previewspath;
    Wnck.Screen? wnck_scr;
    Gdk.Screen? gdk_scr;
    GLib.List<Gdk.Window> gdk_winlist;
    bool idle_state;

    MutterClient? mutterclient;


    public static void main (string[] args) {

        /* get dbus client */
        get_screensaver_client();

        current_queueindex = 0;
        idle_state = false;
        Gtk.init(ref args);
        wnck_scr = Wnck.Screen.get_default();
        if (wnck_scr == null) return; // usually if not run on X11
        gdk_scr = Gdk.Screen.get_default();
        if (gdk_scr == null) return; // usually if there is no display
        string user = Environment.get_user_name();
        var tmp = Environment.get_tmp_dir() + "/";
        previewspath = tmp.concat(user, "_window-previews");
        update_winlist();
        wnck_scr.window_opened.connect(update_winlist);
        wnck_scr.window_opened.connect(refresh_new);
        wnck_scr.window_closed.connect(update_winlist);
        wnck_scr.active_window_changed.connect(refresh_activewindow);
        gdkdisp = (Gdk.X11.Display)Gdk.Display.get_default();
        int global_cycleindex = 0;
        int active_win_cycleindex = 0;
        threshold = 260.0/160.0;
        /* make previews path */
        try {
            File file = File.new_for_commandline_arg (previewspath);
            file.make_directory ();
        } catch (Error e) {
            /* directory exists, no action needed */
        }

        GLib.Timeout.add_seconds(1, () => {
            /* setting up cycles */
            /* queue */
            if (global_cycleindex == 11) {
                refresh_queueitem();
                global_cycleindex = 0;
            }
            else {
                global_cycleindex += 1;
            }
            /* ctive window */
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

    private void get_screensaver_client () {
        try {
            mutterclient = Bus.get_proxy_sync (
                BusType.SESSION, "org.gnome.Mutter.IdleMonitor",
                ("/org/gnome/Mutter/IdleMonitor/Core")
            );
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    private void update_nextqueueindex () {
        if (!validwins_exist) {
            /* if no valid wins */
            current_queueindex = -1;
        }
        /* if only one win, which is apparently valid, don't try to iter */
        else if (n_wins == 1) {
            current_queueindex = 0;
        }
        else {
            /* if multiple, windows, lookup the next valid */
            current_queueindex += 1;
            /* in unlike closing last valid windows (>1) in the split second between */
            /* refreshing winlist and update queue-index, don't try forever */
            int maxtry = 0;
            while (maxtry < 50) {
                /* check if current index is valid */
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
        /* as the name sais, refreshing current index from queue */
        if (n_wins != 0) {
            update_nextqueueindex();
            /* ok, potentially repeated lookup, but for the sake of readability */
            if (current_queueindex != -1) {
                Gdk.Window winsubj = gdk_winlist.nth(current_queueindex).data;
                int xid = get_winid(winsubj);
                string cmd = Config.PREVIEWS_DIR + @"/separate_shot $xid";
                run_imgupdate(cmd);
            }
        }
    }

    private int get_winid(Gdk.Window w) {
        Gdk.X11.Window x11_w = (Gdk.X11.Window)w;
        return (int)x11_w.get_xid();
    }

    private void run_imgupdate (string cmd) {
        if (idle_state) {
            return;
        }
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

    private void refresh_activewindow () {
        Wnck.Window? activewin = wnck_scr.get_active_window();
        if (activewin != null) {
            ulong wnckwin_xid = activewin.get_xid();
            string cmd = Config.PREVIEWS_DIR + @"/separate_shot $wnckwin_xid";
            run_imgupdate(cmd);
        }
    }


    private void refresh_new (Wnck.Window newwin) {
        ulong wnckwin_xid = newwin.get_xid();
        string cmd = Config.PREVIEWS_DIR + @"/separate_shot $wnckwin_xid";
        /* make sure new window's previews are drawn correctly */
        /* remove possible previous preview on other ws */
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
            /* nothing to do, file does not exist */
        }
        newwin.workspace_changed.connect(refresh_new);
        GLib.Timeout.add(1000, () => {;
            run_imgupdate(cmd);
            return false;
        });
        /* check existence again */
        GLib.Timeout.add_seconds(6, () => {
            /* if win still exists, will be updated */
            run_imgupdate(cmd);
            return false;
        });
    }

    private void update_winlist () {
        /* refresh gdk winlist, remove obsolete images */
        gdk_winlist = gdk_scr.get_window_stack();
        n_wins = gdk_winlist.length();
        validwins_exist = false;
        /* check if we should fire up refresh anyway */
        foreach (Gdk.Window w in gdk_winlist) {
            if (w.get_type_hint() == Gdk.WindowTypeHint.NORMAL) {
                validwins_exist = true;
            }
        }
        cleanup();
    }

    private string[] get_currpreviews () {
        /* look up existing previews (files, full names) */
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
        /* see if string exists another string */
        foreach (string xid in existing_xids) {
            if (f.contains(xid)) {
                return true;
            }
        }
        return false;
    }

    private void cleanup () {
        /* look over existing images, remove if obsolete */
        string[] filenames = get_currpreviews();
        /* get existing xids */
        string[] latest_xids = {};
        foreach (Gdk.Window w in gdk_winlist) {
            int xid = get_winid(w);
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
        try {
            if (mutterclient.GetIdletime()/1000 > 90) {
                return true;
            }
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
        return false;
    }
}

// 302 / 306