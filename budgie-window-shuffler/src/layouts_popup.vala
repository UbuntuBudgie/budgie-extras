using Gtk;
using Wnck;
using Gdk.X11;
using Gdk;

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

// translation

namespace LayoutsPopup {

    ShufflerInfoClient? client;
    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]
    interface ShufflerInfoClient : Object {
        public abstract Variant extracttask_fromfile (string path) throws Error;
        public abstract int[] get_grid() throws Error;
        public abstract int get_numberof_workspaces() throws Error;
    }
    string searchpath;
    Gtk.Window? layouts;
    File popuptrigger;
    Gdk.X11.Window timestamp_window;
    Wnck.Screen wnck_scr;
    Gtk.Dialog? get_task;
    Gtk.Dialog? ask_confirmdialog;
    string username;
    string homedir;
    string triggerfpath;


    class PopupWindow : Gtk.Window {

        /*
        / master widget in this window is a mastergrid, for we can easily
        / set cornerspacing, to align all widgets on the right edge of the
        / window. mastergrid holds a stack in the top section. When stack
        / page is changed, bottom section (box holding buttons) changes
        / alongside by button press.
        / layoutlist (stack page 1) is dynamically updated by signal, wating
        / for changes in the layouts config directory.
        */

        Grid mastergrid;
        Gtk.Grid layoutlist_scrolledwindow_grid;
        Gtk.Grid stackgrid_layoutlist;
        Gtk.Grid stackgrid_newlayout;
        Gtk.Grid stackgrid_editlayout;
        FileMonitor layoutschange_monitor;
        Stack layoutspopup_stack;
        Entry? wmclass_entry;
        Entry? editlayoutname_entry;
        Gdk.Display gdk_dsp;
        Gtk.ScrolledWindow layoutlist_scrolledwindow;
        ScrolledWindow tasklist_scrolledwindow;
        Gtk.Box addlayout_box;
        Gtk.Box newlayout_box;
        Gtk.Box editlayout_box;
        string last_layoutname;
        Gtk.Frame layoutframe;
        Gtk.Frame newlayout_frame;
        Gtk.Frame editlayout_frame;
        Gtk.Button? editlayoutbutton_done;
        int set_gridxsize;
        int set_gridysize;
        GLib.Settings shuffler_settings;
        string default_set;

        public PopupWindow(bool fromcontrol) {

            default_set = _("Not set");
            // settings
            shuffler_settings = new GLib.Settings(
                "org.ubuntubudgie.windowshuffler"
            );
            // css stuff
            string layoutss_stylecss = """
            .subheader {
                margin-bottom: 20px;
                margin-top: 10px;
            }
            .secondsubheader {
                margin-bottom: 20px;
                margin-top: 20px;
            }
            .justbold {
                font-weight: bold;
            }
            .arrowbutton {
                padding: 0px;
                border-width: 0px;
            }
            .red_text {
                color: white;
                background-color: red;
            }
            .currbutton:focus {
                font-weight: bold;
            }
            """;
            initialiseLocaleLanguageSupport();
            Gdk.Screen gdk_scr = this.get_screen();
            gdk_dsp = Gdk.Display.get_default();
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(layoutss_stylecss);
                Gtk.StyleContext.add_provider_for_screen(
                    gdk_scr, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }
            // focus management / get wmclass of picked window
            wnck_scr.active_window_changed.connect( ()=> {
                Wnck.Window? newactive = wnck_scr.get_active_window();
                if (newactive != null) {
                    string classname = newactive.get_class_group_name().down();
                    if (
                        classname != "layouts_popup" &&
                        get_task == null &&
                        ask_confirmdialog == null
                    ) {
                        delete_file(popuptrigger);
                        this.destroy();
                    }
                    else if (
                        wmclass_entry != null &&
                        newactive.get_window_type() == Wnck.WindowType.NORMAL
                    ) {
                        if (wmclass_entry.is_focus) {
                            wmclass_entry.set_text(classname);
                        }
                        makesure_offocus();
                    }
                }
            });
            // STACK
            layoutspopup_stack = new Stack();
            layoutspopup_stack.set_transition_type(
                Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
            );
            // MASTERGRID (includes stack)
            mastergrid = new Grid();
            mastergrid.attach(new Label(""), 1, 40, 1, 1);
            // corners spacing of mastergrid
            set_margins(mastergrid, 35, 35, 35, 35);
            mastergrid.attach(layoutspopup_stack, 1, 1, 1, 1);
            this.add(mastergrid);
            // 1. PICK LAYOUT GRID
            layoutframe = new Gtk.Frame(_("Layouts"));
            var widget_label = layoutframe.get_label_widget();
            set_widgetstyle(widget_label, "justbold");
            stackgrid_layoutlist = new Grid(); // dynamically updated
            set_margins(stackgrid_layoutlist, 20, 20, 10, 20);
            layoutframe.add(stackgrid_layoutlist);
            layoutlist_scrolledwindow = new ScrolledWindow(null, null);
            layoutlist_scrolledwindow_grid = new Gtk.Grid();
            layoutlist_scrolledwindow.set_size_request(430, 250);
            layoutlist_scrolledwindow.set_min_content_width(430);
            stackgrid_layoutlist.attach(layoutlist_scrolledwindow, 1, 2, 5, 10);
            layoutlist_scrolledwindow.add(layoutlist_scrolledwindow_grid);
            File layoutschange_dir = File.new_for_path(searchpath);
            try {
                layoutschange_monitor = layoutschange_dir.monitor(
                    FileMonitorFlags.NONE, null
                );
                layoutschange_monitor.changed.connect(() => {
                    update_layoutgrid(); // here the grid is filled
                });
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
            update_layoutgrid();
            // buttons of mastergrid, corresponcing to stack "picklayout"
            addlayout_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            mastergrid.attach(addlayout_box, 1, 51, 4, 1); // since this is the "home" page
            Gtk.Button addbutton = new Gtk.Button();
            addbutton.label = _("Add new");
            addbutton.set_size_request(120, 10);

            if (fromcontrol) {
                Button donefromcontrol = new Gtk.Button();
                donefromcontrol.clicked.connect(()=> {
                    this.destroy();
                    delete_file(popuptrigger);
                });
                donefromcontrol.label = _("Done");
                donefromcontrol.set_size_request(120, 10);
                addlayout_box.pack_end(donefromcontrol, false, false, 2);
            }
            addlayout_box.pack_end(addbutton, false, false, 2);


            // 2. NEW LAYOUTS GRID
            newlayout_frame = new Gtk.Frame(_("New layout"));
            var newlayout_widget_label = newlayout_frame.get_label_widget();
            set_widgetstyle(newlayout_widget_label, "justbold");
            stackgrid_newlayout = new Grid(); // dynamically updated
            set_margins(stackgrid_newlayout, 20, 20, 20, 20);
            newlayout_frame.add(stackgrid_newlayout);
            Entry layoutname_entry = new Entry();
            layoutname_entry.set_size_request(300, 10);
            stackgrid_newlayout.attach(layoutname_entry, 0, 1, 1, 1);
            // buttons of mastergrid, corresponcing to stack "newlayout"
            newlayout_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Gtk.Button apply_newlayoutbutton = new Gtk.Button();
            apply_newlayoutbutton.label = _("Create");
            apply_newlayoutbutton.set_size_request(120, 10);
            newlayout_box.pack_end(apply_newlayoutbutton, false, false, 2);
            Gtk.Button cancel_newlayoutbutton = new Gtk.Button();
            cancel_newlayoutbutton.label = _("Cancel");
            cancel_newlayoutbutton.set_size_request(120, 10);
            newlayout_box.pack_end(cancel_newlayoutbutton, false, false, 2);
            // 3. EDIT LAYOUT GRID
            editlayout_frame = new Gtk.Frame(_("Edit layout"));
            var editlayout_widget_label = editlayout_frame.get_label_widget();
            set_widgetstyle(editlayout_widget_label, "justbold");
            stackgrid_editlayout = new Grid(); // dynamically updated
            set_margins(stackgrid_editlayout, 20, 20, 10, 20);
            editlayout_frame.add(stackgrid_editlayout);
            //  stackgrid_editlayout = new Grid();
            Label editlayoutname_label = new Label(_("Layout name") + ":");
            editlayoutname_label.xalign = 0;
            set_widgetstyle(editlayoutname_label, "subheader");
            stackgrid_editlayout.attach(editlayoutname_label, 0, 0, 1, 1);
            Box editlayoutname_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
            editlayoutname_entry = new Entry();
            editlayoutname_entry.set_size_request(300, 10);
            editlayoutname_box.pack_start(editlayoutname_entry, false, false, 0);
            Button reset_editlayoutname = new Button.from_icon_name(
                    "edit-undo", Gtk.IconSize.BUTTON
                );
            reset_editlayoutname.set_relief(Gtk.ReliefStyle.NONE);
            editlayoutname_box.pack_start(reset_editlayoutname, false, false, 0);
            stackgrid_editlayout.attach(editlayoutname_box, 0, 1, 10, 1);
            Label tasklist_label = new Label(_("Window tasks") + ":");
            set_widgetstyle(tasklist_label, "secondsubheader");
            tasklist_label.xalign = 0;
            stackgrid_editlayout.attach(tasklist_label, 0, 2, 1, 1);
            tasklist_scrolledwindow = new ScrolledWindow(null, null);
            tasklist_scrolledwindow.set_size_request(430, 180);
            stackgrid_editlayout.attach(tasklist_scrolledwindow, 0, 10, 1, 1);
            // buttons of mastergrid, corresponcing to stack "editlayout"
            editlayout_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            editlayoutbutton_done = new Gtk.Button();
            editlayoutbutton_done.set_size_request(120, 10);
            editlayoutbutton_done.label = _("Done");
            editlayout_box.pack_end(editlayoutbutton_done, false, false, 2);
            Gtk.Button addtaskbutton = new Gtk.Button();
            addtaskbutton.set_size_request(120, 10);
            addtaskbutton.label = _("Add task");
            editlayout_box.pack_end(addtaskbutton, false, false, 2);
            // so, let's add stuff to stack
            layoutspopup_stack.add_named(layoutframe, "picklayout");
            layoutspopup_stack.add_named(newlayout_frame, "newlayout");
            layoutspopup_stack.add_named(editlayout_frame, "editlayout");
            // general window stuff
            this.decorated = false;
            this.title = "LayoutsPopup"; // don't change, it's identification
            this.set_skip_taskbar_hint(true);
            this.set_position(Gtk.WindowPosition.CENTER_ALWAYS);
            this.destroy.connect(() => {
                if (get_task != null) {
                    get_task.destroy();
                    get_task = null;
                    delete_file(popuptrigger);
                }
            });
            // Connect to widget signals
            reset_editlayoutname.clicked.connect(()=> {
                editlayoutname_entry.set_text(last_layoutname);
            });
            addtaskbutton.clicked.connect(()=> {
                call_dialog(last_layoutname, "", true);
                //  get_task.set_skip_taskbar_hint();
            });
            editlayoutbutton_done.clicked.connect(()=> {
                // editlayoutname_entry should have set_sensitive check!!
                string edited_layoutname = editlayoutname_entry.get_text();
                if (edited_layoutname != last_layoutname) {
                    change_display_name(
                        edited_layoutname, null, combine_pathsteps(last_layoutname)
                    );
                }
                change_page("picklayout", addlayout_box);
                editlayoutname_entry.set_text("");
                layoutname_entry.set_text("");
            });
            addbutton.clicked.connect(() => {
                foreach (Widget w in tasklist_scrolledwindow.get_children()) {
                    w.destroy();
                }
                change_page("newlayout", newlayout_box);
                layoutname_entry.grab_focus();
            });
            cancel_newlayoutbutton.clicked.connect(() => {
                change_page("picklayout", addlayout_box);
                mastergrid.show_all();
            });
            string newlayout_name = "";
            editlayoutname_entry.changed.connect(()=> {
                if (last_layoutname == editlayoutname_entry.get_text()) {
                    editlayoutbutton_done.set_sensitive(true);
                }
                else {
                    set_applybutton_sensitive(
                        editlayoutbutton_done, editlayoutname_entry, "", true
                    );
                }
            });
            layoutname_entry.changed.connect(()=> {
                set_applybutton_sensitive(
                    apply_newlayoutbutton, layoutname_entry, ""
                );
            });
            apply_newlayoutbutton.clicked.connect(() => {
                newlayout_name = layoutname_entry.get_text();
                //no need for an existence- check, it's in the button sensitivity
                File new_layout = File.new_for_path(
                    combine_pathsteps(layoutname_entry.get_text())
                );
                try {
                    new_layout.make_directory();
                }
                catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
                //  editlayoutname_label.set_text("Editing layout:");
                last_layoutname = newlayout_name;
                change_page("editlayout", editlayout_box);
                editlayoutname_entry.set_text(newlayout_name);
            });
            // just trigger entry to force set_sensitive
            set_applybutton_sensitive(
                apply_newlayoutbutton, layoutname_entry, ""
            );
            mastergrid.show_all();
            addlayout_box.show_all();
            this.show_all();
        }

        /**
        * Ensure translations are displayed correctly
        * according to the locale
        */

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

        private void set_applybutton_sensitive(
            Widget targetwidget, Entry entry,
            string subpath, bool check_exist = true
        ) {
            // set a widget active, depending on conditions
            File newfile = File.new_for_path(
                combine_pathsteps(subpath, entry.get_text())
            );
            string new_content = entry.get_text();
            bool[] checks = {new_content.length > 2, !new_content.contains("'")};
            if (check_exist) {
                checks += (!newfile.query_exists());
            }
            bool allis_ok = true;
            foreach (bool test in checks) {
                if (!test) {
                    allis_ok = false;
                    break;
                }
            }
            targetwidget.set_sensitive(allis_ok);
        }

        private Variant? read_taskfile(string path) {
            Variant taskdata = null;
            try {
                taskdata = client.extracttask_fromfile(path);
            }
            catch (Error e) {
                print("Can't read task\n");
            }
            return taskdata;
        }

        private string[] get_monitornames() {
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

        private void set_margins(
            Gtk.Grid grid, int left, int right, int top, int bottom
        ) {
            // lazy margins on a grid
            grid.set_margin_start(left);
            grid.set_margin_end(right);
            grid.set_margin_top(top);
            grid.set_margin_bottom(bottom);
        }

        private void change_page(string newstackname, Gtk.Box newsection) {
            // change stack page + button section
            layoutspopup_stack.set_visible_child_name(newstackname);
            Gtk.Box[] boxes = {addlayout_box, newlayout_box, editlayout_box};
            foreach (Gtk.Box b in boxes) {
                mastergrid.remove(b);
            }
            mastergrid.attach(newsection, 1, 51, 4, 1);
            mastergrid.show_all();
        }

        private void check_validentries(
            Entry name_entry, Entry cmd_entry, Entry wmclass_entry,
            Button apply_button, Button test_button, string layoutname,
            string? taskname = null, bool check_exist = false
        ) {
            /*
            / we have set_applybutton_sensitive(), but for the sake of
            / readability, let's not try to squeeze it into one abstraction.
            / let's have a separate one for the dialog widgets.
            */
            bool sensitive = true;
            // first test: file exists - on new tasks
            if (check_exist && taskname != null) {

                string candidate = combine_pathsteps(
                    layoutname, taskname + ".windowtask"
                );
                if (File.new_for_path(candidate).query_exists()) {
                    sensitive = false;
                }
            }
            // second test: any of the mandatory fields is empty?
            Entry[] entries = {
                name_entry, cmd_entry, wmclass_entry
            };
            foreach (Gtk.Entry en in entries) {
                if (en.get_text() == "") {
                    sensitive = false;
                    break;
                }
            }
            test_button.set_sensitive(sensitive);
            apply_button.set_sensitive(sensitive);
        }

        private void apply_taskedit(
            string candidate_file, bool apply = false, string? path = null
        ) {
            try {
                File targetfile;
                if (apply && path != null) {
                    targetfile = File.new_for_path(path);
                }
                else {
                    string runfile =  "/tmp/".concat(username, "_istestingtask");
                    targetfile = File.new_for_path(runfile);
                }
                if (targetfile.query_exists ()) {
                    delete_file(targetfile);
                }
                // Create a new file with this name
                var file_stream = targetfile.create (FileCreateFlags.REPLACE_DESTINATION);
                var data_stream = new DataOutputStream (file_stream);
                data_stream.put_string (candidate_file);
                if (!apply) {
                    string testcommand = Config.SHUFFLER_DIR + "/run_layout use_testing";
                    run_command(testcommand);
                }
            }
            catch (Error e) {
                stderr.printf ("Error: %s\n", e.message);
            }
        }

        private string combine_pathsteps (string layoutname, string? taskname = null) {
            string task_step = "";
            if (taskname != null) {
                task_step = "/" + taskname;
            }
            return searchpath.concat("/", layoutname, task_step);
        }

        private void read_currentgrid(ShufflerInfoClient client) {
            // on failure, fallback to:
            set_gridxsize = 2;
            set_gridysize = 2;
            try {
                int[] currgrid = client.get_grid();
                set_gridxsize = currgrid[0];
                set_gridysize = currgrid[1];
            }
            catch (Error e) {
                print("Can't read gridsize\n");
            }
        }

        private bool ask_confirm(string action) {
            bool confirm = false;
            ask_confirmdialog = new Dialog();
            ask_confirmdialog.decorated = false;
            ask_confirmdialog.set_transient_for(this);
            ask_confirmdialog.set_modal(true);
            Gtk.Box contentarea = ask_confirmdialog.get_content_area();
            var askgrid = new Gtk.Grid();
            contentarea.pack_start(askgrid, false, false, 0);
            set_margins(askgrid, 20, 20, 20, 20);
            askgrid.attach(new Label(action + "?\t\t"), 0, 0, 2, 1);
            askgrid.attach(new Label("\n"), 0, 1, 1, 1);
            contentarea.orientation = Gtk.Orientation.VERTICAL;
            Box buttonbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Button cancel = new Gtk.Button();
            cancel.label = "No";
            cancel.get_style_context().add_class("suggested-action");
            askgrid.get_style_context().remove_class("horizontal");
            Button go_on = new Gtk.Button();
            go_on.label = "Yes";
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
            return set_forrule;
        }

        private void call_dialog (
            string currlayout, string currtask = "", bool check_exist = false
        ) {
            // tooltips
            string command_tooltip = _("Command to launch window or application (*mandatory)");
            string class_tooltip = _("Window class of the window to be launched (*mandatory)");
            string windowname_tooltip = _("Window name - optional, to distinguish multiple windows of the same application");
            string gridxsize_tooltip = _("Grid size - columns");
            string gridysize_tooltip = _("Grid size - rows");
            string targetpositionx_tooltip = _("Window target position on grid - horizontally");
            string targetpositiony_tooltip = _("Window target position on grid - vertically");
            string xspan_tooltip = _("Window size - columns");
            string yspan_tooltip = _("Window size - rows");
            string monitor_tooltip = _("Target monitor, default is on active monitor");
            string tryexisting_tooltip = _("Try to move an existing window before launching a new instance");
            string workspaces_tooltip = _("Target workspace, default is on active workspace");
            get_task = new Dialog();
            get_task.set_transient_for(this);
            get_task.decorated = false;
            Gtk.Box contentarea = get_task.get_content_area();
            contentarea.orientation = Gtk.Orientation.VERTICAL;
            // mastergrid
            Grid master_grid = new Gtk.Grid();
            set_margins(master_grid, 30, 30, 30, 30);
            contentarea.pack_start(master_grid, false, false, 0);
            Gtk.Label curr_tasksubject = new Gtk.Label(_("Task name") + ": ");
            curr_tasksubject.xalign = 0;
            set_widgetstyle(curr_tasksubject, "justbold");
            //  master_grid.attach(curr_tasksubject, 1, 1, 1, 1);
            Gtk.Entry taskname_entry = new Gtk.Entry();
            // get taskname
            taskname_entry.set_text(currtask);
            master_grid.attach(curr_tasksubject, 1, 1, 1, 1);
            master_grid.attach(new Label(""), 2, 1, 1, 1);
            master_grid.attach(taskname_entry, 3, 1, 1, 1);
            master_grid.attach(new Label("\n"), 1, 2, 1, 1);
            // 1. APPLICATION FRAME
            Frame applicationframe = new Gtk.Frame(_("Application"));
            var app_label = applicationframe.get_label_widget();
            set_widgetstyle(app_label, "justbold");
            master_grid.attach(applicationframe, 1, 10, 10, 1);
            // application grid
            Grid applicationgrid = new Gtk.Grid();
            set_margins(applicationgrid, 20, 20, 20, 20);
            applicationgrid.set_row_spacing(4);
            // - command
            Label exec_label = new Label(_("Command*"));
            Entry exec_entry = new Entry();
            exec_entry.set_text("");
            exec_entry.set_size_request(250, 10);
            exec_entry.set_tooltip_text(command_tooltip);
            applicationgrid.attach(exec_label, 1, 3, 1, 1);
            applicationgrid.attach(new Label("\t\t"), 2, 3, 1, 1);
            applicationgrid.attach(exec_entry, 3, 3, 20, 1);
            // - wmclass
            Label wmclass_label = new Label(_("WM class group*"));
            wmclass_entry = new Entry();
            wmclass_entry.set_tooltip_text(class_tooltip);
            wmclass_entry.set_text("");
            wmclass_entry.set_size_request(250, 10);
            wmclass_entry.set_placeholder_text(_("Click a window to fetch"));
            applicationgrid.attach(wmclass_label, 1, 4, 1, 1);
            applicationgrid.attach(new Label("\t\t"), 2, 4, 1, 1);
            applicationgrid.attach(wmclass_entry, 3, 4, 20, 1);
            // - wname
            Label wname_label = new Label(_("Window name"));
            Entry wname_entry = new Entry();
            wname_entry.set_tooltip_text(windowname_tooltip);
            wname_entry.set_text("");
            wname_entry.set_size_request(250, 10);
            applicationgrid.attach(wname_label, 1, 5, 1, 1);
            applicationgrid.attach(new Label("\t\t"), 2, 5, 1, 1);
            applicationgrid.attach(wname_entry, 3, 5, 20, 1);
            applicationframe.add(applicationgrid);
            master_grid.attach(new Label(""), 1, 11, 1, 1);
            // 2. GEOMETRY FRAME
            Frame geometryframe = new Gtk.Frame(_("Window position & size"));
            var geo_label = geometryframe.get_label_widget();
            set_widgetstyle(geo_label, "justbold");
            master_grid.attach(geometryframe, 1, 30, 10, 1);
            // gemetry grid
            Grid geogrid = new Gtk.Grid();
            set_margins(geogrid, 20, 20, 20, 20);
            geogrid.set_row_spacing(0);
            // grid cols / rows
            Label grid_size_label = new Label(_("Grid size; columns & rows"));
            geogrid.attach(grid_size_label, 1, 10, 1, 1);
            geogrid.attach(new Label("\t"), 2, 10, 1, 1);
            // get current gridsize
            read_currentgrid(client);
            OwnSpinButton grid_xsize_spin = new OwnSpinButton("hor", 1, 10);
            grid_xsize_spin.set_tooltip_text(gridxsize_tooltip);
            grid_xsize_spin.set_value(set_gridxsize);
            OwnSpinButton grid_ysize_spin = new OwnSpinButton("vert", 1, 10);
            grid_ysize_spin.set_tooltip_text(gridysize_tooltip);
            grid_ysize_spin.set_value(set_gridysize);
            Box gridsize_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            gridsize_box.pack_start(grid_xsize_spin, false, false, 0);
            gridsize_box.pack_start(new Label("\t"), false, false, 0);
            gridsize_box.pack_start(grid_ysize_spin, false, false, 0);
            geogrid.attach(gridsize_box, 3, 10, 1, 1);
            geogrid.attach(new Label(""), 1, 11, 1, 1);
            // window position
            Label winpos_label = new Label(_("Target window position, x / y"));
            geogrid.attach(winpos_label, 1, 12, 1, 1);
            geogrid.attach(new Label("\t"), 2, 12, 1, 1);
            OwnSpinButton xpos_spin = new OwnSpinButton("hor", 0, 10);
            xpos_spin.set_tooltip_text(targetpositionx_tooltip);
            xpos_spin.set_value(0);
            OwnSpinButton ypos_spin = new OwnSpinButton("vert", 0, 10);
            ypos_spin.set_tooltip_text(targetpositiony_tooltip);
            ypos_spin.set_value(0);
            Box winpos_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            winpos_box.pack_start(xpos_spin, false, false, 0);
            winpos_box.pack_start(new Label("\t"), false, false, 0);
            winpos_box.pack_start(ypos_spin, false, false, 0);
            geogrid.attach(winpos_box, 3, 12, 1, 1);
            geogrid.attach(new Label(""), 1, 13, 1, 1);
            // window span
            Label cellspan_label = new Label(_("Window cell span, hor / vert"));
            geogrid.attach(cellspan_label, 1, 14, 1, 1);
            geogrid.attach(new Label("\t"), 2, 14, 1, 1);
            OwnSpinButton yspan_spin = new OwnSpinButton("vert", 1, 10);
            yspan_spin.set_tooltip_text(yspan_tooltip);
            yspan_spin.set_value(1);
            OwnSpinButton xspan_spin = new OwnSpinButton("hor", 1, 10);
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
            Gtk.Frame miscframe = new Gtk.Frame(_("Miscellaneous"));
            var misc_label = miscframe.get_label_widget();
            set_widgetstyle(misc_label, "justbold");
            master_grid.attach(miscframe, 1, 50, 10, 1);
            Grid miscgrid = new Gtk.Grid();
            set_margins(miscgrid, 20, 20, 20, 20);
            miscgrid.set_row_spacing(4);
            miscframe.add(miscgrid);
            // targetmonitor
            Label targetmonitor_label = new Label(_("Target monitor"));
            miscgrid.attach(targetmonitor_label, 1, 1, 1, 1);
            ComboBoxText screendropdown = new ComboBoxText();
            screendropdown.set_tooltip_text(monitor_tooltip);

            string[] monlist = {default_set};
            screendropdown.append_text(default_set);
            screendropdown.active = 0;
            string[] mons = get_monitornames();
            foreach (string m in mons) {
                screendropdown.append_text(m);
                monlist += m;
            }
            miscgrid.attach(new Label("\t"), 2, 1, 1, 1);
            miscgrid.attach(screendropdown, 3, 1, 1, 1);
            // targetworkspace
            Label targetworkspace_label = new Label(_("Target workspace"));
            miscgrid.attach(targetworkspace_label, 1, 2, 1, 1);
            ComboBoxText workspacedropdown = new ComboBoxText();
            workspacedropdown.set_tooltip_text(workspaces_tooltip);
            string[] allspaceslist = {default_set};
            workspacedropdown.append_text(default_set);
            workspacedropdown.active = 0;
            int n_ws = 1;
            try {
                n_ws = client.get_numberof_workspaces();
                for (int i=0; i<n_ws; i++) {
                    string newitem = (i + 1).to_string();
                    allspaceslist += newitem;
                    workspacedropdown.append_text(newitem);
                }
            }
            catch (Error e) {
                error ("%s", e.message);
            }
            miscgrid.attach(new Label("\t"), 2, 2, 1, 1);
            miscgrid.attach(workspacedropdown, 3, 2, 1, 1);
            // TryExisting
            Label tryexisting_label = new Label(("Try to move existing window"));
            miscgrid.attach(tryexisting_label, 1, 3, 1, 1);
            miscgrid.attach(new Label("\t"), 2, 3, 1, 1);
            CheckButton tryexist_checkbox = new Gtk.CheckButton();
            tryexist_checkbox.set_tooltip_text(tryexisting_tooltip);
            miscgrid.attach(tryexist_checkbox, 3, 3, 1, 1);
            Label[] all_labels = {
                exec_label, wmclass_label, wname_label,
                grid_size_label, winpos_label, cellspan_label,
                targetmonitor_label, targetworkspace_label, tryexisting_label
            };
            foreach (Label l in all_labels) {
                l.xalign = 0;
            }
            // test section
            master_grid.attach(new Label(""), 1, 100, 1, 1);
            master_grid.get_style_context().remove_class("horizontal");
            Gtk.Box testaction_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            master_grid.attach(testaction_box, 1, 101, 2, 1);
            Button testwindowtask_button = new Gtk.Button();
            testwindowtask_button.label = _("Test");
            testaction_box.pack_start(testwindowtask_button, false, false, 0);
            //
            Gtk.Box dialogaction_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Button applytask_button = new Gtk.Button();
            applytask_button.label = _("Done");
            applytask_button.set_size_request(90, 10);
            Button canceltask_button = new Gtk.Button();
            canceltask_button.label = _("Cancel");
            canceltask_button.set_size_request(90, 10);
            canceltask_button.clicked.connect(()=> {
                get_task.destroy();
                get_task = null;

            });
            dialogaction_box.pack_end(applytask_button, false, false, 2);
            dialogaction_box.pack_end(canceltask_button, false, false, 2);
            master_grid.attach(dialogaction_box, 1, 110, 50, 1);
            //  master_grid.attach(new Label(""), 1, 150, 1, 1);

            Gtk.Entry[] trythese_beforeyoubuy = {
                exec_entry, wmclass_entry, taskname_entry
            };
            // make method!
            check_validentries(
                taskname_entry, exec_entry, wmclass_entry,
                applytask_button, testwindowtask_button,
                currlayout, taskname_entry.get_text(), check_exist
            );
            foreach (Entry en in trythese_beforeyoubuy) {
                en.changed.connect(()=> {
                    check_validentries(
                        taskname_entry, exec_entry, wmclass_entry,
                        applytask_button, testwindowtask_button,
                        currlayout, taskname_entry.get_text(), check_exist
                    );
                });
            }
            if (currtask != "") {
                // populate entries
                string fullpath = combine_pathsteps(currlayout, currtask +  ".windowtask");
                Variant currtask_data = read_taskfile(fullpath);
                exec_entry.set_text((string)currtask_data.get_child_value(0));
                wmclass_entry.set_text((string)currtask_data.get_child_value(7));
                wname_entry.set_text((string)currtask_data.get_child_value(8));
                grid_xsize_spin.set_value(int.parse((string)currtask_data.get_child_value(3)));
                grid_ysize_spin.set_value(int.parse((string)currtask_data.get_child_value(4)));
                xpos_spin.set_value(int.parse((string)currtask_data.get_child_value(1)));
                ypos_spin.set_value(int.parse((string)currtask_data.get_child_value(2)));
                xspan_spin.set_value(int.parse((string)currtask_data.get_child_value(5)));
                yspan_spin.set_value(int.parse((string)currtask_data.get_child_value(6)));
                string set_monitor = (string)currtask_data.get_child_value(9);
                if (set_monitor == "") {
                    set_monitor = default_set;
                }
                int set_monitorindex = string_inlist(set_monitor, monlist);
                if (set_monitor != "" && set_monitorindex == -1) {
                    screendropdown.append_text(set_monitor);
                    monlist += set_monitor;
                    // then renew the index, set monitor needs to be in list
                    set_monitorindex = string_inlist(set_monitor, monlist);
                }
                screendropdown.active = set_monitorindex;
                string set_workspace = get_value_forrule((string)currtask_data.get_child_value(11));
                int set_workspaceindex = string_inlist(set_workspace, allspaceslist);
                if (set_workspaceindex == -1) {
                    // if workspace does not exist, still keep its set value
                    allspaceslist += set_workspace;
                    workspacedropdown.append_text(set_workspace);
                    // and renew index
                    set_workspaceindex = string_inlist(set_workspace, allspaceslist);
                }
                workspacedropdown.active = set_workspaceindex;
                tryexist_checkbox.set_active(
                    (string)currtask_data.get_child_value(10) == "true"
                );
            }
            OwnSpinButton[] allspins = {
                grid_xsize_spin, grid_ysize_spin, xpos_spin, ypos_spin, xspan_spin, yspan_spin
            };
            foreach (OwnSpinButton spin in allspins) {
                spin.spinvalue.changed.connect(()=> {
                    set_spincolor(allspins);
                });
            };
            // optimize please
            testwindowtask_button.clicked.connect(()=> {
                string candidate_content = create_filecontent(
                    exec_entry, xpos_spin, ypos_spin, grid_xsize_spin,
                    grid_ysize_spin, xspan_spin, yspan_spin, wmclass_entry,
                    wname_entry, screendropdown, workspacedropdown,
                    tryexist_checkbox
                );
                apply_taskedit(candidate_content);
            });
            applytask_button.clicked.connect(()=> {
                string candidate_content = create_filecontent(
                    exec_entry, xpos_spin, ypos_spin, grid_xsize_spin,
                    grid_ysize_spin, xspan_spin, yspan_spin, wmclass_entry,
                    wname_entry, screendropdown, workspacedropdown,
                    tryexist_checkbox
                );
                string newtaskname = taskname_entry.get_text();
                if (currtask != "" && newtaskname != currtask) {
                    change_display_name(
                        newtaskname.concat(".windowtask"), null,
                        combine_pathsteps(currlayout, currtask + ".windowtask")
                    );
                }
                apply_taskedit(
                    candidate_content, true,
                    combine_pathsteps(
                        currlayout,
                        taskname_entry.get_text() + ".windowtask"
                ));
                update_stackgrid_editlayout(currlayout);
                get_task.destroy();
                get_task = null;
            });
            contentarea.show_all();
            get_task.run();
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
        }

        private void change_display_name(
            string newname, File? file = null, string? path = null
        ) {
            File? subject = null;
            if (file != null) {
                subject = file;
            }
            else if (path != null) {
                subject = File.new_for_path(path);
            }
            if (subject != null) {
                try {
                    subject.set_display_name(newname);
                }
                catch (Error e) {
                    print(@"Cannot rename file: $newname\n");
                }
            }
        }

        private string create_filecontent(
            Entry exec_entry, OwnSpinButton xpos_spin, OwnSpinButton ypos_spin,
            OwnSpinButton grid_xsize_spin, OwnSpinButton grid_ysize_spin,
            OwnSpinButton xspan_spin, OwnSpinButton yspan_spin, Entry wmclass_entry,
            Entry wname_entry, ComboBoxText screendropdown,
            ComboBoxText workspacedropdown, ToggleButton tryexist_checkbox
        ) {
            // creates the content of a task file from the fields
            bool try_isset = tryexist_checkbox.get_active();
            int curr_xpos = (int)xpos_spin.get_value();
            int curr_ypos = (int)ypos_spin.get_value();
            int curr_cols = grid_xsize_spin.get_value();
            int curr_rows = grid_ysize_spin.get_value();
            int curr_xspan = (int)xspan_spin.get_value();
            int curr_yspan = (int)yspan_spin.get_value();
            string file_ws = get_value_forrule(workspacedropdown.get_active_text(), true);
            string wsline = "";
            if (file_ws != "") {
                wsline = "\nTargetWorkspace=" + file_ws;
            }

            string monitorline = "";
            string newset_monitor = screendropdown.get_active_text();
            if (newset_monitor != default_set && newset_monitor != "") {
                monitorline = "\nMonitor=" + newset_monitor;
            }
            return "Exec=" + exec_entry.get_text().concat(
                "\nXPosition=" + @"$curr_xpos", "\nYPosition=" + @"$curr_ypos",
                "\nCols=" + @"$curr_cols", "\nRows=" + @"$curr_rows",
                "\nXSpan=" + @"$curr_xspan", "\nYSpan=" + @"$curr_yspan",
                "\nWMClass=" + wmclass_entry.get_text(),
                "\nWName=" + wname_entry.get_text(),
                monitorline, wsline,
                "\nTryExisting=" + @"$try_isset"
            );
        }

        private string[] get_layouttasks (string layoutsubject) {
            string[] newtasks = {};
            string task_searchpath = combine_pathsteps(layoutsubject);
            string? filename = null;
            try {
                // walk through relevant files
                var dr = Dir.open(task_searchpath);
                while ((filename = dr.read_name()) != null) {
                    string filepath = task_searchpath.concat("/", filename); // found file
                    if (
                        FileUtils.test (filepath, FileTest.IS_REGULAR) &&
                        filename.contains(".windowtask")
                    ) { // see what we have
                        newtasks += filename;
                    }
                }
            }
            catch (Error e) {
                error ("%s", e.message);
            }
            return newtasks;
        }

        private void update_stackgrid_editlayout(string layoutsubject) {
            // is this causing issues?
            string[] newtasks = get_layouttasks(layoutsubject);
            foreach (var widget in tasklist_scrolledwindow.get_children()) {
                widget.destroy();
            }
            Gtk.Grid tasklist_scrolledlistgrid = new Gtk.Grid();
            tasklist_scrolledwindow.add(tasklist_scrolledlistgrid);
            int b_index = 0;
            foreach (string s in newtasks) {
                Gtk.Button taskbutton = new Gtk.Button();
                taskbutton.set_relief(Gtk.ReliefStyle.NONE);
                taskbutton.set_size_request(300, 45);
                taskbutton.label = s.replace(".windowtask", "");
                // optimize please! multiple similar occasions
                foreach (Widget ch in taskbutton.get_children()) {
                    ch.set_halign(Gtk.Align.START);
                };
                tasklist_scrolledlistgrid.attach(taskbutton, 0, b_index, 1, 1);
                // edit / delete buttons here
                Gtk.Button taskeditbutton = new Button.from_icon_name(
                    "document-edit-symbolic", Gtk.IconSize.BUTTON
                );
                Gtk.Button taskdeletebutton = new Button.from_icon_name(
                    "user-trash-symbolic", Gtk.IconSize.BUTTON
                );
                taskdeletebutton.set_size_request(45, 45);
                taskdeletebutton.set_can_focus(false);
                taskdeletebutton.set_relief(Gtk.ReliefStyle.NONE);
                tasklist_scrolledlistgrid.attach(taskdeletebutton, 2, b_index, 1, 1);
                taskeditbutton.set_size_request(45, 45);
                taskeditbutton.set_can_focus(false);
                taskeditbutton.set_relief(Gtk.ReliefStyle.NONE);
                tasklist_scrolledlistgrid.attach(taskeditbutton, 1, b_index, 1, 1);
                taskdeletebutton.clicked.connect(()=> {
                    if (ask_confirm(@"Delete task: $s")) {
                        File todelete = File.new_for_path(
                            searchpath.concat("/", layoutsubject, "/", s)
                        );
                        delete_file(todelete);
                        update_stackgrid_editlayout(layoutsubject);
                    }
                });
                taskbutton.clicked.connect(()=> {
                    string exec_path = Config.SHUFFLER_DIR + "/run_layout";
                    // keep for quick compile & test
                    // string exec_path = "/lib/budgie-window-shuffler/run_layout";
                    string testcommand = exec_path.concat(
                        " use_testing ", "'", "/", layoutsubject, "/", s, "'"
                    );
                    run_command(testcommand);
                });
                taskeditbutton.clicked.connect(()=> {
                    call_dialog(
                        layoutsubject, s.replace(".windowtask", ""), false
                    );
                });
                b_index += 1;
            }
            tasklist_scrolledlistgrid.show_all();
        }

        private void update_layoutgrid() {
            string[] newlayouts = {};
            try {
                var dr = Dir.open(searchpath);
                string? dirname = null;
                // walk through relevant files
                while ((dirname = dr.read_name()) != null) {
                    string layoutpath = combine_pathsteps(dirname);
                    if (FileUtils.test (layoutpath, FileTest.IS_DIR)) {
                        newlayouts += dirname;
                    }
                }
            }
            catch (Error e) {
                error ("%s", e.message);
            }
            foreach (var widget in layoutlist_scrolledwindow_grid.get_children()) {
                widget.destroy();
            }
            int row_int = 1;
            foreach (string s in newlayouts) {
                // optimize please
                Gtk.Button newlauyoutbutton = new Gtk.Button.with_label(s);
                foreach (Widget ch in newlauyoutbutton.get_children()) {
                    ch.set_halign(Gtk.Align.START);
                };
                newlauyoutbutton.set_relief(Gtk.ReliefStyle.NONE);
                Gtk.Button neweditbutton = new Button.from_icon_name(
                    "document-edit-symbolic", Gtk.IconSize.BUTTON
                );
                neweditbutton.set_size_request(45, 45);
                neweditbutton.clicked.connect(()=> {
                    update_stackgrid_editlayout(s);
                    mastergrid.remove(addlayout_box);
                    mastergrid.remove(newlayout_box);
                    layoutspopup_stack.set_visible_child_name("editlayout");
                    editlayoutname_entry.set_text(s);
                    mastergrid.attach(editlayout_box, 1, 51, 4, 1);
                    editlayoutbutton_done.set_sensitive(true);
                    last_layoutname = s;
                    mastergrid.show_all();

                });
                newlauyoutbutton.set_size_request(300, 45);
                set_widgetstyle(newlauyoutbutton, "currbutton");
                neweditbutton.set_can_focus(false);
                neweditbutton.set_relief(Gtk.ReliefStyle.NONE);
                Gtk.Button newdeletebutton = new Button.from_icon_name(
                    "user-trash-symbolic", Gtk.IconSize.BUTTON
                );
                newdeletebutton.set_size_request(45, 45);
                newdeletebutton.set_can_focus(false);
                newdeletebutton.set_relief(Gtk.ReliefStyle.NONE);
                newdeletebutton.clicked.connect(()=> {
                    if (ask_confirm(@"Delete layout: $s")) {
                        File todelete = File.new_for_path(combine_pathsteps(s));
                        string[] child_items = get_layouttasks(s);
                        foreach (string sub in child_items) {
                            string path = combine_pathsteps(s, sub);
                            delete_file(null, path);
                        }
                        delete_file(todelete);
                    }
                });
                layoutlist_scrolledwindow_grid.attach(newlauyoutbutton, 1, row_int, 1, 1);
                layoutlist_scrolledwindow_grid.attach(neweditbutton, 2, row_int, 1, 1);
                layoutlist_scrolledwindow_grid.attach(newdeletebutton, 3, row_int, 1, 1);
                newlauyoutbutton.set_size_request(300, 45);
                newlauyoutbutton.clicked.connect(run_layout);
                row_int += 1;
            }
            layoutlist_scrolledwindow_grid.show_all();
        }
    }


    class OwnSpinButton : Gtk.Grid{

        public Gtk.Entry spinvalue;
        Gtk.Button up;
        Gtk.Button down;

        public OwnSpinButton(
           string orientation, int min = 0, int max = 10
        ) {
            this.set_column_spacing(0);
            spinvalue = new Gtk.Entry();
            spinvalue.set_editable(false);
            spinvalue.xalign = (float)0.50;
            spinvalue.set_text("0");
            spinvalue.set_width_chars(2);
            spinvalue.set_max_width_chars(2);
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
        }

        public int get_value() {
            return int.parse(spinvalue.get_text());
        }

        public void set_value(int newvalue) {
            spinvalue.set_text(@"$newvalue");
        }

        public void set_warning_color(bool warning = false) {
            if (warning == true) {
                set_widgetstyle(spinvalue, "red_text");
            }
            else {
                set_widgetstyle(spinvalue, "red_text", true);
            }
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

    private void delete_file(File? file = null, string? path = null) {
        File? subject = null;
        if (file != null) {
            subject = file;
        }
        else if (path != null) {
            subject = File.new_for_path(path);
        }
        if (subject != null) {
            try {
                subject.delete();
            }
            catch (Error e) {
                print("Cannot delete file (does not exist)\n");
            }
        }
    }

    private void run_layout(Button button) {
        string buttontext = button.get_label();
        string cmd = "/usr/lib/budgie-window-shuffler/".concat(
            "run_layout '", buttontext, "'"
        );
        run_command(cmd);
        delete_file(popuptrigger);
        layouts.destroy();
        layouts = null;
    }

    private void run_command (string cmd) {
        // well, seems clear
        try {
            Process.spawn_command_line_async(cmd);
        }
        catch (GLib.SpawnError err) {
            // not much use for any action
        }
    }

    private string create_dirs_file (string subpath, bool ishome = false) {
        // defines, and if needed, creates directory for layouts
        homedir = "";
        if (ishome) {
            homedir = Environment.get_home_dir();
        }
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

    public void toggle_popup(File popuptrigger) {
        if (
            popuptrigger.query_exists() &&
            layouts == null
        ) {
            bool fromcontrol = readfile(triggerfpath) == "fromcontrol";
            layouts = new PopupWindow(fromcontrol);
        }
        else if (
            !popuptrigger.query_exists() &&
            layouts != null
        ) {
            layouts.destroy();
            layouts = null;
        }
    }

    private uint get_now() {
        // get timestamp
        return Gdk.X11.get_server_time(timestamp_window);
    }

    private void makesure_offocus () {
        foreach (Wnck.Window w in wnck_scr.get_windows()) {
            if (w.get_name().down() == "layouts_popup") {
                w.activate(get_now());
                break;
            }
            else if (w.get_name() == "LayoutsPopup") {
                w.activate(get_now());
            }
        }
    }

    private void set_widgetstyle(Widget w, string css_style, bool remove = false) {
        var widgets_stylecontext = w.get_style_context();
        if (!remove) {
            widgets_stylecontext.add_class(css_style);
        }
        else {
            widgets_stylecontext.remove_class(css_style);
        }
    }

    private string readfile (string path) {
        try {
            string read;
            FileUtils.get_contents (path, out read);
            return read;
        } catch (FileError error) {
            return "";
        }
    }

    public static int main(string[] args) {
        try {
            client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
            return 1;
        }
        Gtk.init(ref args);
        searchpath = create_dirs_file(
            ".config/budgie-extras/shuffler/layouts", true
        );
        username = Environment.get_user_name();
        string triggerpath = create_dirs_file(
            "/tmp/".concat(username, "_shufflertriggers")
        );
        // watch triggerfile
        // containing dir
        File triggerdir = File.new_for_path(triggerpath);
        // triggerfilepath
        triggerfpath = triggerpath.concat("/layoutspopup");
        popuptrigger = File.new_for_path(triggerfpath);
        FileMonitor? triggerpath_monitor = null;
        try {
            triggerpath_monitor = triggerdir.monitor(
                FileMonitorFlags.NONE, null
            );
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
        if (triggerpath_monitor != null) {
            triggerpath_monitor.changed.connect(() => {
                toggle_popup(popuptrigger);
                Timeout.add(50, ()=> {
                    makesure_offocus();
                    return false;
                });
            });
        }
        // X11 stuff
        unowned X.Window xwindow = Gdk.X11.get_default_root_xwindow();
        unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
        Gdk.X11.Display display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
        timestamp_window = new Gdk.X11.Window.foreign_for_display(display, xwindow);
        wnck_scr = Wnck.Screen.get_default();
        Gtk.main();
        return 0;
    }
}