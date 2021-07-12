using Gtk;
using Gdk;
using GLib.Math;
using Notify;

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
// todo: organize latest n- windows into grid, latest takes biggest section


namespace ShufflerApplet {

    // check scope please. Needed here?
    GLib.Settings settings;
    int maxcols;
    private int previewsize;
    string[] grids;
    bool showonhover;
    Gtk.Switch onhoverswitch;
    SpinButton maxcols_spin;
    SpinButton previewsize_spin;

    private Grid maingrid;

    // keep below section for further development!
    //  ShufflerInfoClient client;

    //  [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    //  interface ShufflerInfoClient : Object {
    //      public abstract int[] get_grid () throws Error;
    //      public abstract int get_greyshade () throws Error;
    //      public abstract void set_greyshade (int newbrightness) throws Error;
    //      public abstract void set_grid (int cols, int rows) throws Error;
    //  }

    //  private void setup_client () {
    //      try {
    //          client = Bus.get_proxy_sync (
    //              BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
    //              ("/org/ubuntubudgie/shufflerinfodaemon")
    //          );
    //      }
    //      catch (Error e) {
    //          stderr.printf ("%s\n", e.message);
    //      }
    //  }

    public class ShufflerAppletSettings : Gtk.Grid {
        /* Budgie Settings -section */

        public ShufflerAppletSettings(GLib.Settings? settings) {
            /*
            * Gtk stuff, widgets etc. here
            */
            this.set_row_spacing(10);
            Label onhoverlabel = new Label("Show popover on hover (without click)");
            Label maxcols_spin_label = new Label("Popover columns (0 is automatic)");
            Label previewsize_label = new Label("Layout preview size (width in px)");
            onhoverlabel.xalign = 0;
            maxcols_spin_label.xalign = 0;
            previewsize_label.xalign = 0;
            this.attach(onhoverlabel, 0, 0, 1, 1);
            this.attach(new Label("\t"), 1, 0, 1, 1);
            Box onhoverswitchbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            onhoverswitchbox.pack_start(onhoverswitch, false, false, 0);
            this.attach(onhoverswitchbox, 2, 0, 1, 1);
            this.attach(maxcols_spin_label, 0, 1, 1, 1);
            this.attach(new Label("\t"), 1, 1, 1, 1);
            this.attach(maxcols_spin, 2, 1, 2, 1);
            this.attach(previewsize_label, 0, 2, 1, 1);
            this.attach(new Label("\t"), 1, 2, 1, 1);
            this.attach(previewsize_spin, 2, 2, 2, 1);
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
        /* misc stuff */
        public ShufflerAppletPopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);
            /* set icon */
            indicatorIcon = new Gtk.Image.from_icon_name(
                "shufflerapplet-symbolic", Gtk.IconSize.MENU
            );
            indicatorBox.add(this.indicatorIcon);
            /* grid */
            maingrid = new Gtk.Grid();
            maingrid.set_column_spacing(20);
            maingrid.set_row_spacing(20);
            set_margins(maingrid, 20, 20, 20, 20);
            //  fillgrid(maingrid);
            this.add(maingrid);
        }
    }

    private void sendwarning(
        string title, string body, string icon = "shufflerapplet-symbolic"
    ) {
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
        Gdk.Screen gdk_scr;
        GLib.Settings shufflersettings;
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

        private void getsettings_values(GLib. Settings settings) {
            maxcols = settings.get_int("maxcols");
            previewsize = settings.get_int("previewsize");
            grids = settings.get_strv("layouts");
            showonhover = settings.get_boolean("showonhover");
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
            /////////////////////////////////
            if (maxcols == 0) {
                maxcols = (int)rint(Math.pow(grids.length, 0.5));
            }
            foreach (string d in grids) {
                if (currcol == maxcols) {
                    currcol = 0;
                    currow += 1;
                }
                Grid layoutgrid = new Grid();
                string[] layout_def = d.split("|");
                string grid_string = layout_def[0];
                string[] gridcolsrows = grid_string.split("x");
                int gridcols = int.parse(gridcolsrows[0]);
                int gridrows = int.parse(gridcolsrows[1]);
                foreach (string s in layout_def) {
                    if (s != grid_string) {
                        //  print(@"$s\n");
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
                                    print ("Oops\n");
                                }
                            }
                            else {
                                sendwarning(
                                    "Shuffler warning", "Please activate Window Shuffler"
                                );
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
                maingrid.show_all();
            }
        }

        public Applet() {

            //  setup_client();
            shufflersettings = new GLib.Settings("org.ubuntubudgie.windowshuffler");
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
            """;
            settings = new GLib.Settings(
                "org.ubuntubudgie.plugins.budgie-shufflerapplet"
            );
            // settings section widgets
            onhoverswitch = new Gtk.Switch(); // settings section
            print("justedited over again\n");
            settings.bind(
                "showonhover", onhoverswitch, "state",
                SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            maxcols_spin = new Gtk.SpinButton.with_range(0, 10, 1);
            settings.bind(
                "maxcols", maxcols_spin, "value",
                SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            previewsize_spin = new Gtk.SpinButton.with_range(120, 240, 1);
            settings.bind(
                "previewsize", previewsize_spin, "value",
                SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            gdk_scr = Gdk.Screen.get_default();
            css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(buttoncss);
                Gtk.StyleContext.add_provider_for_screen(
                    gdk_scr, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
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
                    //  print("entering\n");
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
            getsettings_values(settings);
            refresh_layouts();
            settings.changed.connect(()=> {
                getsettings_values(settings);
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
