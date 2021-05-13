using Gtk;
using Gdk;
using Wnck;
using Gdk.X11;

// valac --pkg gtk+-3.0 --pkg gdk-x11-3.0 --pkg gdk-3.0 --pkg gio-2.0 --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE"

/*
Budgie Window Shuffler II
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

/* Shuffler
Main categories for the control interface:
 - Tiling
    - enable tiling shortcuts for quarter/half tiling (default: on)
    - enable custom shortcuts for tiling, resizing & moving windows* (default: off)
      (add explanation! add shortcut overview, add customize option for shortcuts?)
      * only an active option if quarter/half tiling is on
        - grid size
        - swap windows (default: off, checkbox only active if shortcuts is on)
        - sticky neighbours (default: off, checkbox only active if shortcuts is on)
        - GUI grid** (default: on, checkbox only active if shortcuts is on)
          **should we ditch this?
        - show notification on incorrect (target) window size (default:on,
          checkboxonly active if shortcuts is on) (appearance currently too short!)
 - Layouts
    - enable layouts (default: on)
    - setup layouts -> external setup window (button only active if layouts is on)
 - Rules
    - enable window rules -> external setup window (button only active if rules is on) <- nope, make it internal. No reason for calling an extra window
 - Miscelaneous
    - set margins & padding
    - enable animation (default:on, or depending on processor? checkbox only active if any of the shortcuts is on)
 */

 // todo: all strings to translate in one place
 // optimize labels {one step less}
 // optimize creation of switchgrids
 // make update rules conditional (rules is on in gsettings)


namespace ShufflerControls2 {

    GLib.Settings shufflersettings;

