using Gtk;
using Gdk;
using Wnck;
using Gdk.X11;

// valac --pkg gtk+-3.0 --pkg gdk-x11-3.0 --pkg gdk-3.0 --pkg gio-2.0 --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE"

/*
Budgie Window Shuffler III
Author: Jacob Vlijm
Copyright © 2017-2021 Ubuntu Budgie Developers
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

//todo: translations, paths

namespace ShufflerControls2 {

    GLib.Settings shufflersettings;
    Button applytask_button;

    private void set_widgetstyle(
        Widget w, string css_style, bool remove = false
    ) {
        var widgets_stylecontext = w.get_style_context();
        if (!remove) {
            widgets_stylecontext.add_class(css_style);
        }
        else {
            widgets_stylecontext.remove_class(css_style);
        }
    }


    class OwnSpinButton : Gtk.Grid{

        public Gtk.Entry spinvalue;
        Gtk.Button up;
        Gtk.Button down;
        bool act_onchange;
        // css stuff
        string spin_stylecss = """
        .arrowbutton {
            padding: 0px;
            border-width: 0px;
        }
        .red_text {
            color: white;
            background-color: red;
        }
        """;

        public void set_warning_color(bool warning = false) {
            if (warning) {
                set_widgetstyle(spinvalue, "red_text");

            }
            else {
                set_widgetstyle(spinvalue, "red_text", true);
            }
        }

        public OwnSpinButton(
           string orientation, string key, int min = 0, int max = 10
        ) {
            // css stuff
            act_onchange = true;
            Gdk.Screen gdk_scr = this.get_screen();
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(spin_stylecss);
                Gtk.StyleContext.add_provider_for_screen(
                    gdk_scr, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }
            this.set_column_spacing(0);
            spinvalue = new Gtk.Entry();
            spinvalue.set_editable(false);
            spinvalue.xalign = (float)0.50;
            spinvalue.set_text("0");
            spinvalue.set_width_chars(2);
            spinvalue.set_max_width_chars(2);
            spinvalue.changed.connect(()=>{
                if (key != "") {
                    if (act_onchange) {
                        int set_spinvalue = get_value();
                        shufflersettings.set_int(key, set_spinvalue);
                    }
                }
            });
            if (key != "") {
                shufflersettings.changed[key].connect(()=> {
                    act_onchange = false;
                    update_value(key);
                    act_onchange = true;
                });
            }
            up = new Gtk.Button();
            set_widgetstyle(up, "arrowbutton");
            up.set_size_request(1,1);
            up.set_relief(Gtk.ReliefStyle.NONE);
            down = new Gtk.Button();
            set_widgetstyle(down, "arrowbutton");
            down.set_size_request(1,1);
            down.set_relief(Gtk.ReliefStyle.NONE);
            if (orientation == "hor") {
                up.label = "▶";
                down.label = "◀";
                this.attach(spinvalue, 0, 1, 1, 1);
                this.attach(up, 2, 1, 1, 1);
                this.attach(down, 1, 1, 1, 1);
            }
            else if (orientation == "vert") {
                up.label = "▲";
                down.label = "▼";
                this.attach(spinvalue, 0, 1, 1, 1);
                this.attach(up, 2, 1, 1, 1);
                this.attach(down, 1, 1, 1, 1);
            }
            up.clicked.connect(()=> {
                add_one(up, min, max);
            });
            down.clicked.connect(()=> {
                add_one(down, min, max);
            });
            if (key != "") {
                update_value(key);
            }
        }

        private void update_value (string key) {
            set_value(shufflersettings.get_int(key));
        }

        public int get_value() {
            return int.parse(spinvalue.get_text());
        }

        public void set_value(int newvalue) {
            spinvalue.set_text(@"$newvalue");
        }

        private void add_one(Button b, int min, int max) {
            int curr = int.parse(spinvalue.get_text());
            if (b == up && curr < max) {
                curr += 1;
            }
            else if (b == down && curr > min) {
                curr -= 1;
            }
            spinvalue.set_text(@"$curr");
        }
    }


    class ShufflerControlsWindow : Gtk.Window {

        ExtrasDaemon bd_client;

        [DBus (name = "org.UbuntuBudgie.ExtrasDaemon")]
        interface ExtrasDaemon : Object {
            public abstract bool ReloadShortcuts () throws Error;
        }

        private void setup_client () {
            try {
                bd_client = Bus.get_proxy_sync (
                    BusType.SESSION, "org.UbuntuBudgie.ExtrasDaemon",
                    ("/org/ubuntubudgie/extrasdaemon")
                );
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        Gdk.X11.Window timestamp_window;
        ShufflerInfoClient? client;
        [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]
        interface ShufflerInfoClient : Object {
            public abstract GLib.HashTable<string,
            Variant> get_rules () throws Error;
            public abstract int get_numberof_workspaces() throws Error;
        }
        GLib.HashTable<string, Variant> foundrules;
        FileMonitor monitor_ruleschange;
        Stack allsettings_stack;
        string default_set = _("Not set");
        string controls_css = """
        .somebox {
            border-left: 0px;
            border-bottom: 0px;
            border-top: 0px;
        }
        .justbold {
            font-weight: bold;
        }
        .justitalic {
            font-style: italic;
        }
        """;
        Wnck.Screen wnck_scr;
        Grid tilinggrid;
        Grid layoutsgrid;
        Grid rulesgrid;
        Grid general_settingsgrid;
        Grid newrulesgrid;
        Dialog? get_task;
        Gtk.Switch[] switches;
        string[] read_switchsettings;
        Gtk.CheckButton[] checkbuttons;
        CheckButton toggle_guigrid;
        string[] read_checkbutton;
        string windowrule_location;

        private Gtk.Label makelabel (
            string labeltext, float halign, string? cssclass = null
        ){
            Gtk.Label newlabel = new Gtk.Label(labeltext);
            newlabel.xalign = 0;
            if (cssclass != null) {
                newlabel.get_style_context().add_class(cssclass);
            }
            return newlabel;
        }

        private string[] get_monitornames() {
            Gdk.Display gdk_dsp = Gdk.Display.get_default();
            int n_monitors = gdk_dsp.get_n_monitors();
            string[] monitors = {};
            for (int i=0; i < n_monitors; i++) {
                monitors += gdk_dsp.get_monitor(i).get_model();
            }
            return monitors;
        }

        private int string_inlist (string s, string[] arr) {
            // check if in in array
            for (int i=0; i<arr.length; i++) {
                if (s == arr[i]) {
                    return i;
                }
            }
            return -1;
        }

        private bool ask_confirm(string action) {
            bool confirm = false;
            Dialog ask_confirmdialog = new Dialog();
            ask_confirmdialog.decorated = false;
            ask_confirmdialog.set_transient_for(get_task);
            ask_confirmdialog.set_modal(true);
            Gtk.Box contentarea = ask_confirmdialog.get_content_area();
            var askgrid = new Gtk.Grid();
            contentarea.pack_start(askgrid, false, false, 0);
            set_margins(askgrid, 20, 20, 20, 20);
            askgrid.attach(new Label(action + "\t\t"), 0, 0, 2, 1);
            askgrid.attach(new Label("\n"), 0, 1, 1, 1);
            contentarea.orientation = Gtk.Orientation.VERTICAL;
            Box buttonbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Button cancel = new Gtk.Button();
            cancel.label = (_("No"));
            cancel.get_style_context().add_class("suggested-action");
            askgrid.get_style_context().remove_class("horizontal");
            Button go_on = new Gtk.Button();
            go_on.label = (_("Yes"));
            buttonbox.pack_end(go_on, false, false, 2);
            buttonbox.pack_end(cancel, false, false, 2);
            askgrid.attach(buttonbox, 1, 10, 1, 1);
            go_on.set_size_request(70, 10);
            cancel.set_size_request(70, 10);
            go_on.clicked.connect(()=> {
                confirm = true;
                ask_confirmdialog.destroy();
                ask_confirmdialog = null;
            });
            cancel.clicked.connect(()=> {
                confirm = false;
                ask_confirmdialog.destroy();
                ask_confirmdialog = null;
            });
            askgrid.show_all();
            ask_confirmdialog.run();
            return confirm;
        }
        //////////////////////////////////////////////////////////////////////////////////////
        //////////////////////////////////////////////////////////////////////////////////////

        private string get_value_forrule (string? found, bool tofile = false) {
            // converting readable value of workspace from filedata and vice versa
            /*
            we need to keep: if set_workspace != default_set (in -> togui),
            in case someone already used the dev version,
            but it won't end up in new rules files, because it is language-dependent
            (files wouldn't work anymore if set language would change)
            */
            string set_forrule = default_set;
            int add = 1;
            if (tofile) {
                add = -1;
                set_forrule = "";
            }

            if (found != "" && found != default_set && found != null) {
                set_forrule = (int.parse(found) + add).to_string();
            }
            print(@"set for rule: $set_forrule\n");
            return set_forrule;
        }
        //////////////////////////////////////////////////////////////////////////////////////
        //////////////////////////////////////////////////////////////////////////////////////

        private void call_dialog (string? wmclass = null) {
            bool wmclass_changed = false;
            string? initial_wm = wmclass;
            OwnSpinButton[] allspins;
            string check_changes = "";
            unowned X.Window xwindow = Gdk.X11.get_default_root_xwindow();
            unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
            Gdk.X11.Display display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
            timestamp_window = new Gdk.X11.Window.foreign_for_display(display, xwindow);
            // just to skip first 'false' positive on window focus change
            bool initial_change = true;
            // if wm class is given, we obviously are updating existing rule
            bool update = (wmclass != null);
            // tooltips
            string class_tooltip = (_("Window class of the window to be launched (*mandatory)"));
            string gridxsize_tooltip = (_("Grid size - columns"));
            string gridysize_tooltip = (_("Grid size - rows"));
            string targetpositionx_tooltip = (_("Window target position on grid - horizontally"));
            string targetpositiony_tooltip = (_("Window target position on grid - vertically"));
            string xspan_tooltip = (_("Window size - columns"));
            string yspan_tooltip = (_("Window size - rows"));
            string monitor_tooltip = (_("Target monitor, default is on active monitor"));
            string workspace_tooltip = (_("Target workspace, default is on active workspace"));
            get_task = new Dialog();
            var contentarea = get_task.get_content_area();
            contentarea.orientation = Gtk.Orientation.VERTICAL;
            // mastergrid
            Grid master_grid = new Gtk.Grid();
            set_margins(master_grid, 30, 30, 30, 30);
            contentarea.pack_start(master_grid, false, false, 0);
            // 1. APPLICATION FRAME
            Frame applicationframe = new Gtk.Frame((_("Application")));
            var app_label = applicationframe.get_label_widget();
            set_widgetstyle(app_label, "justbold");
            // application grid
            Grid applicationgrid = new Gtk.Grid();
            set_margins(applicationgrid, 20, 20, 20, 20);
            applicationgrid.set_row_spacing(4);
            // - wmclass
            Label wmclass_label = makelabel((_("WM class group*")), 0);
            Entry wmclass_entry = new Entry();
            wmclass_entry.changed.connect(()=> {
                set_widgetstyle(wmclass_entry, "red_text", true);
                wmclass_changed = false;
                if (initial_wm != null &&
                    initial_wm != wmclass_entry.get_text()) {
                    wmclass_changed = true;
                }
            });
            wmclass_entry.set_tooltip_text(class_tooltip);
            wmclass_entry.set_text("");
            wmclass_entry.set_size_request(250, 10);
            wmclass_entry.set_placeholder_text((_("Click a window to fetch")));
            applicationgrid.attach(wmclass_label, 1, 4, 1, 1);
            applicationgrid.attach(new Label("\t\t"), 2, 4, 1, 1);
            applicationgrid.attach(wmclass_entry, 3, 4, 20, 1);
            applicationframe.add(applicationgrid);
            master_grid.attach(applicationframe, 1, 10, 10, 1);
            master_grid.attach(new Label(""), 1, 20, 1, 1);
            //  2. GEOMETRY FRAME
            Frame geometryframe = new Gtk.Frame((_("Window position & size")));
            var geo_label = geometryframe.get_label_widget();
            set_widgetstyle(geo_label, "justbold");
            master_grid.attach(geometryframe, 1, 30, 10, 1);
            // geometry grid
            Grid geogrid = new Gtk.Grid();
            set_margins(geogrid, 20, 20, 20, 20);
            geogrid.set_row_spacing(0);
            // grid cols / rows
            Label grid_size_label = makelabel((_("Grid size; columns & rows")), 0);
            geogrid.attach(grid_size_label, 1, 10, 1, 1);
            geogrid.attach(new Label("\t"), 2, 10, 1, 1);
            // get current gridsize
             OwnSpinButton grid_xsize_spin = new OwnSpinButton("hor", "", 1, 10);
            grid_xsize_spin.set_value(shufflersettings.get_int("cols"));
            grid_xsize_spin.set_tooltip_text(gridxsize_tooltip);
            OwnSpinButton grid_ysize_spin = new OwnSpinButton("vert", "", 1, 10);
            grid_ysize_spin.set_value(shufflersettings.get_int("rows"));
            grid_ysize_spin.set_tooltip_text(gridysize_tooltip);
            Box gridsize_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            gridsize_box.pack_start(grid_xsize_spin, false, false, 0);
            gridsize_box.pack_start(new Label("\t"), false, false, 0);
            gridsize_box.pack_start(grid_ysize_spin, false, false, 0);
            geogrid.attach(gridsize_box, 3, 10, 1, 1);
            geogrid.attach(new Label(""), 1, 11, 1, 1);
            // window position
            Label winpos_label = makelabel((_("Target window position, x / y")), 0);
            geogrid.attach(winpos_label, 1, 12, 1, 1);
            geogrid.attach(new Label("\t"), 2, 12, 1, 1);
            OwnSpinButton xpos_spin = new OwnSpinButton("hor", "", 0, 10);
            xpos_spin.set_tooltip_text(targetpositionx_tooltip);
            xpos_spin.set_value(0);
            OwnSpinButton ypos_spin = new OwnSpinButton("vert", "", 0, 10);
            ypos_spin.set_tooltip_text(targetpositiony_tooltip);
            ypos_spin.set_value(0);
            Box winpos_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            winpos_box.pack_start(xpos_spin, false, false, 0);
            winpos_box.pack_start(new Label("\t"), false, false, 0);
            winpos_box.pack_start(ypos_spin, false, false, 0);
            geogrid.attach(winpos_box, 3, 12, 1, 1);
            geogrid.attach(new Label(""), 1, 13, 1, 1);
            // window span
            Label cellspan_label = makelabel((_("Window cell span, hor / vert")),0);
            geogrid.attach(cellspan_label, 1, 14, 1, 1);
            geogrid.attach(new Label("\t"), 2, 14, 1, 1);
            OwnSpinButton yspan_spin = new OwnSpinButton("vert", "", 1, 10);
            yspan_spin.set_tooltip_text(yspan_tooltip);
            yspan_spin.set_value(1);
            OwnSpinButton xspan_spin = new OwnSpinButton("hor", "", 1, 10);
            xspan_spin.set_tooltip_text(xspan_tooltip);
            xspan_spin.set_value(1);
            Box winspan_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            winspan_box.pack_start(xspan_spin, false, false, 0);
            winspan_box.pack_start(new Label("\t"), false, false, 0);
            winspan_box.pack_start(yspan_spin, false, false, 0);
            geogrid.attach(winspan_box, 3, 14, 1, 1);
            geogrid.attach(new Label(""), 1, 13, 1, 1);
            geometryframe.add(geogrid);
            master_grid.attach(new Label(""), 1, 31, 1, 1);
            Gtk.Frame miscframe = new Gtk.Frame((_("Miscellaneous")));
            var misc_label = miscframe.get_label_widget();
            set_widgetstyle(misc_label, "justbold");
            master_grid.attach(miscframe, 1, 50, 10, 1);
            Grid miscgrid = new Gtk.Grid();
            set_margins(miscgrid, 20, 20, 20, 20);
            miscgrid.set_row_spacing(4);
            miscframe.add(miscgrid);
            allspins = {
                grid_xsize_spin, grid_ysize_spin, xpos_spin,
                ypos_spin, xspan_spin, yspan_spin
            };
            // target monitor
            Label targetmonitor_label = new Label((_("Target monitor")));
            targetmonitor_label.xalign = 0;
            miscgrid.attach(targetmonitor_label, 1, 1, 1, 1);
            ComboBoxText screendropdown = new ComboBoxText();
            screendropdown.set_tooltip_text(monitor_tooltip);
            screendropdown.append_text(default_set);
            screendropdown.active = 0;
            string[] mons = {default_set};
            foreach (string m in get_monitornames()) {
                screendropdown.append_text(m);
                mons += m;
            }
            miscgrid.attach(new Label("\t"), 2, 1, 1, 1);
            miscgrid.attach(screendropdown, 3, 1, 1, 1);
            master_grid.attach(new Label(""), 1, 109, 1, 1);
            // target workspace
            Label targetworkspace_label = new Label((_("Target workspace")));
            targetworkspace_label.xalign = 0;
            miscgrid.attach(targetworkspace_label, 1, 2, 1, 1);
            ComboBoxText workspacedropdown = new ComboBoxText();
            workspacedropdown.set_tooltip_text(workspace_tooltip);
            int nspaces = 1;
            string[] allspaces = {default_set};
            workspacedropdown.append_text(default_set);
            workspacedropdown.active = 0;
            try {
                // populate workspace-dropdown & list
                nspaces = client.get_numberof_workspaces();
                for (int i=0;i<nspaces; i++) {
                    int readable_space = i + 1;
                    allspaces += @"$readable_space";
                    workspacedropdown.append_text(@"$readable_space");
                }
            }
            catch (Error e) {
                stderr.printf ("Error: %s\n", e.message);
            }
            miscgrid.attach(new Label("\t"), 2, 2, 1, 1);
            miscgrid.attach(workspacedropdown, 3, 2, 1, 1);
            master_grid.attach(new Label(""), 1, 109, 1, 1);
            // Done button
            Gtk.Box dialogaction_box = new Gtk.Box(
                Gtk.Orientation.HORIZONTAL, 0
            );
            applytask_button = new Gtk.Button();
            applytask_button.label = (_("Done"));
            applytask_button.set_size_request(90, 10);
            applytask_button.clicked.connect(()=> {
                string tocompare = makecheckstring(
                    wmclass_entry, allspins, screendropdown, workspacedropdown
                );
                bool anythingchanged = tocompare != check_changes; /////////////////////////////////////////////////////////////////////////////////////
                print(@"changed? $anythingchanged\n");
                if (anythingchanged) {
                    if (apply_newrule(
                        wmclass_entry, grid_xsize_spin, grid_ysize_spin,
                        xpos_spin, ypos_spin, xspan_spin, yspan_spin,
                        screendropdown, workspacedropdown, update,
                        wmclass_changed
                    ) && wmclass_changed) {
                        /*
                        when updating, we need to keep in mind the possibility
                        of an updated wmclass name -> remove old named file
                        only if wmclass was edited
                        */
                        try {
                            File remove_oldname = File.new_for_path(
                                windowrule_location.concat(@"/$wmclass.windowrule")
                            );
                                remove_oldname.delete();
                        }
                        catch (Error e) {
                            stderr.printf ("Error: %s\n", e.message);
                        }
                    }
                }
                else {
                    get_task.destroy();
                }
            });
            Button canceltask_button = new Gtk.Button();
            canceltask_button.label = (_("Cancel"));
            canceltask_button.set_size_request(90, 10);
            canceltask_button.clicked.connect(()=> {
                get_task.destroy();
            });
            dialogaction_box.pack_end(applytask_button, false, false, 2);
            dialogaction_box.pack_end(canceltask_button, false, false, 2);
            master_grid.attach(dialogaction_box, 1, 110, 10, 1); //
            get_task.set_transient_for(this);
            get_task.decorated = false;
            contentarea.show_all();
            foreach (OwnSpinButton spin in allspins) {
                spin.spinvalue.changed.connect(()=> {
                    set_spincolor(allspins);
                });
            };
            wnck_scr.active_window_changed.connect(()=> {
                if (wmclass_entry.is_focus && initial_change == false) {
                    Wnck.Window? newactive = wnck_scr.get_active_window();
                    if (newactive != null) {
                        Wnck.WindowType wtype = newactive.get_window_type();
                        string classname = newactive.get_class_group_name().down();
                        if (
                            classname != "new_shuffler_control" &&
                            wtype == Wnck.WindowType.NORMAL
                        ) {
                            wmclass_entry.set_text(classname);
                        }
                    }
                    makesure_offocus();
                };
                initial_change = false;
            });
            if (update) {
                wmclass_entry.set_text(wmclass);
                foreach (string k in foundrules.get_keys()) {
                    if (k == wmclass) {
                        // lookup values, set widgets
                        Variant match = foundrules[k];
                        string set_monitor = (string)match.get_child_value(0);
                        int xpos = int.parse((string)match.get_child_value(1));
                        int ypos = int.parse((string)match.get_child_value(2));
                        int grid_ysize = int.parse((string)match.get_child_value(3));
                        int grid_xsize = int.parse((string)match.get_child_value(4));
                        int xspan = int.parse((string)match.get_child_value(5));
                        int yspan = int.parse((string)match.get_child_value(6));
                        string set_workspace = (string)match.get_child_value(7);
                        // lazy check; instead of checking all fields separately, create a string of all
                        //  check_changes = @"$k$set_monitor$grid_xsize$grid_ysize$xpos$ypos$xspan$yspan"; /////////////////////////////////////////////////////////////
                        xpos_spin.set_value(xpos);
                        ypos_spin.set_value(ypos);
                        grid_ysize_spin.set_value(grid_ysize);
                        grid_xsize_spin.set_value(grid_xsize);
                        xspan_spin.set_value(xspan);
                        yspan_spin.set_value(yspan);
                        int foundmonindex = string_inlist(set_monitor, mons);
                        screendropdown.active = foundmonindex;
                        string readable_workspace = get_value_forrule(set_workspace);
                        int foundwsindex = string_inlist(readable_workspace, allspaces);
                        if (foundwsindex == -1) {
                            // if a workspace outside range is set, keep it!
                            allspaces += readable_workspace;
                            workspacedropdown.append_text(readable_workspace);
                            // renew index
                            foundwsindex = string_inlist(readable_workspace, allspaces);
                            print(@"foundwsindex: $foundwsindex\n");
                            //  workspacedropdown.active = foundwsindex;
                        }
                        workspacedropdown.active = foundwsindex;
                        check_changes = @"$k$set_monitor$readable_workspace$grid_xsize$grid_ysize$xpos$ypos$xspan$yspan"; /////////////////////////////////////////////////////////////
                    }
                }
            }
            get_task.run();
        }

        private string makecheckstring(
            Gtk.Entry wmclass, OwnSpinButton[] allspins,
            ComboBoxText screendropdown, ComboBoxText workspacedropdown
        ) {
            string valuestring = wmclass.get_text().concat(
                screendropdown.get_active_text().concat(workspacedropdown.get_active_text())
            );
            foreach (OwnSpinButton sp in allspins) {
                valuestring += sp.get_value().to_string();
            }
            return valuestring;

        }

        private uint get_now() {
            // get timestamp
            return Gdk.X11.get_server_time(timestamp_window);
        }

        private void makesure_offocus () {
            foreach (Wnck.Window w in wnck_scr.get_windows()) {
                if (w.get_name().down() == (_("Window Shuffler Controls"))) {
                    w.activate(get_now());
                    break;
                }
                else if (w.get_name() == "new_shuffler_control") {
                    w.activate(get_now());
                }
            }
        }

        private bool apply_newrule(
            Entry e, OwnSpinButton x, OwnSpinButton y, OwnSpinButton xpos,
            OwnSpinButton ypos, OwnSpinButton xspan, OwnSpinButton yspan,
            ComboBoxText dropdown, ComboBoxText wsdropdown, bool update,
            bool wmclass_changed
        ) {
            /*
            only ask for confirmation if
            - an existing file changed
            - a new file will overwrite an existing file
            */
            // defaults:
            bool apply = true;
            string monitorline = "";
            string workspaceline = "";
            string warninghead = (_("Replace window-rule")); // when creating new file, but name exists
            if (update) {
                warninghead = (_("Save changes to window-rule")); // when just updating
            }
            string classname = e.get_text();
            // 1. let's first check if input classname is correct
            if (classname == "") {
                apply = false;
                set_widgetstyle(e, "red_text");
            }
            // 2. if so, if wm entry, thus filename changes:
            else if (wmclass_changed) {
                warninghead = (_("Save changes to renamed window-rule"));
                apply = ask_confirm(@"$warninghead: $classname?");
            }
            // 3. if file is "only" updated:
            else {
                foreach (string k in foundrules.get_keys()) {
                    if (e.get_text() == k) {
                        apply = ask_confirm(
                            @"$warninghead: $classname?"
                        );
                        break;
                    }
                }
            }
            int cols = x.get_value();
            int rows = y.get_value();
            int xposval = xpos.get_value();
            int yposval = ypos.get_value();
            int xspanval = xspan.get_value();
            int yspanval = yspan.get_value();
            string? disp = dropdown.get_active_text();
            /////////////////////////////////////////////////////////////
            //add get-from-workspacedropdown here
            workspaceline = "";
            //  string? ws = wsdropdown.get_active_text();
            string ws = get_value_forrule(wsdropdown.get_active_text(), true);
            if (ws != "") {
                workspaceline = @"\nTargetWorkspace=$ws";
            }
            /////////////////////////////////////////////////////////////
            if (disp != null) {
                monitorline = @"\nMonitor=$disp";
            }
            string filecontent =  @"Cols=$cols".concat(
                @"\nRows=$rows", @"\nXPosition=$xposval",
                @"\nYPosition=$yposval",@"\nXSpan=$xspanval",
                @"\nYSpan=$yspanval", monitorline, workspaceline
            );
            if (apply) {
                write_edit(filecontent, classname);
                get_task.destroy();
                return true;
            }
            get_task.destroy();
            return false;
        }

        private void write_edit(string filecontent, string classname) {
            string filepath = windowrule_location.concat(
                @"/$classname.windowrule"
            );
            try {
                File targetfile = File.new_for_path(filepath);
                if (targetfile.query_exists ()) {
                    // ask for replace permission first
                    targetfile.delete();
                }
                // Create a new file with this name
                var file_stream = targetfile.create (
                    FileCreateFlags.REPLACE_DESTINATION
                );
                var data_stream = new DataOutputStream (file_stream);
                data_stream.put_string (filecontent);
            }
            catch (Error e) {
                stderr.printf ("Error: %s\n", e.message);
            }
        }

        private void set_spincolor(OwnSpinButton[] spins) {
            var xsize = spins[0];
            var ysize = spins[1];
            var xpos = spins[2];
            var ypos = spins[3];
            var xspan = spins[4];
            var yspan = spins[5];
            OwnSpinButton[] xes = {xsize, xpos, xspan};
            OwnSpinButton[] yses = {ysize, ypos, yspan};
            bool xred = xsize.get_value() < (xpos.get_value() + xspan.get_value());
            bool yred = ysize.get_value() < (ypos.get_value() + yspan.get_value());
            foreach (OwnSpinButton spbx in xes) {
                spbx.set_warning_color(xred);
            }
            foreach (OwnSpinButton spby in yses) {
                spby.set_warning_color(yred);
            }
            bool sens = !(xred || yred);
            applytask_button.set_sensitive(sens);
        }

        private string create_dirs_file (string subpath) {
            // defines, and if needed, creates directory for rules
            string homedir = Environment.get_home_dir();
            string fullpath = GLib.Path.build_path(
                GLib.Path.DIR_SEPARATOR_S, homedir, subpath
            );
            GLib.File file = GLib.File.new_for_path(fullpath);
            try {
                file.make_directory_with_parents();
            }
            catch (Error e) {
                /* the directory exists, nothing to be done */
            }
            return fullpath;
        }

        private void update_currentrules() {
            foreach (Widget w in newrulesgrid.get_children()) {
                w.destroy();
            }
            // update ruleslist
            newrulesgrid.set_column_spacing(15);
            // headers
            string[] rules_columnheaders = {
                "WM-class", (_("Grid")), "X, Y", (_("Span")), (_("Display")), (_("Workspace"))
            };
            int col = 0;
            foreach (string s in rules_columnheaders) {
                Label newheader = new Label(s);
                if (col == 0) {
                    newheader.set_size_request(120, 10);
                    newheader.xalign = 0;
                }
                newheader.get_style_context().add_class("justbold");
                newrulesgrid.attach(newheader, col, 0, 1, 1);
                col += 1;
            }

            int currow = 1;
            try {
                client = Bus.get_proxy_sync (
                    BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                    ("/org/ubuntubudgie/shufflerinfodaemon")
                );
                foundrules = client.get_rules();
                GLib.List<weak string> keys = foundrules.get_keys();
                foreach (string k in keys) {
                    Gtk.Button taskeditbutton = new Button.from_icon_name(
                        "document-edit-symbolic", Gtk.IconSize.BUTTON
                    );
                    Gtk.Button taskdeletebutton = new Button.from_icon_name(
                        "user-trash-symbolic", Gtk.IconSize.BUTTON
                    );
                    taskdeletebutton.set_size_request(10, 10);
                    taskdeletebutton.set_relief(Gtk.ReliefStyle.NONE);
                    taskeditbutton.set_size_request(10, 10);
                    taskeditbutton.set_relief(Gtk.ReliefStyle.NONE);
                    taskeditbutton.clicked.connect(()=> {
                        call_dialog(k);
                    });
                    Variant windowrule = foundrules[k];
                    string monitor = (string)windowrule.get_child_value(0);
                    string xposition = (string)windowrule.get_child_value(1);
                    string yposition = (string)windowrule.get_child_value(2);
                    string rows = (string)windowrule.get_child_value(3);
                    string cols = (string)windowrule.get_child_value(4);
                    string xspan = (string)windowrule.get_child_value(5);
                    string yspan = (string)windowrule.get_child_value(6);
                    string ws = get_value_forrule(
                        (string)windowrule.get_child_value(7)
                    );
                    Label newlabel = makelabel(k, 0);
                    Label newgridsize = new Label(cols + "x" + rows);
                    Label newposition = new Label(xposition + ", " + yposition);
                    Label newspan = new Label(xspan + "x" + yspan);
                    Label newmonitor = new Label(monitor);
                    Label newworkspace = new Label(ws);
                    newrulesgrid.attach(newlabel, 0, currow, 1, 1);
                    newrulesgrid.attach(newgridsize, 1, currow, 1, 1);
                    newrulesgrid.attach(newposition, 2, currow, 1, 1);
                    newrulesgrid.attach(newspan, 3, currow, 1, 1);
                    newrulesgrid.attach(newmonitor, 4, currow, 1, 1);
                    newrulesgrid.attach(newworkspace, 5, currow, 1, 1);
                    newrulesgrid.attach(new Label(" "), 6, currow, 1, 1);
                    newrulesgrid.attach(taskeditbutton, 7, currow, 1, 1);
                    newrulesgrid.attach(taskdeletebutton, 8, currow, 1, 1);
                    string filepath = windowrule_location.concat(
                        @"/$k.windowrule"
                    );
                    taskdeletebutton.clicked.connect(()=> {
                        string del = (_("Delete"));
                        string wrule = (_("windowrule"));
                        if (ask_confirm(@"$del $wrule $k?")) {
                            File targetfile = File.new_for_path(filepath);
                            try {
                                targetfile.delete();
                            }
                            catch (Error e) {
                                stderr.printf ("%s\n", e.message);
                            }
                        }
                    });
                    currow += 1;
                }
                newrulesgrid.show_all();
                rulesgrid.show_all();
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private void add_series_toggrid(
            Grid grid, string[] leftitems, string[] rightitems,
            int startint = 0) {
            // just an optimizasition to add arrays of items to a grid
            for (int i = 0; i < leftitems.length; i++) {
                Label newlabel = makelabel(leftitems[i], 0);
                grid.attach(newlabel, 0, i + startint, 1, 1);
                grid.attach(new Label("\t\t"), 1, i + startint, 1, 1);
                Label newshortcut = makelabel(rightitems[i], 0);
                grid.attach(newshortcut, 2, i + startint, 1, 1);
            }
        }

        public ShufflerControlsWindow() {
            setup_client();
            initialiseLocaleLanguageSupport();
            wnck_scr = Wnck.Screen.get_default();
            // window stuff
            this.title = (_("Window Shuffler Controls"));
            //  this.default_width = 800;
            this.set_resizable(false);
            // watch rulesdir
            windowrule_location = create_dirs_file(
                ".config/budgie-extras/shuffler/windowrules"
            );
            try {
                File rulesdir = File.new_for_path(windowrule_location);
                monitor_ruleschange = rulesdir.monitor(FileMonitorFlags.NONE, null);
                monitor_ruleschange.changed.connect(()=> {
                    // prevent Dbus error
                    if (shufflersettings.get_boolean("runshuffler")) {
                        update_currentrules();
                    }
                });
            }
            catch (Error e) {
            }
            // settings
            shufflersettings = new GLib.Settings("org.ubuntubudgie.windowshuffler");
            var tilingicon = new Gtk.Image.from_icon_name(
                "shuffler-tilingicon-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            var layoutsicon = new Gtk.Image.from_icon_name(
                "shuffler-layouticon-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            var rulesicon = new Gtk.Image.from_icon_name(
                "shuffler-rulesicon-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            var generalprefs = new Gtk.Image.from_icon_name(
                "shuffler-miscellaneousprefs-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            // css stuff
            Gdk.Screen gdk_scr = this.get_screen();
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(controls_css);
                Gtk.StyleContext.add_provider_for_screen(
                    gdk_scr, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }
            this.destroy.connect(()=> {
                Gtk.main_quit();
            });
            Grid maingrid = new Gtk.Grid();
            // Listbox section
            ListBox listbox = new Gtk.ListBox();
            Frame listboxframe = new Gtk.Frame(null);
            listboxframe.get_style_context().add_class("somebox");
            listboxframe.add(listbox);
            maingrid.attach(listboxframe, 1, 1, 1, 1);
            listbox.set_size_request(170, 450);
            // content
            Label title1 = makelabel((_("Tiling")), 0);
            string title1_hint =  (_("Window tiling & shortcuts"));
            Label title2 = makelabel((_("Layouts")), 0);
            string title2_hint = (_("Automatic window & application presets"));
            Label title3 = makelabel((_("Window rules")),0);
            string title3_hint = (_("Define where application windows should be opened"));
            Label title4 = makelabel((_("Miscellaneous")), 0);
            string title4_hint = (_("General preferences"));
            listbox.insert(get_rowgrid(title1, tilingicon, title1_hint), 1);
            listbox.insert(get_rowgrid(title2, layoutsicon, title2_hint), 2);
            listbox.insert(get_rowgrid(title3, rulesicon, title3_hint), 3);
            listbox.insert(get_rowgrid(title4, generalprefs,title4_hint), 4);
            // stack
            allsettings_stack = new Gtk.Stack();
            maingrid.attach(allsettings_stack, 2, 1, 1, 1);
            allsettings_stack.set_transition_type(
                StackTransitionType.OVER_UP_DOWN
            );
            // TILING PAGE
            tilinggrid = new Gtk.Grid();
            tilinggrid.set_row_spacing(10);
            set_margins(tilinggrid, 30, 30, 30, 30);
            // header + switch (in subgrid)
            Grid switchgrid_basicshortcuts = new Gtk.Grid();
            Label basicshortcutsheader = makelabel(
                (_("Basic quarter & half tiling")), 0, "justbold"
            );
            switchgrid_basicshortcuts.attach(
                basicshortcutsheader, 0, 0, 1, 1
            );
            switchgrid_basicshortcuts.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_basictilingswitch = new Gtk.Switch();
            switchgrid_basicshortcuts.attach(
                enable_basictilingswitch, 2, 0, 1, 1
            );
            tilinggrid.attach(switchgrid_basicshortcuts, 0, 0, 10, 1);
            // basic shortcutlist (in subgrid)
            Grid basicshortcutlist_subgrid = new Gtk.Grid();
            // translations!
            string[] basics = {
                (_("Top-left")), (_("Top-right")), (_("Bottom-right")),
                (_("Bottom-left")), (_("Left-half")), (_("Top-half")),
                (_("Right-half")), (_("Bottom-half")), (_("Toggle maximize"))
            };
            string[] basicshortcuts = {
                "Ctrl + Alt + 7", "Ctrl + Alt + 9", "Ctrl + Alt + 3",
                "Ctrl + Alt + 1", "Ctrl + Alt + 4", "Ctrl + Alt + 8",
                "Ctrl + Alt + 6", "Ctrl + Alt + 2", "Ctrl + Alt + 5"
            };
            add_series_toggrid(
                basicshortcutlist_subgrid, basics, basicshortcuts
            );
            tilinggrid.attach(basicshortcutlist_subgrid, 0, 1, 10, 1);
            basicshortcutlist_subgrid.show_all();
            tilinggrid.attach(new Label(""), 1, 2, 1, 1);
            // custom size header + switch (in subgrid)
            Grid switchgrid_advancedshortcuts = new Gtk.Grid();
            Label advancedcutsheader = makelabel(
                (_("Resizing & moving windows in a custom grid")), 0, "justbold"
            );
            switchgrid_advancedshortcuts.attach(
                advancedcutsheader, 0, 0, 1, 1
            );
            switchgrid_advancedshortcuts.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_advancedtilingswitch = new Gtk.Switch();
            switchgrid_advancedshortcuts.attach(
                enable_advancedtilingswitch, 2, 0, 1, 1
            );
            tilinggrid.attach(switchgrid_advancedshortcuts, 0, 15, 10, 1);
            Label customgridsettings_label = makelabel((_("Grid size")) + ":", 0, "justitalic");
            tilinggrid.attach(customgridsettings_label, 0, 16, 10, 1);
            Grid gridsizegrid = new Gtk.Grid();
            Label gridsize_cols_label = makelabel((_("Columns")), 0);
            gridsizegrid.attach(gridsize_cols_label, 0, 0, 1, 1);
            gridsizegrid.attach(new Label(" "), 1, 0, 1, 1);
            OwnSpinButton grid_horsize = new OwnSpinButton(
                "hor", "cols", 0, 10
            );
            gridsizegrid.attach(grid_horsize, 2, 0, 1, 1);
            gridsizegrid.attach(new Label("\t"), 3, 0, 1, 1);
            Label grid_vertsize_label = makelabel((_("Rows")), 0);
            gridsizegrid.attach(grid_vertsize_label, 4, 0, 1, 1);
            gridsizegrid.attach(new Label(" "), 5, 0, 1, 1);
            OwnSpinButton grid_vertsize = new OwnSpinButton(
                "vert", "rows", 0, 10
            );
            gridsizegrid.attach(grid_vertsize, 6, 0, 1, 1);
            tilinggrid.attach(gridsizegrid, 0, 17, 10, 1);
            // options
            Label options_label = makelabel((_("Options")) + ":", 0, "justitalic");
            tilinggrid.attach(options_label, 0, 18, 10, 1);
            Grid optionsgrid = new Grid();
            // sticky
            Label stickylabel = makelabel((_("Resize opposite window")), 0);
            optionsgrid.attach(stickylabel, 0, 0, 1, 1);
            optionsgrid.attach(new Label("\t"), 1, 0, 1, 1);
            CheckButton toggle_sticky = new CheckButton();
            optionsgrid.attach(toggle_sticky, 2, 0, 1, 1);
            // swap
            Label swaplabel = makelabel((_("Swap windows")), 0);
            optionsgrid.attach(swaplabel, 0, 1, 1, 1);
            optionsgrid.attach(new Label("\t"), 1, 1, 1, 1);
            CheckButton toggle_swap = new CheckButton();
            optionsgrid.attach(toggle_swap, 2, 1, 1, 1);
            // notification
            Label notificationlabel = makelabel(
                (_("Show notification on incorrect window size")), 0
            );
            optionsgrid.attach(notificationlabel, 0, 2, 1, 1);
            optionsgrid.attach(new Label("\t"), 1, 2, 1, 1);
            CheckButton toggle_notification = new CheckButton();
            optionsgrid.attach(toggle_notification, 2, 2, 1, 1);
            // guigrid
            Label useguigridlabel = makelabel((_("Enable GUI grid")), 0);
            optionsgrid.attach(useguigridlabel, 0, 3, 1, 1);
            optionsgrid.attach(new Label("\t"), 1, 3, 1, 1);
            toggle_guigrid = new CheckButton();
            optionsgrid.attach(toggle_guigrid, 2, 3, 1, 1);
            tilinggrid.attach(optionsgrid, 0, 19, 10, 1);
            Label guishortcutsheader = makelabel((_("GUI grid shortcuts")) + ":", 0, "justitalic");
            tilinggrid.attach(guishortcutsheader, 0, 20, 10, 1);
            Grid guishortcuts_subgrid = new Grid();
            string[] guis = {
                (_("Toggle GUI grid")), (_("Add a column")),
                (_("Add a row")), (_("Remove column")), (_("Remove row")),
            };
            string[] guishortcuts = {
                "Ctrl + Alt + S", "→", "↓", "←", "↑"
            };
            add_series_toggrid(guishortcuts_subgrid, guis, guishortcuts);
            tilinggrid.attach(guishortcuts_subgrid, 0, 21, 10, 1);
            // shortcutlist custom grid
            Label jump_header_label = makelabel(
                (_("Shortcuts for moving a window to the nearest grid cell")) + ":", 0, "justitalic"
            );
            tilinggrid.attach(jump_header_label, 0, 26, 10, 1);
            Grid advancedshortcutlist_subgrid = new Gtk.Grid();
            string[] movers = {
                (_("Move left")), (_("Move right")), (_("Move up")), (_("Move down"))
            };
            string[] movershortcuts = {
                "Super + Alt + ←", "Super + Alt + →",
                "Super + Alt + ↑", "Super + Alt + ↓"
            };
            add_series_toggrid(
                advancedshortcutlist_subgrid, movers, movershortcuts
            );
            tilinggrid.attach(advancedshortcutlist_subgrid, 0, 27, 10, 1);
            string resize_header = (_("Shortcuts for resizing a window")) + ":";
            Label resize_header_label = makelabel(resize_header, 0, "justitalic");
            Grid workarounspace_1 = new Grid();
            workarounspace_1.attach(resize_header_label, 0, 0, 1, 1);
            set_margins(workarounspace_1, 0, 10, 10, 10);
            advancedshortcutlist_subgrid.attach(
                workarounspace_1, 0, 6, 10, 1
            );
            string[] resizers = {
                (_("Expand horizontally (to the right)")),
                (_("Shrink horizontally (from the right)")),
                (_("Expand vertically (down)")),
                (_("Shrink vertically (from the bottom)")),
                (_("Expand horizontally (to the left)")),
                (_("Shrink horizontally (from the left)")),
                (_("Expand vertically (up)")),
                (_("Shrink vertically (from the top)")),
                (_("Toggle resizing opposite window"))
            };
            string[] resizershortcuts = {
                "Control + Super + →", "Control + Super + ←",
                "Control + Super + ↓", "Control + Super + ↑",
                "Control + Super + Alt + ←", "Control + Super + Alt + →",
                "Control + Super + Alt + ↑", "Control + Super + Alt + ↓",
                "Control + Super + N"
            };
            add_series_toggrid(
                advancedshortcutlist_subgrid, resizers, resizershortcuts, 8
            );
            Label other_header_label = makelabel((_("Other")) + ":", 0, "justitalic");
            Grid workarounspace_2 = new Grid();
            workarounspace_2.attach(other_header_label, 0, 0, 1, 1);
            set_margins(workarounspace_2, 0, 0, 10, 10);
            advancedshortcutlist_subgrid.attach(
                workarounspace_2, 0, 21, 10, 1
            );
            Label tileall_label = makelabel((_("Tile all windows to grid")), 0);
            advancedshortcutlist_subgrid.attach(tileall_label, 0, 23, 1, 1);
            advancedshortcutlist_subgrid.attach(
                new Label("\t\t"), 1, 23, 1, 1
            );
            Label tileall_shortcut = makelabel("Control + Super + A", 0);
            advancedshortcutlist_subgrid.attach(
                tileall_shortcut, 2, 23, 1, 1
            );
            Label toggle_opposite_label = makelabel(
                (_("Toggle resizing opposite window")), 0
            );
            advancedshortcutlist_subgrid.attach(
                toggle_opposite_label, 0, 24, 1, 1
            );
            advancedshortcutlist_subgrid.attach(
                new Label("\t\t"), 1, 24, 1, 1
            );
            Label toggle_opposite_shortcut = makelabel("Control + Super + N", 0);
            advancedshortcutlist_subgrid.attach(
                toggle_opposite_shortcut, 2, 24, 1, 1
            );
            Widget[] checkswitch = {
                optionsgrid, gridsizegrid, customgridsettings_label,
                options_label, guishortcutsheader, guishortcuts_subgrid,
                jump_header_label, advancedshortcutlist_subgrid,
                resize_header_label, other_header_label, tileall_label,
                tileall_shortcut, toggle_opposite_label,
                toggle_opposite_shortcut
            };
            set_widget_sensitive(checkswitch, "customgridtiling");
            shufflersettings.changed["customgridtiling"].connect(()=>{
                set_widget_sensitive(checkswitch, "customgridtiling");
                manage_daemon();
            });
            advancedshortcutlist_subgrid.show_all();
            tilinggrid.attach(new Label(""), 1, 49, 1, 1);
            ScrolledWindow scrolled_tiling = new ScrolledWindow(null, null);
            scrolled_tiling.set_min_content_width(620);
            scrolled_tiling.add(tilinggrid);
            scrolled_tiling.set_propagate_natural_width(true);
            allsettings_stack.add_named(scrolled_tiling, "tiling");
            // LAYOUTS PAGE
            layoutsgrid = new Gtk.Grid();
            layoutsgrid.set_row_spacing(20);
            set_margins(layoutsgrid, 30, 30, 30, 30);
            // optimize please with similar grids
            Grid switchgrid_layouts = new Gtk.Grid();
            Label layoutssheader = makelabel((_("Layouts")), 0, "justbold");
            switchgrid_layouts.attach(layoutssheader, 0, 0, 1, 1);
            switchgrid_layouts.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_layouts = new Gtk.Switch();
            switchgrid_layouts.attach(enable_layouts, 2, 0, 1, 1);
            layoutsgrid.attach(switchgrid_layouts, 0, 0, 10, 1);
            Grid layoutshortcutgrid = new Grid();
            Label layoutshortcutlabel = makelabel(
                (_("Toggle layouts quicklist & manager")), 0
            );
            layoutshortcutgrid.attach(layoutshortcutlabel, 0, 0, 1, 1);
            layoutshortcutgrid.attach(new Label("\t"), 1, 0, 1, 1);
            layoutshortcutgrid.attach(
                new Label("Super + Alt + L"), 2, 0, 1, 1
            );
            layoutsgrid.attach(layoutshortcutgrid, 0, 1, 10, 10);
            layoutsgrid.attach(new Label(""), 0, 2, 1, 1);
            Button manage_layoutsbutton = new Gtk.Button();
            manage_layoutsbutton.label = (_("Setup now"));
            manage_layoutsbutton.clicked.connect(()=> {
                string layoutsetup_path = Config.SHUFFLER_DIR + "/toggle_layouts_popup";
                try {
                    Process.spawn_command_line_sync(layoutsetup_path);
                }
                catch (Error e) {
                }
            });
            layoutsgrid.attach(manage_layoutsbutton, 0, 3, 1, 1);
            allsettings_stack.add_named(layoutsgrid, "layouts");
            Widget[] layotwidgets = {manage_layoutsbutton, layoutshortcutgrid};
            shufflersettings.changed["runlayouts"].connect(()=> {
                set_widget_sensitive(layotwidgets, "runlayouts");
                manage_daemon();
            });
            set_widget_sensitive(layotwidgets, "runlayouts");
            // RULES PAGE
            rulesgrid = new Gtk.Grid();
            rulesgrid.set_row_spacing(20);
            set_margins(rulesgrid, 30, 30, 30, 30);
            // optimize please with similar grids
            Grid switchgrid_rules = new Gtk.Grid();
            Label rulessheader = makelabel(
                (_("Window rules")), 0, "justbold"
            );
            switchgrid_rules.attach(rulessheader, 0, 0, 1, 1);
            switchgrid_rules.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_rules = new Gtk.Switch();
            switchgrid_rules.attach(enable_rules, 2, 0, 1, 1);
            rulesgrid.attach(switchgrid_rules, 0, 0, 10, 1);
            rulesgrid.attach(new Label(""), 0, 1, 10, 1);
            Label activerules = makelabel(
                (_("Stored rules")) + ":", 0, "justitalic"
            );
            rulesgrid.attach(activerules, 0, 2, 10, 1);
            newrulesgrid = new Grid();
            rulesgrid.attach(newrulesgrid, 0, 10, 10, 1);
            ScrolledWindow scrolled_rules = new ScrolledWindow(null, null);
            scrolled_rules.set_min_content_width(620);
            scrolled_rules.add(rulesgrid);
            scrolled_rules.set_propagate_natural_width(true);
            Gtk.Button newrulebutton = new Button();
            newrulebutton.label = (_("Add new rule"));
            newrulebutton.set_size_request(1,1);
            newrulebutton.clicked.connect(()=> {
                call_dialog();
            });
            rulesgrid.attach(newrulebutton, 0, 21, 1, 1);
            allsettings_stack.add_named(scrolled_rules, "rules");
            Widget[] ruleswidgets = {
                newrulesgrid, newrulebutton, activerules
            };
            set_widget_sensitive(ruleswidgets, "windowrules");
            // GENERAL SETTINGS PAGE
            general_settingsgrid = new Gtk.Grid();
            general_settingsgrid.set_row_spacing(10);
            set_margins(general_settingsgrid, 30, 30, 30, 30);
            // margin header
            Label margins_header = makelabel(
                (_("Margins between virtual grid and screen edges")), 0, "justbold"
            );
            general_settingsgrid.attach(margins_header, 0, 0, 100, 1);
            OwnSpinButton leftmarginspin = new OwnSpinButton(
                "vert", "marginleft", 0, 200
            );
            OwnSpinButton rightmarginspin = new OwnSpinButton(
                "vert", "marginright", 0, 200
            );
            OwnSpinButton topmarginspin = new OwnSpinButton(
                "vert", "margintop", 0, 200
            );
            OwnSpinButton bottommarginspin = new OwnSpinButton(
                "vert", "marginbottom", 0, 200
            );
            general_settingsgrid.attach(new Label(""), 0, 5, 1, 1);
            Grid marginsgrid = new Grid();
            marginsgrid.set_row_spacing(10);
            // top margin
            Label topmarginlabel = makelabel((_("Top margin")), 0);
            marginsgrid.attach(topmarginlabel, 0, 0, 1, 1);
            marginsgrid.attach(topmarginspin, 12, 0, 1, 1);
            // left/right margin
            Label leftmarginlabel = makelabel((_("Left & right margins")), 0);
            marginsgrid.attach(leftmarginlabel, 0, 1, 1, 1);
            marginsgrid.attach(leftmarginspin, 11, 1, 1, 1);
            marginsgrid.attach(rightmarginspin, 13, 1, 1, 1);
            // bottom margin
            Label bottommarginlabel = makelabel((_("Bottom margin")), 0);
            marginsgrid.attach(bottommarginlabel, 0, 2, 1, 1);
            marginsgrid.attach(bottommarginspin, 12, 2, 1, 1);
            marginsgrid.attach(new Label("\t\t"), 10, 0, 1, 1);
            general_settingsgrid.attach(marginsgrid, 0, 1, 10, 4);
            // padding header
            Label padding_header = makelabel(
                (_("Padding")), 0, "justbold"
            );
            general_settingsgrid.attach(padding_header, 0, 6, 3, 1);
            // padding
            Grid paddinggrid = new Grid();
            Label paddinglabel = makelabel((_("Window padding")), 0);
            paddinggrid.attach(paddinglabel, 0, 0, 1, 1);
            paddinggrid.attach(new Label("\t"), 1, 0, 1, 1);
            OwnSpinButton paddingspin = new OwnSpinButton(
                "vert", "padding", 0, 200
            );
            paddinggrid.attach(paddingspin, 2, 0, 1, 1);
            general_settingsgrid.attach(paddinggrid, 0, 7, 10, 1);
            general_settingsgrid.attach(new Label(""), 0, 8, 1, 1);
            Grid useanimationsubgrid = new Gtk.Grid();
            Label useanimationheader = makelabel((_("Use animation")), 0, "justbold");
            useanimationsubgrid.attach(useanimationheader, 0, 0, 1, 1);
            useanimationsubgrid.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_animationswich = new Gtk.Switch();
            useanimationsubgrid.attach(enable_animationswich, 2, 0, 1, 1);
            general_settingsgrid.attach(useanimationsubgrid, 0, 9, 3, 1);
            ScrolledWindow scrolled_misc = new ScrolledWindow(null, null);
            scrolled_misc.add(general_settingsgrid);
            scrolled_misc.set_propagate_natural_width(true);
            allsettings_stack.add_named(scrolled_misc, "general");
            listbox.row_activated.connect(get_row);
            // weird that this doesn't seem to send the row by itself:
            listbox.row_selected.connect(()=> {
                get_row(listbox.get_selected_row());
            });
            listbox.select_row(listbox.get_row_at_index(0));
            this.add(maingrid);
            listbox.show_all();
            maingrid.show_all();
            this.show_all();
            // connect stuff
            switches = {
                enable_basictilingswitch, enable_advancedtilingswitch,
                enable_layouts, enable_rules, enable_animationswich
            };
            read_switchsettings = {
                "basictiling", "customgridtiling", "runlayouts",
                "windowrules", "softmove"
            };
            shufflersettings.changed["windowrules"].connect(()=> {
                set_widget_sensitive(ruleswidgets, "windowrules");
                if (shufflersettings.get_boolean("windowrules")) {
                    GLib.Timeout.add(500, ()=> {
                        update_currentrules();
                        return false;
                    });
                }
                manage_daemon();
            });
            for (int i=0; i<switches.length; i++) {
                shufflersettings.bind(read_switchsettings[i], switches[i],
                    "state", SettingsBindFlags.GET|SettingsBindFlags.SET);
            }
            checkbuttons = {
                toggle_sticky, toggle_swap, toggle_notification,
                toggle_guigrid
            };
            read_checkbutton = {
                "stickyneighbors", "swapgeometry", "showwarning",
                "runshufflergui"
            };
            for (int i=0; i<checkbuttons.length; i++) {
                shufflersettings.bind(read_checkbutton[i], checkbuttons[i],
                    "active", SettingsBindFlags.GET|SettingsBindFlags.SET);
            }
            Widget[] basicwidget = {basicshortcutlist_subgrid};
            shufflersettings.changed["basictiling"].connect(()=> {
                manage_daemon();
                set_widget_sensitive(basicwidget, "basictiling");
            });
            set_widget_sensitive(basicwidget, "basictiling");
            shufflersettings.changed["runshufflergui"].connect(()=> {
                reload_shortcuts();
            });
            manage_daemon();
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

        private void manage_daemon() {
            string[] relevant_keys = {
                "basictiling", "customgridtiling", "runlayouts", "windowrules"
            };
            bool sens = false;

            foreach (string k in relevant_keys) {
                sens = shufflersettings.get_boolean(k);
                if (sens) {
                    break;
                }
            }
            shufflersettings.set_boolean("runshuffler", sens);

            if (sens) {
                reload_shortcuts();
            }
            else {
                /*
                if shuffler daemon is off, we need gui to be off as well
                to prevent shortcuts to be active set in vain, since we
                split up functionality now
                */
                shufflersettings.set_boolean("runshufflergui", false);
            }
            general_settingsgrid.set_sensitive(sens);
        }

        private void set_widget_sensitive(
            Widget[] widgets, string key
        ) {
            foreach (Widget w in widgets) {
                bool newval = shufflersettings.get_boolean(key);
                w.set_sensitive(newval);
            }
            // let's allow ourselves a bit of patchwork
            if (key == "customgridtiling" &&
            !shufflersettings.get_boolean("customgridtiling")) {
                toggle_guigrid.set_active(false);
            }
        }

        private void reload_shortcuts () {
            GLib.Timeout.add(100, ()=> {
                try {
                bd_client.ReloadShortcuts();
                }
                catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
                return false;
            });
        }

        private Grid get_rowgrid(Label label, Image img, string hint) {
            Grid rowgrid = new Gtk.Grid();
            rowgrid.set_column_spacing(6);
            set_margins(rowgrid, 10, 3, 7, 7);
            rowgrid.attach(img, 0, 0, 1, 1);
            rowgrid.attach(label, 1, 0, 1, 1);
            rowgrid.set_tooltip_text(hint);
            return rowgrid;
        }

        private void get_row(ListBoxRow row) {
            int row_index = row.get_index();
            switch (row_index) {
                case 0:
                allsettings_stack.set_visible_child_name("tiling");
                break;
                case 1:
                allsettings_stack.set_visible_child_name("layouts");
                break;
                case 2:
                allsettings_stack.set_visible_child_name("rules");
                if (shufflersettings.get_boolean("runshuffler")) {
                    update_currentrules();
                }
                break;
                case 3:
                allsettings_stack.set_visible_child_name("general");
                break;
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
    }

    public static void main(string[] args) {
        Gtk.init(ref args);
        new ShufflerControlsWindow();
        Gtk.main();
    }
}