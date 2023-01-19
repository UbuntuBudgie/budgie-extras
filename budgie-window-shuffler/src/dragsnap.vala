using Gtk;
using Wnck;
using Cairo;

/*
* ShufflerIII
* Author: Jacob Vlijm
* Copyright © 2017 Ubuntu Budgie Developers
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

    bool window_iswatched = false;
    bool drag = false;
    bool warningdialog = false;


    class ManageSettings {

        public GLib.Settings[] competing_settings = {};
        int n_settings = 0;
        public bool act_on_change = true;

        public ManageSettings () {
            string[] competing_strings = {
                "org.ubuntubudgie.windowshuffler",
                "com.solus-project.budgie-wm",
                "org.gnome.mutter"
            };
            foreach (string s in competing_strings) {
                competing_settings += new GLib.Settings(s);
            }
            n_settings = competing_settings.length;
            setup_connection();
        }

        public void setup_connection () {
            foreach (GLib.Settings st in competing_settings[1:n_settings]) {
                st.changed["edge-tiling"].connect((setting, key)=> {
                    bool is_on = setting.get_boolean("edge-tiling");
                    if (act_on_change && !warningdialog && is_on) {
                        warningdialog = true;
                        new DialogWindow(this);
                    }
                });
            }
        }

        public void unset_competition () {
            /* disable all but dragsnap */
            foreach (GLib.Settings st in competing_settings[1:n_settings]) {
                st.set_boolean("edge-tiling", false);
            }
        }

        public void unset_dragsnap () {
            /* enable built-in, disable dragsnap */
            act_on_change = false;
            competing_settings[1].set_boolean("edge-tiling", true);
            competing_settings[0].set_boolean("dragsnaptiling", false);
        }
    }


    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract HashTable<string, Variant> get_monitorgeometry () throws Error;
        public abstract HashTable<string, Variant> get_tiles (string mon_name, int cols, int rows) throws Error;
        public abstract bool get_mouse_isdown (int button) throws Error;
        public abstract bool get_modkey_isdown (int key)  throws Error;
    }

    [DBus (name = "org.UbuntuBudgie.HotCornerSwitch")]

    interface HotCornerClient : Object {
        public abstract void set_skip_action (bool onoff) throws Error;
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

        enum ActiveKey {
            NONE,
            CONTROL,
            ALT
        }

        Gtk.Window? overlay;
        Gdk.Display? gdkdsp;
        ShufflerInfoClient? client; /* shufflerdaemon */
        HotCornerClient? client2; /* hotcorners */
        HashTable<string, Variant>? tiledata;

        public DragSnapTools(Gdk.Display gdkdisplay) {
            overlay = null;
            gdkdsp = gdkdisplay;
            client = get_client();
            client2 = null;
        }

        private int[] get_tiles(string monname,  int cols, int rows) {
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

        private ShufflerInfoClient? get_client () {
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

        private HotCornerClient? get_client2 () {
            try {
                client2 = Bus.get_proxy_sync (
                    BusType.SESSION, "org.UbuntuBudgie.HotCornerSwitch",
                    ("/org/ubuntubudgie/hotcornerswitch")
                );
                return client2;
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return null;
            }
        }

        private void disable_hotcorners (bool onoff) {
            client2 = get_client2();
            try {
                client2.set_skip_action(onoff);
            }
            catch (Error e) {
                /* service does not exist. message is useless */
            }
        }

        private int areastate(int x, int y, int scrw, int scrh, int scrx=0, int scry=0) {
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

        private string get_tilingdefinition(
            int section, int w_id, int activekey
        ) {
            int[] targetsection = {-1};
            /*
            due to extending posibilities after initial plan, these
            definitions need to be transformed into their abstractions/
            Later.
            */
            switch(section) {
                case 1:
                    // left half
                    targetsection = {0, 0, 2, 1};
                    if (activekey == ActiveKey.CONTROL) {
                        // left 2/5
                        targetsection = {0, 0, 5, 1, 2, 1};
                    }
                    else if (activekey == ActiveKey.ALT) {
                        // left 3/5
                        targetsection = {0, 0, 5, 1, 3, 1};
                    }
                    break;
                case 2:
                    // topleft quarter
                    targetsection = {0, 0, 2, 2};
                    if (activekey == ActiveKey.CONTROL) {
                        // topleft 2/5
                        targetsection = {0, 0, 5, 2, 2, 1};
                    }
                    else if (activekey == ActiveKey.ALT) {
                        // topleft 3/5
                        targetsection = {0, 0, 5, 2, 3, 1};
                    }
                    break;
                case 3:
                    // top half
                    targetsection = {0, 0, 1, 2};
                    break;
                case 4:
                    // topright quarter
                    targetsection = {1, 0, 2, 2};
                    if (activekey == ActiveKey.CONTROL) {
                        // topright 2/5
                        targetsection = {3, 0, 5, 2, 2, 1};
                    }
                    else if (activekey == ActiveKey.ALT) {
                        // topright 3/5
                        targetsection = {2, 0, 5, 2, 3, 1};
                    }
                    break;
                case 5:
                    // right half
                    targetsection = {1, 0, 2, 1};
                    if (activekey == ActiveKey.CONTROL) {
                        // right 2/5
                        targetsection = {3, 0, 5, 1, 2, 1};
                    }
                    else if (activekey == ActiveKey.ALT) {
                        // right 3/5
                        targetsection = {2, 0, 5, 1, 3, 1};
                    }
                    break;
                case 6:
                    // bottomright quarter
                    targetsection = {1, 1, 2, 2};
                    if (activekey == ActiveKey.CONTROL) {
                        //bottomright 2/5
                        targetsection = {3, 1, 5, 2, 2, 1};
                    }
                    else if (activekey == ActiveKey.ALT) {
                        //bottomright 3/5
                        targetsection = {2, 1, 5, 2, 3, 1};
                    }
                    break;
                case 7:
                    // bottom half
                    targetsection = {0, 1, 1, 2};
                    break;
                case 8:
                    // bottomleft quarter
                    targetsection = {0, 1, 2, 2};
                    if (activekey == ActiveKey.CONTROL) {
                        // bottomleft 2/5
                        targetsection = {0, 1, 5, 2, 2, 1};
                    }

                    else if (activekey == ActiveKey.ALT) {
                        // bottomleft 3/5
                        targetsection = {0, 1, 5, 2, 3, 1};
                    }

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

        private int[] get_preview_asymbig(int section) {
            /*
            For reasons of understandability, let's not squeeze it all in
            one and the same method for 2 x 2 and 3/5 */
            // runs on area change
            string k = "";
            int spanx = 3;
            int spany = 1;
            switch(section) {
                case 1:
                    // left 3/5
                    k = "0*0";
                    spany = 2; // differs from falback etc, etc.
                    break;
                case 2:
                    // topleft 3/5
                    k = "0*0";
                    break;
                case 3:
                    // top half
                    k = "0*0";
                    spanx = 5;
                    break;
                case 4:
                    // topright
                    k = "2*0";
                    break;
                case 5:
                    // right half
                    k = "3*0";
                    spany = 2;
                    break;
                case 6:
                    // bottom right
                    k = "2*1";
                    break;
                case 7:
                    // bottom half
                    k = "0*1";
                    spanx = 5;
                    break;
                case 8:
                    // bottom left
                    k = "0*1";
                    break;
                case 9: // full screen
                    k = "0*0";
                    spanx = 5;
                    spany = 2;
                    break;
            }
            return geometry_keyvalues(k, spanx, spany);
        }

        private int[] geometry_keyvalues (string k, int spanx, int spany){
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

        private int[] get_preview_asymsmall(int section) {
                /*
                For reasons of understandability, let's not squeeze it all in
                one and the same method for 2 x 2 and 3/5 */
                // runs on area change
                string k = "";
                int spanx = 2;
                int spany = 1;
                switch(section) {
                    case 1:
                        // left 2/5
                        k = "0*0";
                        spany = 2; // differs from falback etc, etc.
                        break;
                    case 2:
                        // topleft 2/5
                        k = "0*0";
                        break;
                    case 3:
                        // top half
                        k = "0*0";
                        spanx = 5;
                        break;
                    case 4:
                        // topright
                        k = "3*0";
                        break;
                    case 5:
                        // right half
                        k = "3*0";
                        spany = 2;
                        break;
                    case 6:
                        // bottom right
                        k = "3*1";
                        break;
                    case 7:
                        // bottom half
                        k = "0*1";
                        spanx = 5;
                        break;
                    case 8:
                        // bottom left
                        k = "0*1";
                        break;
                    case 9: // full screen
                        k = "0*0";
                        spanx = 5;
                        spany = 2;
                        break;
            }
            return geometry_keyvalues(k, spanx, spany);
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
            return geometry_keyvalues(k, spanx, spany);
        }

        private bool get_mousestate (int button) {
            try {
                return client.get_mouse_isdown(button);
            }
            catch (Error e) {
                message ("Couldn't get mouse state. is Shuffler daemon running?");
                return false;
            }
        }

        private bool get_keystate (int key) {
            try {
                return client.get_modkey_isdown(key);
            }
            catch (Error e) {
                message ("Couldn't get key state. is Shuffler daemon running?");
                return false;
            }
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

        private void kill_preview() {
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

        private void run_command (string command) {
            try {
                Process.spawn_command_line_async(command);
            }
            catch (SpawnError e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private int get_active_modkey() {
            int n = 1;
            bool[] states = {
                get_keystate(2), get_keystate(3)
            };
            foreach (bool b in states) {
                if (b) {
                    return n;
                }
                n += 1;
            }
            return 0;
        }

        public void watch_draggedwindow(
            Gdk.Device pointer, int scale, Wnck.Window curr_active
        ) {
            window_iswatched = true;
            int curr_area = PreviewSection.NONE;
            string? monname = null;
            int activekey = ActiveKey.NONE;
            int new_xid = 0;
            int[] mongeo = {0, 0, 0, 0};
            int x = -1;
            int y = -1;
            int t = 0;
            bool firstcycle = true;
            int cols = 2;
            int rows = 2;

            GLib.Timeout.add(100, ()=> {
                /*
                as long as button 1 is pressed and we are dragging,
                check for position and all
                */
                if (get_mousestate(1) && drag) {
                    if (firstcycle) {
                        disable_hotcorners(true);
                        new_xid = (int)curr_active.get_xid(); // for tile_active()
                        firstcycle = false;
                    }
                    pointer.get_position(null, out x, out y);
                    x = x*scale; y = y*scale;

                    /* check monitor at point. still the same? */
                    string newmon = get_activemonitorname(x, y, scale);
                    if (newmon != monname ) {
                        monname = newmon;
                        mongeo = get_tiles(monname, cols, rows);
                    }
                    int new_activekey = get_active_modkey();

                    if (new_activekey != activekey) {
                        activekey = new_activekey;
                        if (activekey == ActiveKey.NONE) {
                            cols = 2; rows = 2;
                        }
                        else {cols = 5; rows = 2;}
                        mongeo = get_tiles(monname, cols, rows);
                        /* updating makes no sense if preview is the same */
                        if (
                            curr_area != PreviewSection.FULLSCREEN &&
                            curr_area != PreviewSection.TOP &&
                            curr_area != PreviewSection.BOTTOM
                        ) {
                            kill_preview();
                            update_preview(curr_area, activekey, scale);
                        }
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
                        /* if state changed, kill preview (if it exists) */
                        kill_preview();
                        /*
                        see if the PreviewSection changed. update accordingly
                        */
                        curr_area = temp_curr_area;
                        update_preview(curr_area, activekey, scale);
                    }
                    return true;
                }
                /* if button 1 is released */
                kill_preview();
                window_iswatched = false;
                if (curr_area != PreviewSection.NONE) {
                    string tilingstring = get_tilingdefinition(curr_area, new_xid, activekey);
                    string cmd = Config.SHUFFLER_DIR + "/tile_active ".concat(
                        tilingstring, @" id=$new_xid monitor=$monname"
                    );
                    run_command(cmd);
                }
                disable_hotcorners(false);
                return false;
            });
        }

        void update_preview (int curr_area, int activekey, int scale) {
            if (curr_area != PreviewSection.NONE) {
                int[] previeworig = get_preview(curr_area);// optimize
                if (activekey == ActiveKey.ALT) {
                    previeworig = get_preview_asymbig (curr_area);
                }
                else if (activekey == ActiveKey.CONTROL) {
                    previeworig = get_preview_asymsmall (curr_area);
                }
                overlay = new Peekaboo(
                    previeworig[0], previeworig[1], scale,
                    previeworig[2], previeworig[3]
                );
            }
        }
    }

    private string intarr_tostring (int[] arr) {
        string str = "";
        foreach (int i in arr) {
            str += i.to_string();
        }
        return str;
    }


    public void initialiseLocaleLanguageSupport() {
        GLib.Intl.setlocale(GLib.LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain(
            Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR
        );
        GLib.Intl.bind_textdomain_codeset(
            Config.GETTEXT_PACKAGE, "UTF-8"
        );
        GLib.Intl.textdomain(Config.GETTEXT_PACKAGE);
    }

    public static int main (string[] args) {
        /*
        we need to check if window is actually dragged
        width and height will be the same during geometry change than
        */
        string check_geo2 = "";
        string check_geo1 = "";
        Gtk.init(ref args);
        ManageSettings mng = new ManageSettings();
        /*
        if we run dragsnap, disable solus' and mutter's edge-tiling,
        make sure they will stay disabled.
        */
        mng.unset_competition();
        /* translation */
        initialiseLocaleLanguageSupport();
        /* mouse stuff */
        Gdk.Display gdkdsp = Gdk.Display.get_default();
        DragSnapTools dragsnaptools = new DragSnapTools(gdkdsp);
        Gdk.Seat gdkseat = gdkdsp.get_default_seat();
        Gdk.Device pointer = gdkseat.get_pointer();
        /* setup watch scale */
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
                        pointer, scale, new_active
                    );
                }
            });
        });
        Gtk.main();
        return 0;
    }


    class DialogWindow : Gtk.Window {

        ulong[] undo_connect = {};
        Button[] todisconnect = {};

        public DialogWindow (ManageSettings manager) {

            /* css stuff */
            string text_css = ".justbold {font-weight: bold;}";
            Gdk.Screen gdk_scr = this.get_screen();
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(text_css);
                Gtk.StyleContext.add_provider_for_screen(
                    gdk_scr, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }

            /* general window stuff */
            this.set_default_size(600, 100);
            this.set_skip_taskbar_hint(true);
            this.set_decorated(false);
            this.set_keep_above(true);
            this.set_position(Gtk.WindowPosition.CENTER_ALWAYS);
            Gtk.Grid maingrid = new Gtk.Grid();
            this.add(maingrid);

            /* header */
            string header = "Drag-snap";
            Label h = new Label(header);
            set_margins(h, 30, 30, 30, 0);
            maingrid.attach(h, 0, 0, 1, 1);
            h.get_style_context().add_class("justbold");

            /* text message */
            // TRANSLATORS: "drag-snap" does not need to be translated since it is the name of the window tiling mechanism for our window shuffler
            string textblock = _("Drag-snap has replaced built-in edge-tiling. " +
            "To choose built-in edge-tiling instead, " +
            "press Built-in.");
            Label l = new Label(textblock);
            set_margins(l, 30, 30, 15, 45);
            l.set_line_wrap(true);
            l.set_size_request(540, 10);
            maingrid.attach(l, 0, 5, 1, 1);

            /* images */
            Gtk.Image img1 = new Gtk.Image.from_icon_name(
                "dragsnapimg-symbolic", Gtk.IconSize.DIALOG
            );
            set_margins(img1, 120, 120, 0, 10);
            img1.set_pixel_size(120);
            Gtk.Image img2 = new Gtk.Image.from_icon_name(
                "dragsnapimgbuiltin-symbolic", Gtk.IconSize.DIALOG
            );
            img2.set_pixel_size(120);
            Box imgbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            imgbox.pack_start(img1, false, false, 0);
            imgbox.pack_start(img2, false, false, 0);
            set_margins(img2, 0, 0, 0, 10);
            maingrid.attach(imgbox, 0, 10, 1, 1);

            /* buttons */
            Gtk.ButtonBox bbox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
            Button keep_dragsnap = new Gtk.Button.with_label("Drag-snap");
            ulong keep_ul = keep_dragsnap.clicked.connect(()=> {
                manager.unset_competition();
                getout();
            });
            Button builtin = new Gtk.Button.with_label(_("Built-in"));
            ulong builtin_ul = builtin.clicked.connect(()=> {
                manager.unset_dragsnap();
                getout();
            });

            undo_connect = {keep_ul, builtin_ul};
            todisconnect = {keep_dragsnap, builtin};

            set_margins(keep_dragsnap, 2, 2, 10, 2);
            set_margins(builtin, 2, 2, 10, 2);

            keep_dragsnap.set_relief(Gtk.ReliefStyle.NONE);
            builtin.set_relief(Gtk.ReliefStyle.NONE);
            keep_dragsnap.set_size_request(296, 10);
            builtin.set_size_request(296, 10);
            bbox.pack_start(keep_dragsnap);
            bbox.pack_start(builtin);
            maingrid.attach(bbox, 0, 15, 1, 1);
            this.show_all();
            keep_dragsnap.grab_focus();
        }

        private void getout () {
            for (int i=0; i<2; i++) {
                todisconnect[i].disconnect(undo_connect[i]);
            }
            warningdialog = false;
            this.destroy();
        }

        private void set_margins (
            Widget w, int l, int r, int t, int b
        ) {
            w.set_margin_start(l);
            w.set_margin_end(r);
            w.set_margin_top(t);
            w.set_margin_bottom(b);
        }
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
