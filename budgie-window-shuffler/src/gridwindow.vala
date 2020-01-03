using Gtk;
using Cairo;
using Gdk;
using Gdk.X11;


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

/*
/ Button color management
/ -----------------------
/ variables played with:
/ - int[] currentlycolored - array of indexes (buttonarr) of currently (permanently, not hovered) colored buttons
/ - int[] currselected - array of indices of corners of the area (can represent either one or two buttons)
/
/ on click:
/ if currselected.length == 1, -and- shift is pressed, the second button(index) is added
/ to currselected and the area in between is calculated -> color button area, move subject window to spanning size.
/ if currselected.length == 2 or 1, (new) currselected only contains the newly pressed button ->
/ move subject window. [send_to_pos(), manage_selection(), manage_selected_color()]
/ while the above is managed, the array currentlycolored is maintained to include all actually colored buttons,
/ to simplify button hover (-color) management [manage_selected_color()].
/ on the occasion of a grid change or a change in window subject, all arrays and button colors are reset
/
/ on hover:
/ temporarily combine data from currselected and hovered button -> calculate min/max, set color.
/ on leave, reset to currentlycolored.
*/

//valac --pkg gio-2.0 --pkg gdk-x11-3.0 --pkg gtk+-3.0 --pkg gdk-3.0 --pkg cairo --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE"

// N.B act on shift press -> update? No.
// todo: gsettings gui_controlsgrid true/false
// todo: gsettings max cols/rows 1-10
// todo: create settings


namespace GridWindowSection {

