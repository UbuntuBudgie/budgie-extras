using Gtk;
using Wnck;
using Cairo;
using Notify;

// valac --pkg libnotify --pkg gtk+-3.0 --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE" -X -lm

/*
* ShufflerIII
* Author: Jacob Vlijm
* Copyright © 2017-2022 Ubuntu Budgie Developers
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

namespace AdvancedDragsnap {

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract HashTable<string, Variant> get_monitorgeometry () throws Error;
        public abstract HashTable<string, Variant> get_tiles (string mon_name, int cols, int rows) throws Error;
    }
    // will also be used in snapdragtools
    bool window_iswatched = false;
    bool drag = false;

    class MouseState {
        /*
        based on xinput spawn. should be able to do it differently, but...
        later
        */
        string[] device_ids = {};

        public void check_devices() {
            device_ids = {};
            string output = "";
            try {
                GLib.Process.spawn_command_line_sync(
                    "xinput --list", out output
                );
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
            foreach (string l in output.split("\n")) {
                l = l.down();
                if (
                    (
                        l.contains("mouse") | l.contains("touchpad") | 
                        l.contains("trackpoint") | l.contains("pointer")
                    ) &&
                    l.contains("id=")
                ) {
                    string id = l.split("=")[1].split("\t")[0];
                    device_ids += id;
                }
            }
        }

        public bool get_ctrl_down() {
            foreach (string id in device_ids) {
                string output2 = "";
                try {
                    GLib.Process.spawn_command_line_sync(
                        "xinput --query-state " + id, out output2
                    );
                    if (output2.contains("button[1]=down")) {
                        return true;
                    }
                }
                catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
            }
            return false;
        }

        public bool get_mousedown() {
            foreach (string id in device_ids) {
                string output2 = "";
                try {
                    GLib.Process.spawn_command_line_sync(
                        "xinput --query-state " + id, out output2
                    );
                    if (output2.contains("button[1]=down")) {
                        return true;
                    }
                }
                catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
            }
            return false;
        }
    }


    class DragSnapTools {

        enum PreviewSection {
            NONE,
            LEFT,
            TOPLEFT,
            TOP,
            TOPRIGHT,
            RIGHT,
            BOTTOMRIGHT,
            BOTTOM,
            BOTTOMLEFT,
            FULLSCREEN
        }

        Gtk.Window? overlay;
        Gdk.Display? gdkdsp;
        ShufflerInfoClient? client;
        HashTable<string, Variant>? tiledata;

        public DragSnapTools(Gdk.Display gdkdisplay) {
            overlay = null;
            gdkdsp = gdkdisplay;
            client = get_client();
        }

        public int[] get_tiles(string monname,  int cols, int rows) {
            /* on monitor change, update tiledata & return basic monitor data*/
            int fullwidth = -1;
            int fullheight = -1;
            int origx = -1;
            int origy = -1;
            try {
                tiledata = client.get_tiles(monname, cols, rows);
                foreach (string foundkey in tiledata.get_keys()) {
                    if (foundkey == "0*0") {
                        Variant target_tile = tiledata[foundkey];
                        origx = (int)target_tile.get_child_value(0);
                        origy = (int)target_tile.get_child_value(1);
                        fullwidth = (int)target_tile.get_child_value(2) * cols;
                        fullheight = (int)target_tile.get_child_value(3) * rows;
                    }
                }
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
            return {origx, origy, fullwidth, fullheight};
        }

        public ShufflerInfoClient? get_client () {
            try {
                client = Bus.get_proxy_sync (
                    BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                    ("/org/ubuntubudgie/shufflerinfodaemon")
                );
                return client;
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return null;
            }
        }

        public int areastate(int x, int y, int scrw, int scrh, int scrx=0, int scry=0) {
            /*
            from screen position and screenwidth / height, calculate
            */
            int marge = scrw/120;
            int cornermarge = scrw/10;
            int leftline = scrx + marge;
            int rightline = scrx + scrw - marge;
            int topline = scry + marge;
            int bottomline = scry + scrh - marge;

            bool left = x < leftline;
            bool top = y < topline;
            bool right = x > rightline;
            bool bottom = y > bottomline;

            if (left) {
                if (y < scry + cornermarge) {
                    return (PreviewSection.TOPLEFT);
                }
                else if (y > scry + scrh - cornermarge) {
                    return (PreviewSection.BOTTOMLEFT);
                }
                return PreviewSection.LEFT;
            }
            else if (top) {
                if (x < scrx + cornermarge) {
                    return PreviewSection.TOPLEFT;
                }
                if (x > scrx + scrw - cornermarge) {
                    return PreviewSection.TOPRIGHT;
                }
                return PreviewSection.TOP;
            }
            else if (right) {
                if (y < scry + cornermarge) {
                    return PreviewSection.TOPRIGHT;
                }
                if (y > scry + scrh - cornermarge) {
                    return PreviewSection.BOTTOMRIGHT;
                }
                return PreviewSection.RIGHT;
            }
            else if (bottom) {
                if (x > scrx + scrw - cornermarge) {
                    return PreviewSection.BOTTOMRIGHT;
                }
                if (x < scrx + cornermarge) {
                    return PreviewSection.BOTTOMLEFT;
                }
                return PreviewSection.BOTTOM;
            }
            return PreviewSection.NONE;
        }

        private string get_tilingdefinition(int section, int w_id) {
            int[] targetsection = {-1};
            switch(section) {
                case 1:
                    // left half
                    targetsection = {0, 0, 2, 1};
                    break;
                case 2:
                    // topleft quarter
                    targetsection = {0, 0, 2, 2};
                    break;
                case 3:
                    // top half
                    targetsection = {0, 0, 1, 2};
                    break;
                case 4:
                    // topright quarter
                    targetsection = {1, 0, 2, 2};
                    break;
                case 5:
                    // right half
                    targetsection = {1, 0, 2, 1};
                    break;
                case 6:
                    // bottomright quarter
                    targetsection = {1, 1, 2, 2};
                    break;
                case 7:
                    // bottom half
                    targetsection = {0, 1, 1, 2};
                    break;
                case 8:
                    // bottomleft quarter
                    targetsection = {0, 1, 2, 2};
                    break;
                case 9:
                    // fullscreen
                    targetsection = {0, 0, 1, 1};
                    break;
            }
            string[] targetstring = {};
            foreach(int n in targetsection) {
                targetstring += @"$n";
            }
            return string.joinv(" ", targetstring);
        }

        private int[] get_preview(int section) {
            // runs on area change
            string k = "";
            int spanx = 1;
            int spany = 1;
            switch(section) {
                case 1:
                    // left half
                    k = "0*0";
                    spany = 2; // differs from falback etc, etc.
                    break;
                case 2:
                    // topleft quarter
                    k = "0*0";
                    break;
                case 3:
                    // top half
                    k = "0*0";
                    spanx = 2;
                    break;
                case 4:
                    // topright
                    k = "1*0";
                    break;
                case 5:
                    // right half
                    k = "1*0";
                    spany = 2;
                    break;
                case 6:
                    // bottom right
                    k = "1*1";
                    break;
                case 7:
                    // bottom half
                    k = "0*1";
                    spanx = 2;
                    break;
                case 8:
                    // bottom left
                    k = "0*1";
                    break;
                case 9:
                    k = "0*0";
                    spanx = 2;
                    spany = 2;
                    break;
            }
            foreach (string foundkey in tiledata.get_keys()) {
                if (foundkey == k) {
                    Variant target_tile = tiledata[k];
                    int tile_x = (int)target_tile.get_child_value(0);
                    int tile_y = (int)target_tile.get_child_value(1);
                    int tile_w = (int)target_tile.get_child_value(2);
                    int tile_h = (int)target_tile.get_child_value(3);
                    return {tile_x, tile_y, tile_w*spanx, tile_h*spany};
                }
            }
            return {-1, -1, -1, -1};
        }

        public int getscale(Gdk.Monitor monitorsubj) {
            if (monitorsubj != null) {
                return monitorsubj.get_scale_factor();
            };
            // fallback
            return 1;
        }

        public int[] get_geo(Wnck.Window new_window) {
            int x; int y; int w; int h;
            new_window.get_geometry(out x, out y, out w, out h);
            int[] geodata = {w, h};
            return geodata;
        }

        void kill_preview() {
            if (overlay != null) {
                overlay.destroy();
                overlay = null;
            }
        }

        public string get_activemonitorname(int x, int y, int scale) {
            /*
            get the monitor where mouse is. get_monitor_at_point()
            works with relative position, so need to divide by scale :/
            */
            Gdk.Monitor activemon = gdkdsp.get_monitor_at_point(
                x/scale, y/scale
            );
            return activemon.get_model();
        }

        void run_command (string command) {
            try {
                Process.spawn_command_line_async(command);
            }
            catch (SpawnError e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        public void watch_draggedwindow(
            MouseState state, Gdk.Device pointer, int scale, Wnck.Window curr_active
        ) {
            window_iswatched = true;
            int curr_area = PreviewSection.NONE;
            string? monname = null;
            int new_xid = 0;
            int[] mongeo = {0, 0, 0, 0};
            int x = -1;
            int y = -1;
            int t = 0;
            GLib.Timeout.add(100, ()=> {
                /*
                as long as button 1 is pressed and we are dragging,
                check for position and all
                */
                if (state.get_mousedown() && drag) {
                    new_xid = (int)curr_active.get_xid(); // for tile_active()
                    pointer.get_position(null, out x, out y);
                    x = x*scale; y = y*scale;
                    /* check monitor at point. still the same? */
                    string newmon = get_activemonitorname(x, y, scale);
                    if (newmon != monname ) {
                        monname = newmon;
                        mongeo = get_tiles(monname, 2, 2);
                    }
                    /*
                    if PreviewSection.TOP, wait 0.6 second to switch to
                    fullscreen preview. reset counter if we move away from top
                    */
                    int temp_curr_area = areastate(
                        x, y, mongeo[2], mongeo[3], mongeo[0], mongeo[1]);
                    if (temp_curr_area == PreviewSection.TOP) {
                        if (t > 6) {
                            temp_curr_area = PreviewSection.FULLSCREEN;
                        }
                        t += 1;
                    }
                    else {t = 0;}
                    /* so, update preview if PreviewSection changes */
                    if (temp_curr_area != curr_area) {
                        //  print(@"area changed: $curr_area -> $temp_curr_area\n");
                        /* if state changed, kill preview (if it exists) */
                        kill_preview();
                        /*
                        see if the PreviewSection changed. update accordingly
                        */
                        curr_area = temp_curr_area;
                        if (curr_area != PreviewSection.NONE) {
                            int[] previeworig = get_preview(curr_area);
                            overlay = new Peekaboo(
                                previeworig[0], previeworig[1], scale,
                                previeworig[2], previeworig[3]
                            );
                        }
                    }
                    return true;
                }
                /* if button 1 is released */
                kill_preview();
                window_iswatched = false;
                if (curr_area != PreviewSection.NONE) {;
                    string tilingstring = get_tilingdefinition(curr_area, new_xid);
                    // replace pathstring!!
                    string cmd = "/usr/lib/budgie-window-shuffler" + "/tile_active ".concat(
                        tilingstring, @" id=$new_xid monitor=$monname"
                    );
                    run_command(cmd);
                }
                return false;
            });
        }
    }

    private string intarr_tostring (int[] arr) {
        string str = "";
        foreach (int i in arr) {
            str += i.to_string();
        }
        return str;
    }

    private void sendwarning(
        string title, string body, string icon = "shufflerapplet-symbolic"
    ) {
        Notify.init("ShufflerApplet");
        var notification = new Notify.Notification(title, body, icon);
        notification.set_urgency(Notify.Urgency.NORMAL);
        try {
            new Thread<int>.try("clipboard-notify-thread", () => {
                try{
                    notification.show();
                    return 0;
                } catch (Error e) {
                    error ("Unable to send notification: %s", e.message);
                }
            });
        } catch (Error e) {
            error ("Error: %s", e.message);
        }
    }

    public static void main (string[] args) {
        /*
        if we run dragsnap, disable solu' version
        */
        string solus_snappath = "com.solus-project.budgie-wm";
        GLib.Settings solus_snapsettings = new GLib.Settings(solus_snappath);
        solus_snapsettings.set_boolean("edge-tiling", false);
        solus_snapsettings.changed["edge-tiling"].connect(()=> {
            solus_snapsettings.set_boolean("edge-tiling", false);
            sendwarning(
                "Shuffler notification",
                "Shuffler edge-tiling is running."
            );
        });
        /*
        we need to check if window is actually dragged
        width and height will be the same during gemetry change than
        */
        string check_geo2 = "";
        string check_geo1 = "";
        Gtk.init(ref args);
        /*
        mouse stuff
        */
        MouseState mousestate = new MouseState();
        mousestate.check_devices();
        Gdk.Display gdkdsp = Gdk.Display.get_default();
        DragSnapTools dragsnaptools = new DragSnapTools(gdkdsp);
        Gdk.Seat gdkseat = gdkdsp.get_default_seat();
        gdkseat.device_added.connect(mousestate.check_devices);
        gdkseat.device_removed.connect(mousestate.check_devices);
        Gdk.Device pointer = gdkseat.get_pointer();
        /*
        setup watch scale
        */
        int scale;
        Gdk.Monitor? monitorsubj = gdkdsp.get_primary_monitor();
        Gdk.Screen gdkscr = Gdk.Screen.get_default();
        scale = dragsnaptools.getscale(monitorsubj);
        gdkscr.monitors_changed.connect(()=> {
            scale = dragsnaptools.getscale(monitorsubj);
        });
        /*
        on active window change, we are watching the new window for
        drag-action. we then need to unset the previous connection
        */
        ulong curr_connection = 0;
        Wnck.Screen wnckscr = Wnck.Screen.get_default();
        Wnck.Window? new_active = null;
        wnckscr.active_window_changed.connect(()=> {
            /* watch newly active window, disconnect previous */
            if (new_active != null) {
                new_active.disconnect(curr_connection);
            }
            /* set_new_active to the new one: check if the window is valid */
            new_active = wnckscr.get_active_window();
            if (new_active == null) {
                return;
            }
            curr_connection = new_active.geometry_changed.connect(()=> {
                /*
                if window is currently watched, (so if on second+
                connect-event) see if width and/or height changed
                if so, we are not dragging, but resizing -> no preview,
                bail out!
                */
                if (window_iswatched) {
                    check_geo2 = intarr_tostring(
                        dragsnaptools.get_geo(new_active)
                    );
                    drag = check_geo2 == check_geo1;
                }
                else if (
                    !window_iswatched &&
                    new_active.get_window_type() == Wnck.WindowType.NORMAL
                ) {
                    check_geo1 = intarr_tostring(
                        dragsnaptools.get_geo(new_active)
                    );
                    dragsnaptools.watch_draggedwindow(
                        mousestate, pointer, scale, new_active
                    );
                }
            });
        });
        Gtk.main();
    }


    class Peekaboo : Gtk.Window {

        public Peekaboo(int x = 0, int y = 0, int scale, int w, int h) {
            this.set_skip_taskbar_hint(true);
            this.set_type_hint(Gdk.WindowTypeHint.NOTIFICATION);
            this.set_keep_above(true);
            this.move(x/scale, y/scale);
            this.resize(w/scale, h/scale);
            this.set_decorated(false);
            // transparency
            var screen = this.get_screen();
            this.set_app_paintable(true);
            var visual = screen.get_rgba_visual();
            this.set_visual(visual);
            this.draw.connect(on_draw);
            this.show_all();
        }

        private bool on_draw (Widget da, Context ctx) {
            double[] tc = get_theme_fillcolor();
            ctx.set_source_rgba(tc[0], tc[1], tc[2], 0.4);
            ctx.set_operator(Cairo.Operator.SOURCE);
            ctx.paint();
            ctx.set_operator(Cairo.Operator.OVER);
            return false;
        }

        private double[] get_theme_fillcolor(){
			Gtk.StyleContext style_ctx = new Gtk.StyleContext();
			Gtk.WidgetPath widget_path =  new Gtk.WidgetPath();
			widget_path.append_type(typeof(Gtk.Button));
			style_ctx.set_path(widget_path);
			Gdk.RGBA fcolor = style_ctx.get_color(Gtk.StateFlags.LINK);
			double red = fcolor.red;
			double green = fcolor.green;
			double blue = fcolor.blue;
            return {red, green, blue};
		}
    }
}