    private void set_widgetstyle(Widget w, string css_style, bool remove = false) {
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
                        print(@"$set_spinvalue\n");
                    }
                }
            });
            if (key != "") {
                print(@"$key, key is valid\n");
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

        Gdk.X11.Window timestamp_window;
        ShufflerInfoClient? client;
        [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]
        interface ShufflerInfoClient : Object {
            public abstract GLib.HashTable<string, Variant> get_rules () throws Error;
        }
        GLib.HashTable<string, Variant> foundrules;
        FileMonitor monitor_ruleschange;
        Stack allsettings_stack;
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

        Dialog get_task;

        Gtk.Switch[] switches;
        string[] read_switchsettings;
        OwnSpinButton[] spins;
        string[] read_spins;
        Gtk.CheckButton[] checkbuttons;
        string[] read_checkbutton;

        private string[] get_monitornames() {
            Gdk.Display gdk_dsp = Gdk.Display.get_default();
            int n_monitors = gdk_dsp.get_n_monitors();
            string[] monitors = {};
            for (int i=0; i < n_monitors; i++) {
                monitors += gdk_dsp.get_monitor(i).get_model();
            }
            return monitors;
        }

        private void call_dialog (
        ) {
            unowned X.Window xwindow = Gdk.X11.get_default_root_xwindow();
            unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
            Gdk.X11.Display display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
            timestamp_window = new Gdk.X11.Window.foreign_for_display(display, xwindow);
            bool initial_change = true;
            //  // tooltips
            //  string command_tooltip = _("Command to launch window or application (*mandatory)");
            string class_tooltip = "Window class of the window to be launched (*mandatory)";
            //  string windowname_tooltip = _("Window name - optional, to distinguish multiple windows of the same application");
            string gridxsize_tooltip = "Grid size - columns";
            string gridysize_tooltip = "Grid size - rows";
            string targetpositionx_tooltip = "Window target position on grid - horizontally";
            string targetpositiony_tooltip = "Window target position on grid - vertically";
            string xspan_tooltip = "Window size - columns";
            string yspan_tooltip = "Window size - rows";
            string monitor_tooltip = "Target monitor, default is on active monitor";
            //  string tryexisting_tooltip = _("Try to move an existing window before launching a new instance");
            get_task = new Dialog();
            var contentarea = get_task.get_content_area();
            contentarea.orientation = Gtk.Orientation.VERTICAL;
            // mastergrid
            Grid master_grid = new Gtk.Grid();
            set_margins(master_grid, 30, 30, 30, 30);
            contentarea.pack_start(master_grid, false, false, 0);
            ////////////////////
            ////////////////////
            // 1. APPLICATION FRAME
            Frame applicationframe = new Gtk.Frame("Application");
            var app_label = applicationframe.get_label_widget();
            set_widgetstyle(app_label, "justbold");
            // application grid
            Grid applicationgrid = new Gtk.Grid();
            set_margins(applicationgrid, 20, 20, 20, 20);
            applicationgrid.set_row_spacing(4);
            // - wmclass
            Label wmclass_label = new Label("WM class group*");
            wmclass_label.xalign = 0;
            Entry wmclass_entry = new Entry();    ////// other scope?
            wmclass_entry.changed.connect(()=> {
                set_widgetstyle(wmclass_entry, "red_text", true);
            });
            wmclass_entry.set_tooltip_text(class_tooltip);
            wmclass_entry.set_text("");
            wmclass_entry.set_size_request(250, 10);
            wmclass_entry.set_placeholder_text("Click a window to fetch");
            applicationgrid.attach(wmclass_label, 1, 4, 1, 1);
            applicationgrid.attach(new Label("\t\t"), 2, 4, 1, 1);
            applicationgrid.attach(wmclass_entry, 3, 4, 20, 1);
            applicationframe.add(applicationgrid);
            master_grid.attach(applicationframe, 1, 10, 10, 1);
            master_grid.attach(new Label(""), 1, 20, 1, 1);
            ////////////////////
            ////////////////////
            //  2. GEOMETRY FRAME
            Frame geometryframe = new Gtk.Frame("Window position & size");
            var geo_label = geometryframe.get_label_widget();
            set_widgetstyle(geo_label, "justbold");
            master_grid.attach(geometryframe, 1, 30, 10, 1);
            // geometry grid
            Grid geogrid = new Gtk.Grid();
            set_margins(geogrid, 20, 20, 20, 20);
            geogrid.set_row_spacing(0);
            // grid cols / rows
            Label grid_size_label = new Label("Grid size; colums & rows");
            grid_size_label.xalign = 0;
            geogrid.attach(grid_size_label, 1, 10, 1, 1);
            geogrid.attach(new Label("\t"), 2, 10, 1, 1);
            //  // get current gridsize
            //  //  read_currentgrid(client);
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
            Label winpos_label = new Label("Target window position, x / y");
            winpos_label.xalign = 0;
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
            Label cellspan_label = new Label("Window cell span, hor / vert");
            cellspan_label.xalign = 0;
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
            Gtk.Frame miscframe = new Gtk.Frame("Miscellaneous");
            var misc_label = miscframe.get_label_widget();
            set_widgetstyle(misc_label, "justbold");
            master_grid.attach(miscframe, 1, 50, 10, 1);
            Grid miscgrid = new Gtk.Grid();
            set_margins(miscgrid, 20, 20, 20, 20);
            miscgrid.set_row_spacing(4);
            miscframe.add(miscgrid);
            ///////////////////////
            // targetmonitor
            Label targetmonitor_label = new Label("Target monitor");
            miscgrid.attach(targetmonitor_label, 1, 1, 1, 1);
            ComboBoxText screendropdown = new ComboBoxText();
            screendropdown.set_tooltip_text(monitor_tooltip);
            string[] mons = get_monitornames();
            foreach (string m in mons) {
                screendropdown.append_text(m);
            }
            miscgrid.attach(new Label("\t"), 2, 1, 1, 1);
            miscgrid.attach(screendropdown, 3, 1, 1, 1);
            ////////////////////
            ////////////////////

            master_grid.attach(new Label(""), 1, 109, 1, 1);

            Gtk.Box dialogaction_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Button applytask_button = new Gtk.Button();
            applytask_button.label = "Done";
            applytask_button.set_size_request(90, 10);
            applytask_button.clicked.connect(()=> {
                apply_newrule(
                    wmclass_entry, grid_xsize_spin, grid_ysize_spin,
                    xpos_spin, ypos_spin, xspan_spin, yspan_spin,
                    screendropdown
                );
            });
            Button canceltask_button = new Gtk.Button();
            canceltask_button.label = "Cancel";
            canceltask_button.set_size_request(90, 10);
            canceltask_button.clicked.connect(()=> {
                get_task.destroy();
                get_task = null;
            });
            dialogaction_box.pack_end(applytask_button, false, false, 2);
            dialogaction_box.pack_end(canceltask_button, false, false, 2);
            master_grid.attach(dialogaction_box, 1, 110, 10, 1); //

            get_task.set_transient_for(this);
            get_task.decorated = false;
            contentarea.show_all();
            ///
            OwnSpinButton[] allspins = {
                grid_xsize_spin, grid_ysize_spin, xpos_spin, ypos_spin, xspan_spin, yspan_spin
            };
            foreach (OwnSpinButton spin in allspins) {
                spin.spinvalue.changed.connect(()=> {
                    set_spincolor(allspins);
                });
            };
            ///

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
            get_task.run();
        }

        private uint get_now() {
            // get timestamp
            return Gdk.X11.get_server_time(timestamp_window);
        }

        private void makesure_offocus () {
            foreach (Wnck.Window w in wnck_scr.get_windows()) {
                if (w.get_name().down() == "Window Shuffler Controls") {
                    w.activate(get_now());
                    break;
                }
                else if (w.get_name() == "new_shuffler_control") {
                    w.activate(get_now());
                }
            }
        }

        ///////////////////////////////////////////////////
        ///////////////////////////////////////////////////
        private void apply_newrule(
            Entry e, OwnSpinButton x, OwnSpinButton y, OwnSpinButton xpos,
            OwnSpinButton ypos, OwnSpinButton xspan, OwnSpinButton yspan,
            ComboBoxText dropdown
        ) {
            bool apply = true;
            string monitorline = "";
            string classname = e.get_text();
            if (classname == "") {
                apply = false;
                print("set red now\n");
                set_widgetstyle(e, "red_text");
            }
            int cols = x.get_value();
            int rows = y.get_value();
            int xposval = xpos.get_value();
            int yposval = ypos.get_value();
            int xspanval = xspan.get_value();
            int yspanval = yspan.get_value();
            string disp = dropdown.get_active_text();
            if (disp != null) {
                monitorline = @"\nMonitor=$disp";
            }
            string filecontent =  @"\nCols=$cols".concat(
                @"\nRows=$rows", @"\nXPosition=$xposval",
                @"\nYPosition=$yposval",@"\nXSpan=$xspanval",
                @"\nYSpan=$yspanval", monitorline
            );

            print(@"$filecontent\n");

            foreach (string k in foundrules.get_keys()) {
                if (e.get_text() == k) {
                    print("already exists\n");
                }
            }
        }

        // keep a bit longer for possible spare parts

        //  private void apply_taskedit(
        //      string candidate_file, bool apply = false, string? path = null
        //  ) {
        //      try {
        //          File targetfile;
        //          if (apply && path != null) {
        //              targetfile = File.new_for_path(path);
        //          }
        //          else {
        //              string runfile =  "/tmp/".concat(username, "_istestingtask");
        //              targetfile = File.new_for_path(runfile);
        //          }
        //          if (targetfile.query_exists ()) {
        //              delete_file(targetfile);
        //          }
        //          // Create a new file with this name
        //          var file_stream = targetfile.create (FileCreateFlags.REPLACE_DESTINATION);
        //          var data_stream = new DataOutputStream (file_stream);
        //          data_stream.put_string (candidate_file);
        //          if (!apply) {
        //              string testcommand = Config.SHUFFLER_DIR + "/run_layout use_testing";
        //              // keep for quick compile & test
        //              //  string testcommand = "/lib/budgie-window-shuffler/run_layout use_testing";
        //              run_command(testcommand);
        //          }
        //      }
        //      catch (Error e) {
        //          stderr.printf ("Error: %s\n", e.message);
        //      }
        //  }


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
        }

        ///////////////////////////////////////////////////
        ///////////////////////////////////////////////////

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
                "WM-class", "Grid", "X, Y", "Span", "Display"
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

                    Variant windowrule = foundrules[k];
                    string monitor = (string)windowrule.get_child_value(0);
                    string xposition = (string)windowrule.get_child_value(1);
                    string yposition = (string)windowrule.get_child_value(2);
                    string rows = (string)windowrule.get_child_value(3);
                    string cols = (string)windowrule.get_child_value(4);
                    string xspan = (string)windowrule.get_child_value(5);
                    string yspan = (string)windowrule.get_child_value(6);
                    Label newlabel = new Label(k);
                    newlabel.xalign = 0;
                    Label newgridsize = new Label(cols + "x" + rows);
                    Label newposition = new Label(xposition + ", " + yposition);
                    Label newspan = new Label(xspan + "x" + yspan);
                    Label newmonitor = new Label(monitor);
                    newrulesgrid.attach(newlabel, 0, currow, 1, 1);
                    newrulesgrid.attach(newgridsize, 1, currow, 1, 1);
                    newrulesgrid.attach(newposition, 2, currow, 1, 1);
                    newrulesgrid.attach(newspan, 3, currow, 1, 1);
                    newrulesgrid.attach(newmonitor, 4, currow, 1, 1);
                    newrulesgrid.attach(new Label(" "), 5, currow, 1, 1);
                    newrulesgrid.attach(taskeditbutton, 6, currow, 1, 1);
                    newrulesgrid.attach(taskdeletebutton, 7, currow, 1, 1);
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
                Label newlabel = new Label(leftitems[i]);
                newlabel.xalign = 0;
                grid.attach(newlabel, 0, i + startint, 1, 1);
                grid.attach(new Label("\t\t"), 1, i + startint, 1, 1);
                Label newshortcut = new Label(rightitems[i]);
                grid.attach(newshortcut, 2, i + startint, 1, 1);
                newshortcut.xalign = 0;
            }
        }

        public ShufflerControlsWindow() {
            wnck_scr = Wnck.Screen.get_default();
            // window stuff
            this.title = "Window Shuffler Controls";
            this.set_resizable(false);
            // watch rulesdir
            string windowrule_location = create_dirs_file(
                ".config/budgie-extras/shuffler/windowrules"
            );
            try {
                File rulesdir = File.new_for_path(windowrule_location);
                monitor_ruleschange = rulesdir.monitor(FileMonitorFlags.NONE, null);
                monitor_ruleschange.changed.connect(update_currentrules);
            }
            catch (Error e) {
            }
            // settings
            shufflersettings = new GLib.Settings("org.ubuntubudgie.windowshuffler");
            var tilingicon = new Gtk.Image.from_icon_name(
                "tilingicon-symbolic", Gtk.IconSize.DND);
            var layoutsicon = new Gtk.Image.from_icon_name(
                "layouticon-symbolic", Gtk.IconSize.DND);
            var rulesicon = new Gtk.Image.from_icon_name(
                "rulesicon-symbolic", Gtk.IconSize.DND);
            var generalprefs = new Gtk.Image.from_icon_name(
                "miscellaneousprefs-symbolic", Gtk.IconSize.DND);
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
            listbox.set_size_request(200, 450);
            // content
            Label title1 = new Label("Tiling");
            string title1_hint =  "Window tiling & shortcuts";
            title1.set_xalign(0);
            Label title2 = new Label("Layouts");
            string title2_hint = "Automatic window & application presets";
            title2.set_xalign(0);
            Label title3 = new Label("Window rules");
            string title3_hint = "Define where application windows should be opened";
            title3.set_xalign(0);
            Label title4 = new Label("Miscellaneous");
            string title4_hint = "General preferences";
            title4.set_xalign(0);
            listbox.insert(get_rowgrid(title1, tilingicon, title1_hint), 1);
            listbox.insert(get_rowgrid(title2, layoutsicon, title2_hint), 2);
            listbox.insert(get_rowgrid(title3, rulesicon, title3_hint), 3);
            listbox.insert(get_rowgrid(title4, generalprefs,title4_hint), 4);
            // stack
            allsettings_stack = new Gtk.Stack();
            maingrid.attach(allsettings_stack, 2, 1, 1, 1);
            allsettings_stack.set_transition_type(StackTransitionType.OVER_UP_DOWN);

            // TILING PAGE
            tilinggrid = new Gtk.Grid();
            tilinggrid.set_row_spacing(10);
            set_margins(tilinggrid, 40, 40, 40, 40);
            // header + switch (in subgrid)
            Grid switchgrid_basicshortcuts = new Gtk.Grid();
            Label basicshortcutsheader = new Label(
                "Basic quarter & half tiling"
            );
            basicshortcutsheader.xalign = 0;
            basicshortcutsheader.get_style_context().add_class("justbold");
            switchgrid_basicshortcuts.attach(basicshortcutsheader, 0, 0, 1, 1);
            switchgrid_basicshortcuts.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_basictilingswitch = new Gtk.Switch();
            switchgrid_basicshortcuts.attach(enable_basictilingswitch, 2, 0, 1, 1);
            tilinggrid.attach(switchgrid_basicshortcuts, 0, 0, 10, 1);
            // basic shortcutlist (in subgrid)
            Grid basicshortcutlist_subgrid = new Gtk.Grid();
            // translations!
            string[] basics = {
                "Top-left", "Top-right", "Bottom-right", "Bottom-left",
                "Left-half", "Top-half", "Right-half", "Bottom-half"
            };
            string[] basicshortcuts = {
                "Ctrl + Alt + 7", "Ctrl + Alt + 9", "Ctrl + Alt + 3",
                "Ctrl + Alt + 1", "Ctrl + Alt + 4", "Ctrl + Alt + 8",
                "Ctrl + Alt + 6", "Ctrl + Alt + 2"
            };
            add_series_toggrid(basicshortcutlist_subgrid, basics, basicshortcuts); // optimized
            tilinggrid.attach(basicshortcutlist_subgrid, 0, 1, 10, 1);
            basicshortcutlist_subgrid.show_all();
            tilinggrid.attach(new Label(""), 1, 2, 1, 1);
            // custom size header + switch (in subgrid)
            Grid switchgrid_advancedshortcuts = new Gtk.Grid();
            Label advancedcutsheader = new Label(
                "Tiling, resizing & moving windows in a custom grid"
            );
            advancedcutsheader.xalign = 0;
            advancedcutsheader.get_style_context().add_class("justbold");
            switchgrid_advancedshortcuts.attach(advancedcutsheader, 0, 0, 1, 1);
            switchgrid_advancedshortcuts.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_advancedtilingswitch = new Gtk.Switch();
            switchgrid_advancedshortcuts.attach(enable_advancedtilingswitch, 2, 0, 1, 1);
            tilinggrid.attach(switchgrid_advancedshortcuts, 0, 15, 10, 1);

            Label customgridsettings_label = new Label("Grid size" + ":");
            customgridsettings_label.xalign = 0;
            customgridsettings_label.get_style_context().add_class("justitalic");
            tilinggrid.attach(customgridsettings_label, 0, 16, 10, 1);
            Grid gridsizegrid = new Gtk.Grid();

            Label gridsize_cols_label = new Label("Columns");
            gridsize_cols_label.xalign = 0;
            gridsizegrid.attach(gridsize_cols_label, 0, 0, 1, 1);
            gridsizegrid.attach(new Label(" "), 1, 0, 1, 1);
            OwnSpinButton grid_horsize = new OwnSpinButton("hor", "cols", 0, 10);
            gridsizegrid.attach(grid_horsize, 2, 0, 1, 1);
            gridsizegrid.attach(new Label("\t"), 3, 0, 1, 1);
            Label grid_vertsize_label = new Label("Rows");
            grid_vertsize_label.xalign = 0;
            gridsizegrid.attach(grid_vertsize_label, 4, 0, 1, 1);
            gridsizegrid.attach(new Label(" "), 5, 0, 1, 1);
            OwnSpinButton grid_vertsize = new OwnSpinButton("vert", "rows", 0, 10);
            gridsizegrid.attach(grid_vertsize, 6, 0, 1, 1);
            tilinggrid.attach(gridsizegrid, 0, 17, 10, 1);

            // options
            Label options_label = new Label("Options" + ":");
            options_label.xalign = 0;
            options_label.get_style_context().add_class("justitalic");
            tilinggrid.attach(options_label, 0, 18, 10, 1);
            Grid optionsgrid = new Grid();

            // sticky
            Label stickylabel = new Label("Resize opposite window");
            stickylabel.xalign = 0; // optimize please
            optionsgrid.attach(stickylabel, 0, 0, 1, 1);
            optionsgrid.attach(new Label("\t"), 1, 0, 1, 1);
            CheckButton toggle_sticky = new CheckButton();
            optionsgrid.attach(toggle_sticky, 2, 0, 1, 1);

            // swap
            Label swaplabel = new Label("Swap windows");
            swaplabel.xalign = 0; // optimize please
            optionsgrid.attach(swaplabel, 0, 1, 1, 1);
            optionsgrid.attach(new Label("\t"), 1, 1, 1, 1);
            CheckButton toggle_swap = new CheckButton();
            optionsgrid.attach(toggle_swap, 2, 1, 1, 1);

            // notification
            Label notificationlabel = new Label("Show notification on incorrect window size");
            notificationlabel.xalign = 0; // optimize please
            optionsgrid.attach(notificationlabel, 0, 2, 1, 1);
            optionsgrid.attach(new Label("\t"), 1, 2, 1, 1);
            CheckButton toggle_notification = new CheckButton();
            optionsgrid.attach(toggle_notification, 2, 2, 1, 1);

            // guigrid
            Label useguigridlabel = new Label("Enable GUI grid");
            useguigridlabel.xalign = 0; // optimize please
            optionsgrid.attach(useguigridlabel, 0, 3, 1, 1);
            optionsgrid.attach(new Label("\t"), 1, 3, 1, 1);
            CheckButton toggle_guigrid = new CheckButton();
            optionsgrid.attach(toggle_guigrid, 2, 3, 1, 1);
            tilinggrid.attach(optionsgrid, 0, 19, 10, 1);
            Label guishortcutsheader = new Label("GUI grid shortcuts" + ":");
            guishortcutsheader.xalign = 0;
            guishortcutsheader.get_style_context().add_class("justitalic");
            tilinggrid.attach(guishortcutsheader, 0, 20, 10, 1);

            string[] guis = {
                "Toggle GUI grid", "Add a column",
                "Add a row", "Remove column", "Remove row",
            };

            string[] guishortcuts = {
                "Ctrl + Alt + S", "→", "↓", "←", "↑"
            };
            Grid guishortcuts_subgrid = new Grid();
            add_series_toggrid(guishortcuts_subgrid, guis, guishortcuts);
            tilinggrid.attach(guishortcuts_subgrid, 0, 21, 10, 1);

            // shortcutlist custom grid
            Label jump_header_label = new Label(
                "Shortcuts for moving a window to the nearest grid cell" + ":"
            );
            jump_header_label.xalign = 0;
            jump_header_label.get_style_context().add_class("justitalic");
            tilinggrid.attach(jump_header_label, 0, 26, 10, 1);

            Grid advancedshortcutlist_subgrid = new Gtk.Grid();
            string[] movers = {
                "Move left", "Move right", "Move up", "Move down"
            };

            string[] movershortcuts = {
                "Super + Alt + ←", "Super + Alt + →",
                "Super + Alt + ↑", "Super + Alt + ↓"
            };

            add_series_toggrid(
                advancedshortcutlist_subgrid, movers, movershortcuts
            );
            tilinggrid.attach(advancedshortcutlist_subgrid, 0, 27, 10, 1);

            string resize_header = "Shortcuts for resizing a window" + ":";
            Label resize_header_label = new Label(resize_header);
            resize_header_label.xalign = 0;
            resize_header_label.get_style_context().add_class("justitalic");
            Grid workarounspace_1 = new Grid();
            workarounspace_1.attach(resize_header_label, 0, 0, 1, 1);
            set_margins(workarounspace_1, 0, 10, 10, 10);
            advancedshortcutlist_subgrid.attach(workarounspace_1, 0, 6, 10, 1);
            string[] resizers = {
                "Expand horizontally (to the right)",
                "Shrink horizontally (from the right)",
                "Expand vertically (down)",
                "Shrink vertically (from the bottom)",
                "Expand horizontally (to the left)",
                "Shrink horizontally (from the left)",
                "Expand vertically (up)",
                "Shrink vertically (from the top)",
                "Toggle resizing opposite window"
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

            Label other_header_label = new Label("Other" + ":");
            other_header_label.xalign = 0;
            other_header_label.get_style_context().add_class("justitalic");

            Grid workarounspace_2 = new Grid();
            workarounspace_2.attach(other_header_label, 0, 0, 1, 1);
            set_margins(workarounspace_2, 0, 0, 10, 10);
            advancedshortcutlist_subgrid.attach(workarounspace_2, 0, 21, 10, 1); //optimize!

            Label tileall_label = new Label("Tile all windows to grid");
            tileall_label.xalign = 0;
            advancedshortcutlist_subgrid.attach(tileall_label, 0, 23, 1, 1);
            advancedshortcutlist_subgrid.attach(new Label("\t\t"), 1, 23, 1, 1);
            Label tileall_shortcut = new Label("Control + Super + A");
            tileall_shortcut.xalign = 0;
            advancedshortcutlist_subgrid.attach(tileall_shortcut, 2, 23, 1, 1);

            Label toggle_opposite_label = new Label("Toggle resizing opposite window");
            toggle_opposite_label.xalign = 0;
            advancedshortcutlist_subgrid.attach(toggle_opposite_label, 0, 24, 1, 1);
            advancedshortcutlist_subgrid.attach(new Label("\t\t"), 1, 24, 1, 1);
            Label toggle_opposite_shortcut = new Label("Control + Super + N");
            toggle_opposite_shortcut.xalign = 0;
            advancedshortcutlist_subgrid.attach(toggle_opposite_shortcut, 2, 24, 1, 1);
            advancedshortcutlist_subgrid.show_all();
            tilinggrid.attach(new Label(""), 1, 49, 1, 1);

            ScrolledWindow scrolled_tiling = new ScrolledWindow(null, null);
            scrolled_tiling.add(tilinggrid);
            scrolled_tiling.set_propagate_natural_width(true);
            allsettings_stack.add_named(scrolled_tiling, "tiling");

            // LAYOUTS PAGE
            layoutsgrid = new Gtk.Grid();
            layoutsgrid.set_row_spacing(20);
            set_margins(layoutsgrid, 40, 40, 40, 40);
            // optimize please with similar grids
            Grid switchgrid_layouts = new Gtk.Grid();
            Label layoutssheader = new Label(
                "Layouts"
            );
            layoutssheader.xalign = 0;
            layoutssheader.get_style_context().add_class("justbold");
            switchgrid_layouts.attach(layoutssheader, 0, 0, 1, 1);
            switchgrid_layouts.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_layouts = new Gtk.Switch();
            switchgrid_layouts.attach(enable_layouts, 2, 0, 1, 1);
            layoutsgrid.attach(switchgrid_layouts, 0, 0, 10, 1);
            Grid layoutshortcutgrid = new Grid();
            Label layoutshortcutlabel = new Label(
                "Toggle layouts quicklist & manager"
            );
            layoutshortcutlabel.xalign = 0;
            layoutshortcutgrid.attach(layoutshortcutlabel, 0, 0, 1, 1);
            layoutshortcutgrid.attach(new Label("\t"), 1, 0, 1, 1);
            layoutshortcutgrid.attach(new Label("Super + Alt + L"), 2, 0, 1, 1);
            layoutsgrid.attach(layoutshortcutgrid, 0, 1, 10, 10);
            layoutsgrid.attach(new Label(""), 0, 2, 1, 1);
            Button manage_layoutsbutton = new Gtk.Button();
            manage_layoutsbutton.label = "Setup now";
            manage_layoutsbutton.clicked.connect(()=> {
                //  string layoutsetup_path = Config.SHUFFLER_DIR + "/toggle_layouts_popup";
                string layoutsetup_path = "/usr/lib/budgie-window-shuffler" + "/toggle_layouts_popup";
                print(@"$layoutsetup_path\n");
                try {
                    Process.spawn_command_line_sync(layoutsetup_path);
                }
                catch (Error e) {
                }
            });
            layoutsgrid.attach(manage_layoutsbutton, 0, 3, 1, 1);
            allsettings_stack.add_named(layoutsgrid, "layouts");
            // RULES PAGE
            rulesgrid = new Gtk.Grid();
            rulesgrid.set_row_spacing(20);
            set_margins(rulesgrid, 40, 40, 40, 40);
            // optimize please with similar grids
            Grid switchgrid_rules = new Gtk.Grid();
            Label rulessheader = new Label(
                "Window rules"
            );
            rulessheader.xalign = 0;
            rulessheader.get_style_context().add_class("justbold");
            switchgrid_rules.attach(rulessheader, 0, 0, 1, 1);
            switchgrid_rules.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_rules = new Gtk.Switch();
            switchgrid_rules.attach(enable_rules, 2, 0, 1, 1);
            rulesgrid.attach(switchgrid_rules, 0, 0, 10, 1);
            rulesgrid.attach(new Label(""), 0, 1, 10, 1);
            Label activerules = new Label(
                "Stored rules" + ":"
            );
            activerules.xalign = 0;
            activerules.get_style_context().add_class("justitalic");
            rulesgrid.attach(activerules, 0, 2, 10, 1);
            newrulesgrid = new Grid();
            rulesgrid.attach(newrulesgrid, 0, 10, 10, 1);
            ScrolledWindow scrolled_rules = new ScrolledWindow(null, null);
            scrolled_rules.add(rulesgrid);
            scrolled_rules.set_propagate_natural_width(true);
            Gtk.Button newrulebutton = new Button();
            newrulebutton.label = "Add new rule";
            newrulebutton.set_size_request(1,1);
            newrulebutton.clicked.connect(()=> {
                print("dialog?\n");
                call_dialog();
            });
            rulesgrid.attach(newrulebutton, 0, 21, 1, 1);
            allsettings_stack.add_named(scrolled_rules, "rules");
            // GENERAL SETTINGS PAGE
            general_settingsgrid = new Gtk.Grid();
            general_settingsgrid.set_row_spacing(10);
            set_margins(general_settingsgrid, 40, 40, 40, 40);
            // margin header
            Label margins_header = new Label("Margins between virtual grid and screen edges");
            margins_header.get_style_context().add_class("justbold");
            margins_header.xalign = 0;
            general_settingsgrid.attach(margins_header, 0, 0, 100, 1);
            OwnSpinButton leftmarginspin = new OwnSpinButton("vert", "marginleft", 0, 200);
            OwnSpinButton rightmarginspin = new OwnSpinButton("vert", "marginright", 0, 200);
            OwnSpinButton topmarginspin = new OwnSpinButton("vert", "margintop", 0, 200);
            OwnSpinButton bottommarginspin = new OwnSpinButton("vert", "marginbottom", 0, 200);
            general_settingsgrid.attach(new Label(""), 0, 5, 1, 1);
            Grid marginsgrid = new Grid();
            marginsgrid.set_row_spacing(10);
            // top margin
            Label topmarginlabel = new Label("Top margin");
            topmarginlabel.xalign = 0;
            marginsgrid.attach(topmarginlabel, 0, 0, 1, 1);
            marginsgrid.attach(topmarginspin, 12, 0, 1, 1);
            // left/right margin
            Label leftmarginlabel = new Label("Left & right margins");
            leftmarginlabel.xalign = 0;
            marginsgrid.attach(leftmarginlabel, 0, 1, 1, 1);
            marginsgrid.attach(leftmarginspin, 11, 1, 1, 1);
            marginsgrid.attach(rightmarginspin, 13, 1, 1, 1);
            // bottom margin
            Label bottommarginlabel = new Label("Bottom margin");
            bottommarginlabel.xalign = 0; // optimize please
            marginsgrid.attach(bottommarginlabel, 0, 2, 1, 1);
            marginsgrid.attach(bottommarginspin, 12, 2, 1, 1);
            marginsgrid.attach(new Label("\t\t"), 10, 0, 1, 1);
            general_settingsgrid.attach(marginsgrid, 0, 1, 10, 4);
            // padding header
            Label padding_header = new Label("Padding");
            padding_header.get_style_context().add_class("justbold");
            padding_header.xalign = 0;
            general_settingsgrid.attach(padding_header, 0, 6, 3, 1);
            // padding
            Grid paddinggrid = new Grid();
            Label paddinglabel = new Label("Window padding");
            paddinglabel.xalign = 0; // optimize please
            paddinggrid.attach(paddinglabel, 0, 0, 1, 1);
            paddinggrid.attach(new Label("\t"), 1, 0, 1, 1);
            OwnSpinButton paddingspin = new OwnSpinButton("vert", "padding", 0, 200);
            paddinggrid.attach(paddingspin, 2, 0, 1, 1);
            general_settingsgrid.attach(paddinggrid, 0, 7, 10, 1);
            general_settingsgrid.attach(new Label(""), 0, 8, 1, 1);
            Grid useanimationsubgrid = new Gtk.Grid();
            Label useanimationheader = new Label(
                "Use animation"
            );
            useanimationheader.xalign = 0;
            useanimationheader.get_style_context().add_class("justbold");
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
                update_currentrules();
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