    Wnck.Screen wnckscr;
    ShufflerInfoClient client;
    Gtk.Window? gridgui;
    Gdk.X11.Window timestamp_window;

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract int[] get_grid () throws Error;
        public abstract void set_grid (int cols, int rows) throws Error;
        public abstract void show_tilepreview (int col, int row, int width = 1, int height = 1) throws Error;
        public abstract void kill_tilepreview () throws Error;
    }

    private void setup_client () {
        try {
            client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    public class GridWindow: Gtk.Window {
        bool shiftispressed;
        int[] currselected; // max 2, only corners of selection
        int gridcols;
        int gridrows;
        Gtk.Button[] buttonarr;
        int[] xpos;
        int[] ypos;
        Gtk.Grid buttongrid;
        ulong? previously_active;
        Gtk.Grid maingrid;
        int[] currentlycolored; // arr of all currently colored buttons

        string gridcss = """
        .gridmanage {
            border-radius: 3px;
            background-color: rgb(235, 235, 235);
            box-shadow: none;
        }
        .gridmanage:hover {
            background-color: rgb(0, 100, 148);
            transition: 0.05s linear;
        }
        .selected {
            background-color: rgb(0, 77, 128);
            transition: 0.05s linear;
        }
        """;

        public GridWindow() {
            this.title = "Gridwindows";
            this.set_position(Gtk.WindowPosition.CENTER_ALWAYS);
            this.enter_notify_event.connect(showquestionmark);
            this.key_press_event.connect(on_shiftpress);
            this.key_release_event.connect(on_shiftrelease);
            wnckscr.active_window_changed.connect(get_subject);
            Wnck.Window? curr_active = wnckscr.get_active_window();
            if (curr_active != null) {
                previously_active = curr_active.get_xid();
            }
            int[] colsrows = get_setcolsrows();
            gridcols = colsrows[0];
            gridrows = colsrows[1];
            // whole bunch of styling
            var screen = this.get_screen();
            this.set_app_paintable(true);
            var visual = screen.get_rgba_visual();
            this.set_visual(visual);
            this.draw.connect(on_draw);
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(gridcss);
                Gtk.StyleContext.add_provider_for_screen(
                    screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }
            // grid and stuff
            maingrid = new Gtk.Grid();
            maingrid.set_column_spacing(6);
            maingrid.set_row_spacing(6);
            this.add(maingrid);
            setgrid();
            //add_gridcontrols();
            currselected = {};
            maingrid.show_all();
            this.set_decorated(false);
            this.set_keep_above(true);
            this.show_all();
        }

        private int[] get_setcolsrows () {
            // get cols & rows from dconf
            int[] colsrows = {0, 0};
            try {
                colsrows = client.get_grid();
            }
            catch (Error E) {
            }
            return colsrows;
        }

        private int find_buttonindex(Gtk.Button b) {
            // look up button index from array (to look up col/row)
            int i = 0;
            foreach (Gtk.Button button in buttonarr) {
                if (button == b) {
                    return i;
                }
                i += 1;
            }
            return -1;
        }

        private bool winstillexists (ulong subj) {
            /*
            / not-so-elegant way to re-check if the subject hasn't just
            / been closed by user. its xid still exists then
            */
            foreach (Wnck.Window w in wnckscr.get_windows()) {
                if (w.get_xid() == subj) {
                    return true;
                }
            }
            print("Oops, no window was selected!\n");
            return false;
        }

        private void send_to_pos (Gtk.Button b) {
            // here we send the subject window to its targeted position, using tile_active
            int index = find_buttonindex(b);
            if (index != -1 && previously_active != null && winstillexists(previously_active)) {
                string cmd_args = manage_selection(b);
                // manage preview shade separately: different rules, algorithm (first make this work)
                string cm = "/home/jacob/Desktop/experisync_edit3/newshuffler_2/tile_active ".concat(
                    cmd_args, " id=", @"$previously_active");
                try {
                    Process.spawn_command_line_async(cm);
                }
                catch (SpawnError e) {
                }
            }
        }

        private int[] get_selectedarea (
            int[] b_indices, int minx = 100,
            int miny = 100, int maxx = 0, int maxy = 0
        ) {
            // get min/max x, min/max y, span x/y of given button-indices
            foreach (int n in b_indices) {
                int x_comp = xpos[n];
                int y_comp = ypos[n];
                if (x_comp < minx) {
                    minx = x_comp;
                }
                if (y_comp < miny) {
                    miny = y_comp;
                }
                if (x_comp > maxx) {
                    maxx = x_comp;
                }
                if (y_comp > maxy) {
                    maxy = y_comp;
                }
            }
            int w = maxx + 1 - minx;
            int h = maxy + 1 - miny;
            return {minx, miny, maxx, maxy, w, h};
        }

        private string manage_selection (Gtk.Button b) {
            /*
            / on-click functionality
            / here we check if we have a multi-span selection
            / & create args for move
            // check if active window != null!
            */
            int n_arrcontent = currselected.length;
            int latest_pressed = find_buttonindex(b);
            if (n_arrcontent == 0 || (n_arrcontent == 1 && shiftispressed)) {
                currselected += latest_pressed;
            }
            else {
                currselected = {latest_pressed};
            }
            // update n_arrcontent
            n_arrcontent = currselected.length;
            int minx = 100;
            int miny = 100;
            int maxx = 0;
            int maxy = 0;
            int w = 1;
            int h = 1;

            if (n_arrcontent == 2) {
                int[] areadata = get_selectedarea(currselected);
                minx = areadata[0];
                miny = areadata[1];
                maxx = areadata[2];
                maxy = areadata[3];
                w = maxx + 1 - minx;
                h = maxy + 1 - miny;

            }
            else {
                minx = xpos[latest_pressed];
                miny = ypos[latest_pressed];
            }
            manage_selected_color(n_arrcontent, minx, miny, maxx, maxy);
            return @"$minx $miny $gridcols $gridrows $w $h";
        }

        private bool check_int(int n, int[] arr) {
            // see if int in array
            for (int i=0; i < arr.length; i++) {
                if(n == arr[i]) return true;
            } return false;
        }

        private void unsetsetcolor_onhover () {
            // on leave, reset colored to current selection
            foreach (Gtk.Button b in buttonarr) {
                if (!check_int(find_buttonindex(b), currentlycolored)) {
                    var ct = b.get_style_context();
                    ct.remove_class("selected");
                }
            }
        }

        private void manage_selected_color (
            int n_arrcontent, int minx, int miny, int maxx, int maxy
        ) {
            // after click, set the selected color for button or area
            // do your bookkeeping on colored buttons
            currentlycolored = {};
            if (n_arrcontent == 1) {
                Gtk.Button newselected = buttonarr[currselected[0]];
                foreach (Gtk.Button b in buttonarr) {
                    var st_gb = b.get_style_context();
                    if (b == newselected) {
                        st_gb.add_class("selected");
                        currentlycolored += find_buttonindex(b);
                    }
                    else {
                        st_gb.remove_class("selected");
                    }
                }
            }
            else {
                foreach (Gtk.Button b in buttonarr) {
                    int index = find_buttonindex(b);
                    int x_comp = xpos[index];
                    int y_comp = ypos[index];
                    var st_gb = b.get_style_context();
                    if (maxx >= x_comp >= minx && maxy >= y_comp >= miny) {
                        st_gb.add_class("selected");
                        currentlycolored += index;
                    }
                    else {
                        st_gb.remove_class("selected");
                    }
                }
            }
        }

        private void unset_colors () {
            foreach (Gtk.Button b in buttonarr) {
                var st_gb = b.get_style_context();
                st_gb.remove_class("selected");
            }
        }

        private void get_subject () {
            // bookkeeping on the window to move
            ulong old_active = previously_active;
            Wnck.Window? curr_active = wnckscr.get_active_window();
            if (curr_active != null) {
                Wnck.WindowType type = curr_active.get_window_type ();
                string wname = curr_active.get_name();
                if (
                    wname != "tilingpreview" &&
                    wname != "Gridwindows" &&
                    type == Wnck.WindowType.NORMAL
                    ) {
                    previously_active = curr_active.get_xid();
                }
                makesure_offocus();
            }
            // unset colors on subject change
            if (old_active != previously_active) {
                unset_colors();
                currentlycolored = {};
            }
        }

        private void setcolor_onhover (Gtk.Button hovered) {
            if (shiftispressed && currentlycolored.length == 1) {
                int[] temporarycolored = currentlycolored;
                temporarycolored += find_buttonindex(hovered);
                int[] temp_area = get_selectedarea(temporarycolored);
                int minx = temp_area[0];
                int miny = temp_area[1];
                int maxx = temp_area[2];
                int maxy = temp_area[3];
                foreach (Gtk.Button b in buttonarr) {
                    int index = find_buttonindex(b);
                    int x_comp = xpos[index];
                    int y_comp = ypos[index];
                    var st_gb = b.get_style_context();
                    if (maxx >= x_comp >= minx && maxy >= y_comp >= miny) {
                        st_gb.add_class("selected");
                    }
                }
                try {
                    client.show_tilepreview(
                        minx, miny, maxx - minx + 1, maxy - miny + 1
                    );
                }
                catch (Error e) {
                }
            }
            else {
                int b_index = find_buttonindex(hovered);
                int col = xpos[b_index];
                int row = ypos[b_index];
                try {
                    client.show_tilepreview(col, row);
                }
                catch (Error e) {
                }
            }
        }

        private bool on_shiftrelease (Gdk.EventKey key) {
            // to keep record of Shift state
            string released = Gdk.keyval_name(key.keyval);
            if (released.contains("Shift")) {
                shiftispressed = false;
            }
            return false;
        }

        private bool on_shiftpress (Gdk.EventKey key) {
            // to keep record of Shift state & send through if not Shift
            string pressed = Gdk.keyval_name(key.keyval);
            if (pressed.contains("Shift")) {
                shiftispressed = true;
            }
            else {
                managegrid(pressed);
            }
            return false;
        }

        private bool showquestionmark () {
            // currently out of a job
            return false;
        }

        private bool killpreview () {
            // kill the preview shade
            try {
                client.kill_tilepreview();
            }
            catch (Error e) {
            }
            return false;
        }

        private bool managegrid (string pressed) {
            // here we set cols.rows on the grid gui,
            // set dconf vals accordingly
            killpreview();
            currselected = {};
            currentlycolored = {};
            int[] currgrid = get_setcolsrows();
            int currcols = currgrid[0];
            int currrows = currgrid[1];
            switch (pressed) {
                case "Up":
                if (currrows > 1) {
                    gridrows = currrows - 1;
                }
                break;
                case "Down":
                if (currrows < 5) {
                    gridrows = currrows + 1;
                }
                break;
                case "Left":
                if (currcols > 1) {
                    gridcols = currcols - 1;
                }
                break;
                case "Right":
                if (currcols < 5) {
                    gridcols = currcols + 1;
                }
                break;
            }
            try {
                client.set_grid(gridcols, gridrows);
            }
            catch (Error e) {
            }
            buttongrid.destroy();
            setgrid();
            maingrid.show_all();
            this.resize(10,10);
            return false;
        }

        private bool on_draw (Widget da, Context ctx) {
            // transparency
            // needs to be connected to transparency settings change?
            ctx.set_source_rgba(0.15, 0.15, 0.15, 0.0);
            ctx.set_operator(Cairo.Operator.SOURCE);
            ctx.paint();
            ctx.set_operator(Cairo.Operator.OVER);
            return false;
        }

        private void setgrid() {
            // create the gui grid + buttons on it
            buttongrid = new Gtk.Grid();
            buttongrid.set_column_spacing(3);
            buttongrid.set_row_spacing(3);
            maingrid.attach(buttongrid, 0, 0, 1, 1);
            for (int iy=0; iy < gridrows; iy++) {
                for (int ix=0; ix < gridcols; ix++) {;
                    var gridbutton = new Gtk.Button();
                    gridbutton.set_size_request(50, 50);
                    var st_gb = gridbutton.get_style_context();
                    st_gb.add_class("gridmanage");
                    buttongrid.attach(gridbutton, ix, iy, 1, 1);
                    xpos += ix;
                    ypos += iy;
                    buttonarr += gridbutton;
                    gridbutton.clicked.connect(send_to_pos);
                    gridbutton.enter_notify_event.connect(()=> {
                        setcolor_onhover(gridbutton);
                        return false;
                    });
                    gridbutton.leave_notify_event.connect(()=> {
                        unsetsetcolor_onhover();
                        return false;
                    });
                    gridbutton.leave_notify_event.connect(killpreview);
                }
            }
        }
    }

    private void actonfile(File file, File? otherfile, FileMonitorEvent event) {
        if (event == FileMonitorEvent.CREATED) {
            gridgui = new GridWindow();
        }
        else if (event == FileMonitorEvent.DELETED) {
            gridgui.destroy();
        }
    }

    private uint get_now () {
        // get timestamp
        return Gdk.X11.get_server_time(timestamp_window);
    }

    private void makesure_offocus () {
        foreach (Wnck.Window w in wnckscr.get_windows()) {
            if (w.get_name() == "Gridwindows") {
                w.activate(get_now());
            }
        }
    }

    public static void main(string[] args) {
        /*
        / minimal main. eventually need to insert a signal watcher to
        / create/destroy the grid window
        */
        setup_client();
        Gtk.init(ref args);
        wnckscr = Wnck.Screen.get_default();
        wnckscr.force_update();
        wnckscr.window_opened.connect(makesure_offocus);
        // X11 stuff, non-dynamic part
        unowned X.Window xwindow = Gdk.X11.get_default_root_xwindow();
        unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
        Gdk.X11.Display display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
        timestamp_window = new Gdk.X11.Window.foreign_for_display(display, xwindow);
        // monitoring files / dirs
        FileMonitor monitor;
        string user = Environment.get_user_name();
        File gridtrigger = File.new_for_path(
            "/tmp/".concat(user, "_gridtrigger")
        );
        try {
            monitor = gridtrigger.monitor(FileMonitorFlags.NONE, null);
            monitor.changed.connect(actonfile);
        }
        catch (Error e) {
        }
        Gtk.main();
    }
}