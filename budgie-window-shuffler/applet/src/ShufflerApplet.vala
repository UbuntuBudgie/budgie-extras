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

// todo: run only if shuffler runs -> done
// todo: translations/meson stuff etc etc
// todo; paths from Config


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
        public abstract void set_grid (int cols, int rows) throws Error;
        public abstract int check_windowvalid (int xid) throws Error;
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


    public class ShufflerAppletSettings : Gtk.Grid {
        /* Budgie Settings -section */
        Gtk.Switch onhoverswitch;
        Gtk.Switch gridsyncswitch;
        SpinButton maxcols_spin;
        SpinButton previewsize_spin;

        public ShufflerAppletSettings(GLib.Settings? settings) {

            this.set_row_spacing(10);

            onhoverswitch = new Gtk.Switch();
            shufflerappletsettings.bind(
                "showonhover", onhoverswitch, "state",
                SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            gridsyncswitch = new Gtk.Switch();
            shufflerappletsettings.bind(
                "gridsync", gridsyncswitch, "state",
                SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            maxcols_spin = new Gtk.SpinButton.with_range(0, 10, 1);
            shufflerappletsettings.bind(
                "maxcols", maxcols_spin, "value",
                SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            previewsize_spin = new Gtk.SpinButton.with_range(120, 240, 1);
            shufflerappletsettings.bind(
                "previewsize", previewsize_spin, "value",
                SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            Label onhoverlabel = new Label("Show popover on hover (without click)");
            onhoverlabel.xalign = 0;
            this.attach(onhoverlabel, 0, 0, 1, 1);
            this.attach(new Label("\t"), 1, 0, 1, 1);
            Box onhoverswitchbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            onhoverswitchbox.pack_start(onhoverswitch, false, false, 0);
            this.attach(onhoverswitchbox, 2, 0, 1, 1);

            Label gridsynclabel = new Label("Synchronize grid size");
            gridsynclabel.xalign = 0;
            this.attach(gridsynclabel, 0, 1, 1, 1);
            this.attach(new Label("\t"), 1, 1, 1, 1);
            Box gridsyncswitchbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            gridsyncswitchbox.pack_start(gridsyncswitch, false, false, 0);
            gridsyncswitch.set_tooltip_text(
                "Update grid size for moving & resizing to latest picked layout"
            );
            this.attach(gridsyncswitchbox, 2, 1, 1, 1);

            Label maxcols_spin_label = new Label("Popover columns (0 is automatic)");
            maxcols_spin_label.xalign = 0;
            this.attach(maxcols_spin_label, 0, 2, 1, 1);
            this.attach(new Label("\t"), 1, 2, 1, 1);
            this.attach(maxcols_spin, 2, 2, 2, 1);

            Label previewsize_label = new Label("Layout preview size (width in px)");
            previewsize_label.xalign = 0;
            this.attach(previewsize_label, 0, 3, 1, 1);
            this.attach(new Label("\t"), 1, 3, 1, 1);
            this.attach(previewsize_spin, 2, 3, 2, 1);

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
                                "(iiiii)", wid, (int)match.get_child_value(3),
                                (int)match.get_child_value(4),
                                (int)match.get_child_value(5),
                                (int)match.get_child_value(6)
                            );
                            return newdata;
                        }
                    }
                }
            }
            return null;
        }

        // private bool get_animated() {
        //     bool general_animation = general_desktopsettings.get_boolean("enable-animations");
        //     bool shuffler_animation = shufflersettings.get_boolean("softmove");
        //     bool generalfirst = shufflersettings.get_boolean("usegeneralanimation");
        //     if (generalfirst) {
        //         return general_animation;
        //     }
        //     else {
        //         return shuffler_animation;
        //     }
        // }

        private void swap_recent_windows() {
            bool useanimation = false;
            try {
                useanimation = client.useanimation();
            }
            catch (Error e) {
                message("Can't get animation settings from daemon");
            }
            // swap positions of the two latest visoble windows with focus
            Variant[] valid_wins = {};

            HashTable<string, Variant>? wins = null;
            try {
                wins = client.get_winsdata ();
            }
            catch (Error e) {
                message("Can't get window data from daemon");
            }

            try {
                foreach (Wnck.Window w in wnck_scr.get_windows_stacked()) {
                    int w_id = (int)w.get_xid();
                    Variant visible_win = check_visible(wins, w_id);
                    if (
                        // check valid & visible (on this ws, not minimized)
                        client.check_windowvalid(w_id) != -1 &&
                        visible_win != null
                    ) {
                        valid_wins += visible_win;
                    }
                }
            }
            catch (Error e) {
                message("Something went wrong creating valid window list");
            }
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
                    if (s != grid_string) {
                        int[] coords = {};
                        foreach (string c in s.split(",")) {
                            coords += int.parse(c);
                        }
                        Button sectionbutton = new Button();
                        //  MenuButton sectionbutton = new MenuButton();
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
                        sectionbutton.clicked.connect(()=> {
                            //  string cm = Config.SHUFFLER_DIR + "/softmove ".concat(
                            string cmd = "/usr/lib/budgie-window-shuffler" + "/tile_active ".concat(
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
                            }
                            else {
                                sendwarning(
                                    "Shuffler warning", "Please activate Window Shuffler"
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
            }

            Gtk.Box swapbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            // Button swapbutton = new Gtk.Button();

            Button swapbutton = new Button.from_icon_name(
                "shufflerswapwindows-symbolic", Gtk.IconSize.DND
            );
            swapbox.pack_start(swapbutton, true, false, 0);
            swapbutton.set_tooltip_text(
                "Swap position and size of the two most recently focussed windows"
            );
            swapbutton.set_relief(Gtk.ReliefStyle.NONE);
            swapbutton.get_style_context().add_class("otherbutton");
            swapbutton.clicked.connect(()=> {
                swap_recent_windows();
                popover.set_visible(false);
            });
            // swapbutton.label = "🠰 🠲";
            maingrid.attach(
                swapbox, 0, 100, realcols + add, 1
            );
            maingrid.show_all();
        }

        public Applet() {

            setup_client();
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
                background-color: rgba(0, 100, 148, 0)
            }
            .otherbutton:hover {
                color: rgb(105, 105, 105);
                background-color: rgba(0, 100, 148, 0)
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
