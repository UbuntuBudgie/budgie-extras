using Gtk;
using Gdk;
using libxfce4windowing;
/*
* VisualSpace
* Author: Jacob Vlijm
* Copyright © 2017-2025 Ubuntu Budgie Developers
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

    private libxfce4windowing.Screen xfw_screen;
    private libxfce4windowing.WorkspaceManager ws_manager;
    private GLib.Settings visualspace_settings;
    private Gdk.Screen gdkscreen;
    private string fontspacing_css;

    // Helper class for labwc workspace management
    private class LabwcWorkspaceHelper {
        private string config_path;

        public LabwcWorkspaceHelper() {
            // Check for config in XDG_CONFIG_HOME or fallback to ~/.config
            string config_home = Environment.get_variable("XDG_CONFIG_HOME");
            if (config_home == null || config_home == "") {
                config_home = Path.build_filename(Environment.get_home_dir(), ".config");
            }
            config_path = Path.build_filename(config_home, "budgie-desktop", "labwc", "rc.xml");
        }

        public int get_workspace_count() throws GLib.Error {
            if (!FileUtils.test(config_path, FileTest.EXISTS)) {
                warning("labwc config not found at %s", config_path);
                return -1;
            }

            string contents;
            FileUtils.get_contents(config_path, out contents);

            // Parse XML to find <desktops number="X"/>
            var regex = new Regex("<desktops\\s+number=\"(\\d+)\"");
            MatchInfo match_info;

            if (regex.match(contents, 0, out match_info)) {
                string num_str = match_info.fetch(1);
                return int.parse(num_str);
            }

            return -1;
        }

        public bool set_workspace_count(int count) throws GLib.Error {
            if (!FileUtils.test(config_path, FileTest.EXISTS)) {
                warning("labwc config not found at %s", config_path);
                return false;
            }

            string contents;
            FileUtils.get_contents(config_path, out contents);

            // Replace the desktops number attribute
            var regex = new Regex("<desktops\\s+number=\"\\d+\"");
            string new_contents = regex.replace(contents, -1, 0,
                @"<desktops number=\"$count\"");

            // Write back to file
            FileUtils.set_contents(config_path, new_contents);

            // Reconfigure labwc
            return reconfigure_labwc();
        }

        private bool reconfigure_labwc() {
            try {
                string[] spawn_args = {"labwc", "-r"};
                Process.spawn_async(null, spawn_args, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL,
                    null, null);
                return true;
            } catch (SpawnError e) {
                warning("Failed to reconfigure labwc: %s", e.message);
                return false;
            }
        }
    }

    private LabwcWorkspaceHelper? labwc_helper = null;

    public class VisualSpacePopover : Budgie.Popover {

        private ScrolledWindow scrollwin;
        private Gtk.EventBox indicatorBox;
        private Grid maingrid;
        private Label nspaces_show;
        private Label? topspace1=null;
        Button nspaces_down;
        Button nspaces_up;
        const string INSTRUCTION = "scrollinstruction";

        public VisualSpacePopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);
            this.indicatorBox = indicatorBox;

            xfw_screen = libxfce4windowing.Screen.get_default();
            ws_manager = xfw_screen.get_workspace_manager();

            maingrid = new Gtk.Grid();
            maingrid.show_all();
            produce_content ();

            // Initialize labwc helper for workspace management
            try {
                labwc_helper = new LabwcWorkspaceHelper();
            } catch (GLib.Error e) {
                warning("Failed to initialize labwc helper: %s", e.message);
            }

            // supergrid, including maingrid
            Grid supergrid = new Gtk.Grid();

            // buttonbox & elements, holding top section
            ButtonBox ws_managebox = new ButtonBox(Gtk.Orientation.HORIZONTAL);
            ws_managebox.set_layout(Gtk.ButtonBoxStyle.CENTER);

            /*
                TRANSLATORS: automatic dynamic workspace control
             */
            CheckButton autobutton = new CheckButton.with_label(_("Auto"));
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

            // topspacelabel
            int closednumber = visualspace_settings.get_int(INSTRUCTION);
            if (closednumber != 2) {
                topspace1 = new Gtk.Label(null);
                topspace1.set_markup("<b>" + _("Scroll over panel icon to change workspace") + "</b>");
                supergrid.attach(topspace1, 0, 0, 1, 1);
            }

            supergrid.attach(scrollwin, 0, 10, 1, 1);
            supergrid.attach(ws_managebox, 0, 1, 1, 1);

            // throw all stuff at each other
            scrollwin.add(maingrid);
            this.add(supergrid);

            // Connect to workspace change signals
            connect_workspace_signals();

            this.closed.connect(() => {
                int closed = visualspace_settings.get_int(INSTRUCTION);
                if (closed >= 2 && topspace1 != null) {
                    topspace1.set_visible(false);
                } else {
                    visualspace_settings.set_int(INSTRUCTION, ++closed);
                }
            });
        }

        private void connect_workspace_signals() {
            // Get workspace groups and connect signals
            unowned var workspace_groups = ws_manager.list_workspace_groups();

            if (workspace_groups != null) {
                foreach (var group in workspace_groups) {
                    group.workspace_added.connect(update_interface);
                    group.workspace_removed.connect(update_interface);
                    group.active_workspace_changed.connect(update_interface);
                }
            }

            // Connect to workspace manager signals for new/destroyed groups
            ws_manager.workspace_created.connect(update_interface);
            ws_manager.workspace_destroyed.connect(update_interface);
        }

        private void add_onespace (string edit) {
            int max_nspace = 8;
            int n_currentworkspaces = 0;

            // Get current workspace count
            unowned var workspace_groups = ws_manager.list_workspace_groups();
            if (workspace_groups != null && workspace_groups.length() > 0) {
                var group = workspace_groups.nth_data(0);
                n_currentworkspaces = (int)group.get_workspace_count();
            } else {
                return;
            }

            try {
                if (edit == "add" && n_currentworkspaces < max_nspace) {
                    // Try using libxfce4windowing first
                   var group = workspace_groups.nth_data(0);
                    try {
                        group.create_workspace("Workspace %lu".printf(group.get_workspace_count() + 1));
                    } catch (GLib.Error e) {
                        // Fallback to labwc workaround
                        if (labwc_helper != null) {
                            labwc_helper.set_workspace_count(n_currentworkspaces + 1);
                        } else {
                            warning("Cannot create workspace: %s", e.message);
                        }
                    }
                } else if (edit == "remove" && n_currentworkspaces > 1) {
                    // Try using libxfce4windowing first
                    var group = workspace_groups.nth_data(0);
                    unowned var workspaces = group.list_workspaces();
                    var last_ws = workspaces.nth_data(n_currentworkspaces - 1);

                    try {
                        if (last_ws != null) {
                            last_ws.remove();
                        }
                    } catch (GLib.Error e) {
                        // Fallback to labwc workaround
                        if (labwc_helper != null) {
                            labwc_helper.set_workspace_count(n_currentworkspaces - 1);
                        } else {
                            warning("Cannot remove workspace: %s", e.message);
                        }
                    }
                }
            } catch (GLib.Error e) {
                warning("Failed to add/remove workspace: %s", e.message);
            }
        }

        private void set_nspaces_show (string? subj = null) {
            unowned var workspace_groups = ws_manager.list_workspace_groups();

            if (workspace_groups != null && workspace_groups.length() > 0) {
                var group = workspace_groups.nth_data(0);
                int new_nspaces = (int)group.get_workspace_count();
                nspaces_show.set_text(new_nspaces.to_string());
            }
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

            // Get workspace groups
            unowned var workspace_groups = ws_manager.list_workspace_groups();

            if (workspace_groups == null || workspace_groups.length() == 0) {
                return;
            }

            // Use the first workspace group (typically there's only one)
            var group = workspace_groups.nth_data(0);
            unowned var workspaces = group.list_workspaces();
            int n_spaces = (int)workspaces.length();

            set_nspaces_show();

            // Create blocks per space
            Grid[] spacegrids = {};

            for (int i=0; i < n_spaces; i++) {
                Grid spacegrid = new Grid();
                Button header = create_spacebutton (i, n_spaces);
                // Get the workspace at this index
                var ws = workspaces.nth_data(i);

                if (ws != null) {
                    header.clicked.connect(() => {
                        try {
                            ws.activate();
                            this.hide();
                        } catch (GLib.Error e) {
                            warning("Failed to activate workspace: %s", e.message);
                        }
                    });
                }

                header.set_relief(Gtk.ReliefStyle.NONE);
                header.set_size_request(260, 0);
                // lazy layout
                spacegrid.attach(header, 2, 0, 10, 1);
                spacegrid.attach(new Label(""), 0, 100, 1, 1);
                spacegrids += spacegrid;
            }

            // Attach workspace grids to main grid
            int blockrow = 0;
            foreach (Grid g in spacegrids) {
                maingrid.attach(g, 1, blockrow, 1, 1);
                blockrow += 1;
            }

            scrollwin = new Gtk.ScrolledWindow (null, null);
            scrollwin.set_propagate_natural_height(true);
            scrollwin.set_max_content_height(350);
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
                return false;
            });
        }
     }

    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget(string uuid) {
            return new Applet();
        }
    }

    public class VisualSpaceSettings : Gtk.Grid {
        /* Budgie Settings -section */
        private CheckButton reversebutton;

        public VisualSpaceSettings() {
            var widthlabel = new Label(_("Reverse Scroll Direction"));
            widthlabel.set_xalign(0);

            reversebutton = new Gtk.CheckButton();
            this.attach(reversebutton, 0, 1, 1, 1);
            this.attach(widthlabel, 1, 1, 1, 1);

            this.show_all();

            visualspace_settings.bind("reverse-scroll", reversebutton, "active",
                SettingsBindFlags.GET|SettingsBindFlags.SET);
        }
    }

    public class Applet : Budgie.Applet {

        private Gtk.EventBox indicatorBox;
        private VisualSpacePopover popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        public string uuid { public set; public get; }
        Label label = new Label("");
        bool usevertical;

        public override void panel_position_changed(
            Budgie.PanelPosition position
        ) {
            if (
                position == Budgie.PanelPosition.LEFT ||
                position == Budgie.PanelPosition.RIGHT
            ) {
                usevertical = true;
            }
            else {
                usevertical = false;
            }
            update_appearance();
        }

        private void update_appearance () {
            string s = "";
            string charc = "";
            unowned var workspace_groups = ws_manager.list_workspace_groups();

            if (workspace_groups == null || workspace_groups.length() == 0) {
                label.set_text("");
                return;
            }

            var group = workspace_groups.nth_data(0);
            unowned var workspaces = group.list_workspaces();
            var active_ws = group.get_active_workspace();

            foreach (var ws in workspaces) {
                if (ws == active_ws) {
                    charc = "●";
                } else {
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
        }

        public Applet() {

            // misc stuff we are using
            fontspacing_css = """
            .fontspacing {letter-spacing: 3px; font-size: 12px;}
            .linespacing_top {margin-top: 10px;}
            """;
            gdkscreen = this.get_screen();

            xfw_screen = libxfce4windowing.Screen.get_default();
            ws_manager = xfw_screen.get_workspace_manager();

            visualspace_settings = new GLib.Settings("org.ubuntubudgie.plugins.budgie-visualspace");
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

            // Connect to workspace change signals
            connect_workspace_signals();

            // workspace-scrolling
            indicatorBox.add_events(Gdk.EventMask.SCROLL_MASK);
            indicatorBox.scroll_event.connect(movealong_workspaces);
            show_all();
        }

        private void connect_workspace_signals() {
            unowned var workspace_groups = ws_manager.list_workspace_groups();

            if (workspace_groups != null) {
                foreach (var group in workspace_groups) {
                    group.workspace_added.connect(update_appearance);
                    group.workspace_removed.connect(update_appearance);
                    group.active_workspace_changed.connect(update_appearance);
                }
            }

            ws_manager.workspace_created.connect(update_appearance);
            ws_manager.workspace_destroyed.connect(update_appearance);
        }

        private bool movealong_workspaces (Gdk.EventScroll scrollevent) {
            unowned var workspace_groups = ws_manager.list_workspace_groups();

            if (workspace_groups == null || workspace_groups.length() == 0) {
                return false;
            }

            var group = workspace_groups.nth_data(0);
            var active_ws = group.get_active_workspace();

            if (active_ws == null) {
                return false;
            }

            libxfce4windowing.Workspace? new_ws = null;
            Gdk.ScrollDirection upordown = scrollevent.direction;

            bool reverse_scroll = visualspace_settings.get_boolean("reverse-scroll");

            if (reverse_scroll && upordown == Gdk.ScrollDirection.UP) {
                upordown = Gdk.ScrollDirection.DOWN;
            } else if (reverse_scroll && upordown == Gdk.ScrollDirection.DOWN) {
                upordown = Gdk.ScrollDirection.UP;
            }

            if (upordown == Gdk.ScrollDirection.UP) {
                new_ws = active_ws.get_neighbor(libxfce4windowing.Direction.RIGHT);
            } else if (upordown == Gdk.ScrollDirection.DOWN) {
                new_ws = active_ws.get_neighbor(libxfce4windowing.Direction.LEFT);
            }

            if (new_ws != null) {
                try {
                    new_ws.activate();
                } catch (GLib.Error e) {
                    warning("Failed to activate workspace: %s", e.message);
                }
             }

            return false;
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

        /* specifically to the settings section */
        public override bool supports_settings() {
            return true;
        }

        public override Gtk.Widget? get_settings_ui() {
            return new VisualSpaceSettings();
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
        catch (GLib.Error e) {
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
