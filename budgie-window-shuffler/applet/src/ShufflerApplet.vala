using Gtk;
using Gdk;
using GLib.Math;
using Notify;
using Wnck;

/*
* ShufflerApplet
* Author: Jacob Vlijm
* Copyright © 2017-2021 Ubuntu Budgie Developers
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


namespace ShufflerApplet {

    GLib.Settings shufflerappletsettings;
    GLib.Settings shufflersettings;
    private int previewsize;
    string[] grids;
    bool showonhover;
    bool gridsync;
    private Grid maingrid;

    ShufflerInfoClient client;

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        public abstract int check_windowvalid (int xid) throws Error;
        public abstract void activate_window (int xid) throws Error;
        public abstract int getactivewin () throws Error;
        public abstract int[] get_winspecs (int w_id) throws Error;
        public abstract bool useanimation () throws Error;
        public abstract void move_window(
            int w_id, int x, int y, int width, int height,
            bool nowarning = false
        ) throws Error;
        public abstract void move_window_animated(
            int w_id, int x, int y, int width, int height
        ) throws Error;
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

    private bool procruns (string processname) {
        string cmd = Config.PACKAGE_BINDIR + @"/pgrep -f $processname";
        string output;
        try {
            GLib.Process.spawn_command_line_sync(cmd, out output);
            if (output != "") {
                return true;
            }
        }
        /* on an unlike to happen exception, return false */
        catch (SpawnError e) {
            return false;
        }
        return false;
    }


    public class ShufflerAppletSettings : Gtk.Grid {
        /* Budgie Settings -section */
        public ShufflerAppletSettings(GLib.Settings? settings) {
            this.set_row_spacing(10);
            Button callsettings = new Gtk.Button();
            callsettings.label = _("Open Shuffler settings");
            callsettings.clicked.connect(()=> {
                if (procruns(Config.SHUFFLER_DIR + "/shuffler_control")) {
                    string user = Environment.get_user_name();
                    try {
                        File showpage_trigger = File.new_for_path(
                            @"/tmp/shufflerapplettrigger_$user"
                        );
                        showpage_trigger.create(FileCreateFlags.NONE);
                    }
                    catch (Error e) {
                        message("something went wrong creating trigger file");

                    }
                }
                else {
                    string cmd = Config.SHUFFLER_DIR + "/shuffler_control 3";
                    // string cmd = "/usr/lib/budgie-window-shuffler" + "/shuffler_control 3";
                    try {
                    Process.spawn_command_line_async(cmd);
                    }
                    catch (Error e) {
                        stderr.printf ("%s\n", e.message);
                    }
                }
            });
            this.attach(callsettings, 0, 0, 1, 1);
            this.show_all();
        }
    }

    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget(string uuid) {
            return new Applet();
        }
    }

    private void set_margins(
        Gtk.Grid grid, int left, int right, int top, int bottom
    ) {
        // lazy margins on a grid
        grid.set_margin_start(left);
        grid.set_margin_end(right);
        grid.set_margin_top(top);
        grid.set_margin_bottom(bottom);
    }


    public class ShufflerAppletPopover : Budgie.Popover {

        private Gtk.Image indicatorIcon;

        public ShufflerAppletPopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);
            indicatorIcon = new Gtk.Image.from_icon_name(
                "shufflerapplet-symbolic", Gtk.IconSize.MENU
            );
            indicatorBox.add(this.indicatorIcon);
            maingrid = new Gtk.Grid();
            maingrid.set_column_spacing(20);
            maingrid.set_row_spacing(20);
            set_margins(maingrid, 20, 20, 20, 20);
            this.add(maingrid);
        }
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


    public class Applet : Budgie.Applet {

        Gtk.CssProvider css_provider;
        GLib.Settings general_desktopsettings;
        Gdk.Screen gdk_scr;
        Wnck.Screen wnck_scr;
        int maxcols;
        private Gtk.EventBox indicatorBox;
        private ShufflerAppletPopover popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        public string uuid { public set; public get; }
        /* specifically to the settings section */
        public override bool supports_settings()
        {
            return true;
        }
        public override Gtk.Widget? get_settings_ui()
        {
            return new ShufflerAppletSettings(this.get_applet_settings(uuid));
        }

        public void initialiseLocaleLanguageSupport() {
            // Initialize gettext
            GLib.Intl.setlocale(GLib.LocaleCategory.ALL, "");
            GLib.Intl.bindtextdomain(
                Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR
            );
            GLib.Intl.bind_textdomain_codeset(
                Config.GETTEXT_PACKAGE, "UTF-8"
            );
            GLib.Intl.textdomain(Config.GETTEXT_PACKAGE);
        }

        private void getsettings_values(GLib. Settings shufflerappletsettings) {
            maxcols = shufflerappletsettings.get_int("maxcols");
            previewsize = shufflerappletsettings.get_int("previewsize");
            grids = shufflerappletsettings.get_strv("layouts");
            showonhover = shufflerappletsettings.get_boolean("showonhover");
            gridsync = shufflerappletsettings.get_boolean("gridsync");
        }

        private Variant? check_visible(HashTable<string, Variant>? wins, int wid) {
            // check if window is on this workspace & not minimized
            if (wins != null) {
                foreach (string k in wins.get_keys()) {
                    if (@"$wid" == k) {
                        Variant match = wins[k];
                        if (
                            (string)match.get_child_value(1) == "true" &&
                            (string)match.get_child_value(7) == "false"
                        ) {
                            Variant newdata = new Variant(
                                "(iiiiis)", wid, (int)match.get_child_value(3),
                                (int)match.get_child_value(4),
                                (int)match.get_child_value(5),
                                (int)match.get_child_value(6),
                                (string)match.get_child_value(0)

                            );
                            return newdata;
                        }
                    }
                }
            }
            return null;
        }

        private void swap_recent_windows() {
            bool useanimation = false;
            try {
                useanimation = client.useanimation();
            }
            catch (Error e) {
                message("Can't get animation settings from daemon");
            }
            Variant[] valid_wins = getvalidwins();
            int n_windows = valid_wins.length;
            if (n_windows > 2) {
                valid_wins = valid_wins[(n_windows-2):n_windows];
            }
            // so, if we finally got our windows to work with...
            if (valid_wins.length == 2) {
                int curr_index = 0;
                foreach (Variant winsubject in valid_wins) {

                    int target_index = 0;
                    if (curr_index == 0) {
                        target_index = 1;
                    }
                    try {
                        Variant usetarget = valid_wins[target_index];
                        int use_win = (int)winsubject.get_child_value(0);
                        int y_shift = client.get_winspecs(use_win)[0];
                        int targetx = (int)usetarget.get_child_value(1);
                        int targety = (int)usetarget.get_child_value(2);
                        int targetw = (int)usetarget.get_child_value(3);
                        int targeth = (int)usetarget.get_child_value(4);
                        if (useanimation) {
                            client.move_window_animated(
                                use_win, targetx, targety - y_shift, targetw, targeth
                            );
                            Thread.usleep(250000);
                        }
                        else {
                            client.move_window(
                             use_win, targetx, targety - y_shift, targetw, targeth
                            );
                        }
                    }
                    catch (Error e) {
                        error ("Error: %s", e.message);
                    }
                    curr_index += 1;
                }
            }
        }

        private void refresh_layouts() {
            // after gsettings change, repopulate popovergrid
            // remove old stuff
            foreach (Widget w in maingrid.get_children()) {
                w.destroy();
            }
            // from settings
            int area_ysize = (int)(previewsize*0.67);
            int currcol = 0;
            int currow = 0;
            // real cols (for swapbutton alignment)
            int realcols = 0;
            if (maxcols == 0) {
                maxcols = (int)rint(Math.pow(grids.length, 0.5));
            }
            int add = 1;
            int group_number = 0;
            foreach (string d in grids) {
                if (currcol > realcols) {
                    realcols = currcol;
                }
                if (currcol == maxcols) {
                    currcol = 0;
                    currow += 1;
                    add = 0;
                }
                Grid layoutgrid = new Grid();
                string[] layout_def = d.split("|");
                string grid_string = layout_def[0];
                string[] gridcolsrows = grid_string.split("x");
                int gridcols = int.parse(gridcolsrows[0]);
                int gridrows = int.parse(gridcolsrows[1]);

                foreach (string s in layout_def) {
                    int n_tiles = layout_def.length - 1; //so:  minus grid definition
                    if (s != grid_string) {
                        int[] coords = {};
                        foreach (string c in s.split(",")) {
                            coords += int.parse(c);
                        }
                        Button sectionbutton = new Button();
                        sectionbutton.get_style_context().add_class("windowbutton");
                        int xpos = coords[0];
                        int ypos = coords[1];
                        int xspan = coords[2];
                        int yspan = coords[3];
                        sectionbutton.set_relief(Gtk.ReliefStyle.NONE);
                        sectionbutton.set_size_request((int)(
                            xspan * (previewsize/gridcols)),
                            (int)(yspan * (area_ysize/gridrows))
                        );
                        int currpos = group_number;
                        sectionbutton.clicked.connect((currposition)=> {
                            string cmd = Config.SHUFFLER_DIR + "/tile_active ".concat(
                                @"$xpos $ypos $gridcols $gridrows $xspan $yspan"
                            );
                            bool shufflerruns = shufflersettings.get_boolean("runshuffler");
                            if (shufflerruns) {
                                try {
                                Process.spawn_command_line_async(cmd);
                                }
                                catch (Error e) {
                                    stderr.printf ("%s\n", e.message);
                                }
                                if (shufflerappletsettings.get_boolean("tilemultiple")) {
                                    tile_abunch(currpos, n_tiles, s, gridcols, gridrows);
                                }
                            }
                            else {
                                sendwarning(
                                    _("Shuffler warning"), _("Please activate Window Shuffler")
                                );
                            }
                            if (gridsync) {
                                shufflersettings.set_int("cols", gridcols);
                                shufflersettings.set_int("rows", gridrows);
                            }
                            popover.set_visible(false);
                        });
                        layoutgrid.attach(
                            sectionbutton, xpos, ypos, xspan, yspan
                        );
                    }
                }
                maingrid.attach(layoutgrid, currcol, currow, 1, 1);
                currcol += 1;
                group_number += 1;
            }
            Gtk.Box swapbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Button swapbutton = new Button.from_icon_name(
                "shuffler-swapwindows-symbolic", Gtk.IconSize.DND
            );
            //  swapbox.pack_start(swapbutton, true, false, 0);
            swapbutton.set_tooltip_text(
                _("Swap position and size of the two most recently focussed windows")
            );
            swapbutton.set_relief(Gtk.ReliefStyle.NONE);
            swapbutton.get_style_context().add_class("otherbutton");
            swapbutton.clicked.connect(()=> {
                swap_recent_windows();
                popover.set_visible(false);
            });
            string currcolor = "tilebunch_off";
            if (shufflerappletsettings.get_boolean("tilemultiple")) {
                currcolor = "tilebunch_on";
            }
            Gtk.Button toggle_gridall = new Button.from_icon_name(
                "shuffler-applet-tileall-symbolic", Gtk.IconSize.DND
            );
            toggle_gridall.set_tooltip_text(
                _("Reorganize secundary windows into layout").concat(
                    " - ", _("Toggle mode")
            ));
            toggle_gridall.get_style_context().add_class(currcolor);
            toggle_gridall.clicked.connect(set_tilebunchcolor);
            toggle_gridall.set_relief(Gtk.ReliefStyle.NONE);
            Gtk.Box subbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            subbox.pack_start(swapbutton, false, false, 0);
            subbox.pack_start(toggle_gridall, false, false, 0);
            swapbox.pack_start(subbox, true, false, 0);
            maingrid.show_all();
            maingrid.attach(
                swapbox, 0, 100, realcols + add, 1
            );
            maingrid.show_all();
        }

        private Variant[] getvalidwins () {
            HashTable<string, Variant>? wins = null;
            try {
                wins = client.get_winsdata ();
            }
            catch (Error e) {
                message("Can't get window data from daemon");
            }
            Variant[] valid_wins = {};
            try {
                foreach (Wnck.Window w in wnck_scr.get_windows_stacked()) {
                    int w_id = (int)w.get_xid();
                    Variant visible_win = check_visible(wins, w_id);
                    if (
                        // check valid & visible (on this ws, not minimized)
                        client.check_windowvalid(w_id) != -1 &&
                        visible_win != null
                    ) {
                        // but now we only need xid
                        // currwindows += w_id;
                        valid_wins += visible_win;
                    }
                }
            }
            catch (Error e) {
                message("Something went wrong creating valid window list (int)");
            }
            return valid_wins;
        }

        private void tile_abunch(
            int currpos, int n_tiles, string active_target,
            int gridcols, int gridrows
        ) {
            // visually separate main action from reorganizing secundary windows
            Thread.usleep(250000);
            // 1. GET TASKS
            string[] currtaskdata =  grids[currpos].split("|");
            // remove gridsize
            currtaskdata = currtaskdata[1:currtaskdata.length];
            // remove task, if already done in area button action
            string[] filtered_taskdata = {};
            foreach (string st in currtaskdata) {
                if (st != active_target) {
                    filtered_taskdata += st;
                }
            }
            currtaskdata = filtered_taskdata;
            // 2. GET WINDOW SUBJECTS
            Variant[] currwins = getvalidwins(); // <- newest = last
            // let's get the xid of most recent window first (for re- focus)
            int mostrecent_xid = -1;
            int ncurrwins = currwins.length;
            if (ncurrwins != 0) {
                mostrecent_xid = (int)currwins[ncurrwins - 1].get_child_value(0);
            }
            // reverse and filter out active window (last in array, is already moved)
            Variant[] reversed_wins = {};
            int nwins = currwins.length - 1; // -1, since we want to skip active window
            while (nwins > 0) {
                reversed_wins += currwins[nwins - 1];
                nwins -= 1;
            }
            currwins = reversed_wins; // <- first is newest
            // 3. OK, get the job done
            // see how many tasks we actually have
            int ntasks = currtaskdata.length;
            // let's say we don't know:
            nwins = currwins.length;
            if (nwins < ntasks) {
                ntasks = nwins;
            }
            int taskindex = 0;
            while (taskindex < ntasks) {
                /*
                / additional data in Variant could come handy if we would
                / want to do more with it in future (magnetic reorganize)
                */
                Variant currwinsubject = currwins[taskindex];
                int winkey = (int)currwinsubject.get_child_value(0);
                string[] currtask = filtered_taskdata[taskindex].split(",");
                string gridx = currtask[0];
                string gridy = currtask[1];
                string xspan = currtask[2];
                string yspan = currtask[3];
                // softmove is off if we move more then one or two
                string newcommand = Config.SHUFFLER_DIR + "/tile_active ".concat(
                    @"$gridx $gridy $gridcols ",
                    @"$gridrows $xspan $yspan nosoftmove id=$winkey"
                );
                try {
                    Process.spawn_command_line_async(newcommand);
                }
                catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
                Thread.usleep(100000);
                try {
                    client.activate_window(mostrecent_xid);
                }
                catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
                taskindex += 1;
            }
        }

        private void set_tilebunchcolor (Button tabutton) {
            bool oldval = shufflerappletsettings.get_boolean("tilemultiple");
            shufflerappletsettings.set_boolean("tilemultiple", !oldval);
        }

        public Applet() {
            setup_client();
            initialiseLocaleLanguageSupport();
            wnck_scr = Wnck.Screen.get_default();
            shufflersettings = new GLib.Settings("org.ubuntubudgie.windowshuffler");
            shufflerappletsettings = new GLib.Settings(
                "org.ubuntubudgie.plugins.budgie-shufflerapplet"
            );
            general_desktopsettings = new GLib.Settings(
                "org.gnome.desktop.interface"
            );
            string buttoncss = """
            .windowbutton {
                margin: 2px;
                box-shadow: none;
                background-color: rgb(210, 210, 210);
                min-width: 4px;
            }
            .windowbutton:hover {
                background-color: rgb(0, 100, 148);
            }
            .otherbutton {
                color: rgb(210, 210, 210);
                background-color: rgba(0, 100, 148, 0);
                margin: 0px;
            }
            .otherbutton:hover {
                color: rgb(105, 105, 105);
                background-color: rgba(0, 100, 148, 0);
            }
            .tilebunch_off {
                color: rgb(210, 210, 210);
                background-color: rgba(0, 100, 148, 0);
                margin: 0px;
            }
            .tilebunch_off:hover {
                color: rgb(105, 105, 105);
                background-color: rgba(0, 100, 148, 0);
            }
            .tilebunch_on {
                color: rgb(150, 150, 150);
                background-color: rgba(0, 100, 148, 0);
            }

            """;
            gdk_scr = Gdk.Screen.get_default();
            css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(buttoncss);
                Gtk.StyleContext.add_provider_for_screen(
                    gdk_scr, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
            /* box */
            indicatorBox = new Gtk.EventBox();
            add(indicatorBox);
            /* Popover */
            popover = new ShufflerAppletPopover(indicatorBox);
            /* On Event indicatorBox */
            // if hover is set
            indicatorBox.enter_notify_event.connect(()=> {
                if (showonhover) {
                    popover.set_visible(true);
                    return Gdk.EVENT_STOP;
                }
                return false;
            });
            // if click is set
            indicatorBox.button_press_event.connect((e)=> {
                if (!showonhover) {
                    if (e.button != 1) {
                        return Gdk.EVENT_PROPAGATE;
                    }
                    if (popover.get_visible()) {
                        popover.hide();
                    } else {
                        this.manager.show_popover(indicatorBox);
                    }
                    return Gdk.EVENT_STOP;
                }
                return false;
            });
            getsettings_values(shufflerappletsettings);
            refresh_layouts();
            shufflerappletsettings.changed.connect(()=> {
                getsettings_values(shufflerappletsettings);
                refresh_layouts();
            });
            popover.get_child().show_all();
            show_all();
        }

        public override void update_popovers(Budgie.PopoverManager? manager)
        {
            this.manager = manager;
            manager.register_popover(indicatorBox, popover);
        }
    }
}


[ModuleInit]
public void peas_register_types(TypeModule module){
    /* boilerplate - all modules need this */
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(ShufflerApplet.Plugin)
    );
}

// 779
