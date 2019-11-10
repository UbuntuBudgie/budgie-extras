using Gtk;
using Gdk;
using Gdk.X11;

/*
* VisualSpace
* Author: Jacob Vlijm
* Copyright © 2017-2019 Ubuntu Budgie Developers
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


namespace VisualSpaceApplet {

    private unowned Wnck.Screen wnckscr;
    private GLib.Settings mutter_ws_settings;
    // related to optional auto-workspaces
    private GLib.Settings visualspace_settings;
    private Gdk.Screen gdkscreen;
    private string fontspacing_css;

    public class VisualSpacePopover : Budgie.Popover {

        Gdk.X11.Window timestamp_window;
        private ScrolledWindow scrollwin;
        private Gtk.EventBox indicatorBox;
        private Grid maingrid;
        private Label nspaces_show;
        Button nspaces_down;
        Button nspaces_up;

        public VisualSpacePopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);
            this.indicatorBox = indicatorBox;
            mutter_ws_settings.changed.connect(set_nspaces_show);
            // X11 stuff, non-dynamic part
            unowned X.Window xwindow = Gdk.X11.get_default_root_xwindow();
            unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
            Gdk.X11.Display display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
            timestamp_window = new Gdk.X11.Window.foreign_for_display(display, xwindow);
            // Wnck initial stuff
            wnckscr =  Wnck.Screen.get_default();
            wnckscr.force_update();
            maingrid = new Gtk.Grid();
            maingrid.show_all();
            produce_content ();
            // supergrid, including maingrid
            Grid supergrid = new Gtk.Grid();
            // buttonbox & elements, holding top section
            ButtonBox ws_managebox = new ButtonBox(Gtk.Orientation.HORIZONTAL);
            // related to optional auto-workspaces
            ws_managebox.set_layout(Gtk.ButtonBoxStyle.CENTER);
            CheckButton autobutton = new CheckButton.with_label((_("Auto"));
            bool autospace = visualspace_settings.get_boolean("autospaces");
            autobutton.set_active(autospace);
            nspaces_down = new Button.from_icon_name(
                "pan-down-symbolic", Gtk.IconSize.MENU
            );
            nspaces_down.set_relief(Gtk.ReliefStyle.NONE);
            nspaces_up = new Button.from_icon_name(
                "pan-up-symbolic", Gtk.IconSize.MENU
            );
            nspaces_up.set_relief(Gtk.ReliefStyle.NONE);
            nspaces_show = new Label("");
            nspaces_show.set_xalign(0);
            set_nspaces_show();
            nspaces_show.set_width_chars(2);
            Box fakespin = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            fakespin.set_baseline_position(Gtk.BaselinePosition.BOTTOM);
            fakespin.pack_start(nspaces_down, false, false, 0);
            fakespin.pack_start(nspaces_show, false, false, 0);
            fakespin.pack_start(nspaces_up, false, false, 0);
            nspaces_up.clicked.connect(() => {
                add_onespace("add");
            });
            nspaces_down.clicked.connect(() => {
                add_onespace("remove");
            });
            ws_managebox.pack_start(fakespin, false, false, 0);

            // related to optional auto-workspaces, uncomment to apply
            // ws_managebox.pack_start(autobutton, false, false, 0);
            // autobutton.toggled.connect(toggle_auto);
            // set_widgets_sensitive(!autospace);

            // linespacing_topspacelabel
            Label topspace1 = new Gtk.Label("");
            Label topspace2 = new Gtk.Label("");
            set_spacing(gdkscreen, topspace1, "linespacing_top");
            set_spacing(gdkscreen, topspace2, "linespacing_bottom");
            supergrid.attach(scrollwin, 0, 10, 1, 1);
            supergrid.attach(ws_managebox, 0, 1, 1, 1);
            supergrid.attach(topspace1, 0, 0, 1, 1);
            supergrid.attach(topspace2, 0, 3, 1, 1);
            // throw all stuff at each other
            scrollwin.add(maingrid);
            this.add(supergrid);
            // refresh on signals
            wnckscr.window_closed.connect(update_interface);
            wnckscr.window_opened.connect(update_interface);
            wnckscr.workspace_created.connect(update_interface);
            wnckscr.workspace_destroyed.connect(update_interface);
        }

        //  private void set_widgets_sensitive (bool opposite_active) {
        //      // related to optional auto-workspaces
        //      nspaces_show.set_sensitive(opposite_active);
        //      nspaces_down.set_sensitive(opposite_active);
        //      nspaces_up.set_sensitive(opposite_active);
        //  }

        //  private void toggle_auto (ToggleButton button) {
        //      // related to optional auto-workspaces
        //      bool newval = button.get_active();
        //      visualspace_settings.set_boolean("autospaces", newval);
        //      set_widgets_sensitive(!newval);
        //  }

        private void add_onespace (string edit) {
            // prevent exceeding 8, due to hardcoded max- nspaces in budgie-wm
            // wm crashes if > 8
            bool act = true;
            int max_nspace = 8;
            int n_currentworkspaces = mutter_ws_settings.get_int(
                "num-workspaces"
            );
            int add = 0;
            if (edit == "add" && n_currentworkspaces < max_nspace) {
                add = 1;
            }
            else if (edit == "remove" && n_currentworkspaces > 1) {
                add = -1;
            }
            else {
                act = false;
            }
            if (act) {
                mutter_ws_settings.set_int(
                    "num-workspaces", n_currentworkspaces + add
                );
            }
        }

        private void set_nspaces_show (string? subj = null) {
            if (subj == "num-workspaces" || subj == null) {
                int new_nspaces = mutter_ws_settings.get_int("num-workspaces");
                nspaces_show.set_text(@"$new_nspaces");
            }
        }

        private uint get_now() {
            // timestamp
            return Gdk.X11.get_server_time(timestamp_window);
        }

        private Button create_spacebutton (int currsubj, int n_spaces) {
            // creates the header-per-workspace button
            Button spaceheader = new Button.with_label("");
            Gtk.Label l = (Gtk.Label)spaceheader.get_child();
            l.set_xalign((float)0.5);
            string s = "";
            for (int i=0; i < n_spaces; i++) {
                string add = "○ ";
                if (i == currsubj) {
                    add = "● ";
                }
                s = s + add;
            }
            l.set_text(s);
            return spaceheader;
        }

        private void produce_content () {
            // topleft / botomright space
            maingrid.attach(new Label("\t"), 0, 0, 1, 1);
            maingrid.attach(new Label("\t"), 100, 100, 1, 1);

            unowned GLib.List<Wnck.Window> wnckstack = wnckscr.get_windows ();
            unowned GLib.List<Wnck.Workspace> wnckspaces = wnckscr.get_workspaces ();
            int n_spaces = (int)wnckspaces.length ();
            // create blocks per space
            Grid[] spacegrids = {};
            int[] grids_rows = {}; // <- to keep track of row while adding buttons

            for (int i=0; i < n_spaces; i++) {
                Grid spacegrid = new Grid();
                Button header = create_spacebutton (i, n_spaces);
                // set spacebutton action
                Wnck.Workspace ws = null;
                int wsindex = 0;
                foreach (Wnck.Workspace w in wnckspaces) {
                    if (wsindex == i) {
                        ws = w;
                        header.clicked.connect (() => {
                            // move to workspace
                            uint now = get_now();
                            ws.activate(now);
                            this.hide();
                        });
                        break;
                    }
                    wsindex += 1;
                }

                header.set_relief(Gtk.ReliefStyle.NONE);
                header.set_size_request(260, 0);
                // lazy layout
                spacegrid.attach(header, 2, 0, 10, 1);
                spacegrid.attach(new Label(" "), 1, 1, 1, 1);

                if (i > 0) {
                    spacegrid.attach(new Label(""), 0, 1, 1, 1);
                }
                spacegrid.attach(new Label(""), 0, 100, 1, 1);

                spacegrids += spacegrid;
                grids_rows += 0;
            }
            // collect window data & create windowname-buttons
            foreach (Wnck.Window w in wnckstack) {
                // get desktop (workspace)
                Wnck.Workspace currspace = w.get_workspace ();
                int currspaceindex = 0;
                int i = 0;
                foreach (Wnck.Workspace win in wnckspaces) {
                    if (win == currspace) {
                        currspaceindex = i;
                        break;
                    }
                    i += 1;
                }
                // type
                Wnck.WindowType type = w.get_window_type ();
                bool normalwindow = type == Wnck.WindowType.NORMAL;
                // icon
                Gdk.Pixbuf app_pixbuf = w.get_mini_icon ();
                Gtk.Image app_image = new Gtk.Image.from_pixbuf(app_pixbuf);
                // name
                string wname = w.get_name ();
                // add to grid
                if (normalwindow) {
                    // fetch the corresponding grid from array & add button
                    Grid editgrid = spacegrids[currspaceindex];
                    int row = grids_rows[currspaceindex];
                    Button windownamebutton = new Gtk.Button.with_label(wname);
                    // set window button action
                    windownamebutton.clicked.connect (() => {
                        //raise_win(s)
                        uint now = get_now();
                        w.activate(now);
                        this.hide();
                    });
                    windownamebutton.set_relief(Gtk.ReliefStyle.NONE);
                    Gtk.Label wbuttonlabel = (Gtk.Label)windownamebutton.get_child();
                    wbuttonlabel.set_ellipsize(Pango.EllipsizeMode.END);
                    wbuttonlabel.set_max_width_chars(28);
                    wbuttonlabel.set_xalign(0);
                    editgrid.attach(windownamebutton, 2, row + 2, 10, 1);
                    editgrid.attach(app_image, 0, row + 2, 1, 1);
                    grids_rows[currspaceindex] = row + 1;
                }
            }
            int blockrow = 0;
            foreach (Grid g in spacegrids) {
                if (grids_rows[blockrow] != 0) {
                    maingrid.attach(g, 1, blockrow + 1, 1, 1);
                }
                blockrow += 1;
            }
            scrollwin = new Gtk.ScrolledWindow (null, null);
            scrollwin.set_min_content_height(350);
            scrollwin.set_min_content_width(365);
        }

        private void update_interface () {
            GLib.List<weak Gtk.Widget> widgets = maingrid.get_children();
            foreach (Gtk.Widget wdg in widgets) {
                GLib.Idle.add( () => {
                    wdg.destroy();
                    return false;
                });
            }
            GLib.Idle.add( () => {
                produce_content ();
                maingrid.show_all();
                scrollwin.show_all();
                // this.show_all();
                return false;
            });
        }
     }

    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget(string uuid) {
            return new Applet();
        }
    }


    public class Applet : Budgie.Applet {

        private Gtk.EventBox indicatorBox;
        private VisualSpacePopover popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        public string uuid { public set; public get; }
        ButtonBox? spacebox = null;
        Label label = new Label("");
        bool usevertical;

        public override void panel_position_changed(Budgie.PanelPosition position) {
            if (
                position == Budgie.PanelPosition.LEFT ||
                position == Budgie.PanelPosition.RIGHT
            ) {
                usevertical = true;
                update_appearance();
            }
        }

        private void update_appearance () {
            string s = "";
            string charc = "";
            spacebox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
            unowned GLib.List<Wnck.Workspace> spaces = wnckscr.get_workspaces();
            Wnck.Workspace curractive = wnckscr.get_active_workspace();
            foreach (Wnck.Workspace w in spaces) {
                if (w == curractive) {
                    charc = "●";
                }
                else {
                    charc = "○";
                }
                s = s + charc;
                if (usevertical) {
                    s = s + "\n";
                }
            }
            label.set_text(s);
            set_spacing(gdkscreen, label, "fontspacing");
            indicatorBox.show_all();
            spacebox.show_all();
        }

        public Applet() {

            // misc stuff we are using
            fontspacing_css = """
            .fontspacing {letter-spacing: 3px; font-size: 12px;}
            .fontspacing_vertical {font-size: 12px;}
            .linespacing_top {margin-top: -12px;}
            .linespacing_bottom {margin-top: -12px;}
            .plusminus {font-size: 24px; font-weight: bold;}
            """;
            gdkscreen = this.get_screen();
            wnckscr = Wnck.Screen.get_default();
            mutter_ws_settings =  new GLib.Settings(
                "org.gnome.desktop.wm.preferences"
            );

            visualspace_settings =  new GLib.Settings(
                "org.ubuntubudgie.plugins.budgie-visualspace"
            );

            initialiseLocaleLanguageSupport();
            // Box
            indicatorBox = new Gtk.EventBox();
            // Popover
            popover = new VisualSpacePopover(indicatorBox);
            // On Press indicatorBox
            indicatorBox.button_press_event.connect((e)=> {
                if (e.button != 1) {
                    return Gdk.EVENT_PROPAGATE;
                }
                if (popover.get_visible()) {
                    popover.hide();
                } else {
                    this.manager.show_popover(indicatorBox);
                }
                return Gdk.EVENT_STOP;
            });
            popover.get_child().show_all();
            add(indicatorBox);
            indicatorBox.add(label);
            update_appearance();
            wnckscr.active_workspace_changed.connect(update_appearance);
            wnckscr.workspace_created.connect(update_appearance);
            wnckscr.workspace_destroyed.connect(update_appearance);
            show_all();
        }

        public override void update_popovers(Budgie.PopoverManager? manager)
        {
            this.manager = manager;
            manager.register_popover(indicatorBox, popover);
        }

        public void initialiseLocaleLanguageSupport(){
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
    }

    public void set_spacing (Gdk.Screen screen, Label label, string st) {
        Gtk.CssProvider css_provider = new Gtk.CssProvider();
        try {
            css_provider.load_from_data(fontspacing_css);
            Gtk.StyleContext.add_provider_for_screen(
                gdkscreen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
            );
            label.get_style_context().add_class(st);
        }
        catch (Error e) {
            // not much to be done
            print("Error loading css data\n");
        }
    }
}


[ModuleInit]
public void peas_register_types(TypeModule module){
    /* boilerplate - all modules need this */
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(VisualSpaceApplet.Plugin)
    );
}