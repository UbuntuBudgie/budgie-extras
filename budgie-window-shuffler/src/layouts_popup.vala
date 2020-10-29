using Gtk;
using Wnck;
using Gdk.X11;
using Gdk;

// todo: be consequent in var /no var/ widget naming - is ok
// optimize set style & alignment, its all over the place - done
// optimize button switch - done
// make path combination a method ! -done
// use paths from Config - done
// add tooltips
// translation

namespace LayoutsPopup {

    ShufflerInfoClient? client;
    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]
    interface ShufflerInfoClient : Object {
        public abstract Variant extracttask_fromfile (string path) throws Error;
    }
    // see what can be de-globalized from below please - done
    string searchpath;
    Gtk.Window? layouts;
    File popuptrigger;
    Gdk.X11.Window timestamp_window;
    Wnck.Screen wnck_scr;
    Gtk.Dialog? get_task;
    string username;
    string homedir;


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

        public PopupWindow() {
            // css stuff

            string layoutss_stylecss = """
            .header {
                font-weight: bold;
                margin-bottom: 10px;
            }
            .secondheader {
                font-weight: bold;
                margin-bottom: 10px;
                margin-top: 10px;
            }
            .justbold {
                font-weight: bold;
            }
            .entries {
                margin-bottom: 2px;
                margin-top: 2px;
            }
            .windowcolor {
                background-color: black;
            }
            """;

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
            // keep window above
            wnck_scr.active_window_changed.connect( ()=> {
                if (wmclass_entry != null && wmclass_entry.is_focus) {
                    Wnck.Window newactive = wnck_scr.get_active_window();
                    string classname = newactive.get_class_group_name().down();
                    if (
                        newactive.get_window_type() == Wnck.WindowType.NORMAL &&
                        classname != "layouts_popup"
                    ) {
                        if (get_task != null) {
                            wmclass_entry.set_text(classname);
                        }
                    }
                }
                makesure_offocus();
            });

            //  set_widgetstyle(this, "windowcolor");

            // STACK
            layoutspopup_stack = new Stack();
            layoutspopup_stack.set_transition_type(
                Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
            );
            // MASTERGRID (includes stack)
            mastergrid = new Grid();
            mastergrid.attach(new Label(""), 1, 40, 1, 1);
            // corners spacing of mastergrid
            set_cornerspacing(mastergrid);
            mastergrid.attach(layoutspopup_stack, 1, 1, 1, 1);
            this.add(mastergrid);
            // 1. PICK LAYOUT GRID
            stackgrid_layoutlist = new Grid(); // dynamically updated
            Gtk.Label layout_header = new Gtk.Label("Layouts");
            stackgrid_layoutlist.attach(layout_header, 1, 1, 5, 1);
            layout_header.xalign = 0;
            set_widgetstyle(layout_header, "header");
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
            addbutton.label = "Add New";
            addbutton.set_size_request(120, 10);
            addlayout_box.pack_end(addbutton, false, false, 2);
            // 2. NEW LAYOUTS GRID
            stackgrid_newlayout = new Grid();
            Label layoutname_label = new Label("New layout name");
            layoutname_label.xalign = 0;
            set_widgetstyle(layoutname_label, "header");
            stackgrid_newlayout.attach(layoutname_label, 0, 0, 1, 1);
            Entry layoutname_entry = new Entry();
            layoutname_entry.set_size_request(300, 10);
            stackgrid_newlayout.attach(layoutname_entry, 0, 1, 1, 1);
            // buttons of mastergrid, corresponcing to stack "newlayout"
            newlayout_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Gtk.Button apply_newlayoutbutton = new Gtk.Button();
            apply_newlayoutbutton.label = "Create";
            apply_newlayoutbutton.set_size_request(120, 10);
            newlayout_box.pack_end(apply_newlayoutbutton, false, false, 2);
            Gtk.Button cancel_newlayoutbutton = new Gtk.Button();
            cancel_newlayoutbutton.label = "Cancel";
            cancel_newlayoutbutton.set_size_request(120, 10);
            newlayout_box.pack_end(cancel_newlayoutbutton, false, false, 2);
            // 3. EDIT LAYOUT GRID
            stackgrid_editlayout = new Grid();
            Label editlayoutname_label = new Label("Edit Layout:");
            editlayoutname_label.xalign = 0;
            set_widgetstyle(editlayoutname_label, "secondheader");
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
            Label tasklist_label = new Label("Window tasks" + ":");
            set_widgetstyle(tasklist_label, "secondheader");
            tasklist_label.xalign = 0;
            stackgrid_editlayout.attach(tasklist_label, 0, 2, 1, 1);
            tasklist_scrolledwindow = new ScrolledWindow(null, null);
            tasklist_scrolledwindow.set_size_request(430, 180);
            stackgrid_editlayout.attach(tasklist_scrolledwindow, 0, 10, 1, 1);
            // buttons of mastergrid, corresponcing to stack "editlayout"
            editlayout_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Gtk.Button editlayoutbutton_done = new Gtk.Button();
            editlayoutbutton_done.set_size_request(120, 10);
            editlayoutbutton_done.label = "Done";
            editlayout_box.pack_end(editlayoutbutton_done, false, false, 2);
            Gtk.Button addtaskbutton = new Gtk.Button();
            addtaskbutton.set_size_request(120, 10);
            addtaskbutton.label = "Add task";
            editlayout_box.pack_end(addtaskbutton, false, false, 2);
            // so, let's add stuff to stack
            layoutspopup_stack.add_named(stackgrid_layoutlist, "picklayout");
            layoutspopup_stack.add_named(stackgrid_newlayout, "newlayout");
            layoutspopup_stack.add_named(stackgrid_editlayout, "editlayout");
            // general window stuff
            this.decorated = false;
            this.title = "LayoutsPopup"; // don't change, it's identification
            this.set_skip_taskbar_hint(true);
            this.set_position(Gtk.WindowPosition.CENTER_ALWAYS);
            this.destroy.connect(() => {
                if (get_task != null) {
                    get_task.destroy();
                    delete_file(popuptrigger);
                }
            });
            // Connect to widget signals
            reset_editlayoutname.clicked.connect(()=> {
                editlayoutname_entry.set_text(last_layoutname);
            });
            // what is happening?
            addtaskbutton.clicked.connect(()=> {
                call_dialog(editlayoutname_entry.get_text(), "", true);
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
                        editlayoutbutton_done, editlayoutname_entry, "", false
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
                editlayoutname_label.set_text("Editing layout:");
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

        private void set_cornerspacing (Gtk.Grid grid) {
            int[,] corners = {{0, 0}, {100, 0}, {0, 100}, {100, 100}};
            for (int i=0; i<4; i++) {
                grid.attach(new Label("\t"), corners[i, 0], corners[i, 1], 1, 1);
            }
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

        private void change_page(string newstackname, Gtk.Box newsection) {
            layoutspopup_stack.set_visible_child_name(newstackname);
            Gtk.Box[] boxes = {addlayout_box, newlayout_box, editlayout_box};
            foreach (Gtk.Box b in boxes) {
                mastergrid.remove(b);
            }
            mastergrid.attach(newsection, 1, 51, 4, 1);
            mastergrid.show_all();
        }

        private void set_widgetstyle(Widget w, string css_style) {
            var widgets_stylecontext = w.get_style_context();
            widgets_stylecontext.add_class(css_style);
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
                    //  string testcommand = Config.SHUFFLER_DIR + "/run_layout use_testing";
                    // keep for quick compile & test
                    string testcommand = "/lib/budgie-window-shuffler/run_layout use_testing";
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

        private void call_dialog (
            string currlayout, string currtask = "", bool check_exist = false
        ) {

            // tooltips
            string command_tooltip = "Command to launch window or application (*mandatory)";
            string class_tooltip = "Window class of the window to be launched (*mandatory)";
            string windowname_tooltip = "Window name - optional, to distinguish multiple windows of the same application";
            //  string


            // todo: make numbers smart; only possible settings
            get_task = new Dialog();
            get_task.decorated = false;
            Gtk.Box contentarea = get_task.get_content_area();
            contentarea.orientation = Gtk.Orientation.VERTICAL;
            Grid addtask_grid = new Gtk.Grid();
            addtask_grid.attach(new Label("\t\t"), 2, 0, 1, 1);
            addtask_grid.set_row_spacing(4);
            set_cornerspacing(addtask_grid);
            contentarea.pack_start(addtask_grid, false, false, 0);
            Gtk.Label curr_tasksubject = new Gtk.Label("Task name" + ": ");
            curr_tasksubject.xalign = 0;
            set_widgetstyle(curr_tasksubject, "justbold");
            addtask_grid.attach(curr_tasksubject, 1, 1, 1, 1);
            Gtk.Entry taskname_entry = new Gtk.Entry();
            // get taskname
            taskname_entry.set_text(currtask);
            addtask_grid.attach(taskname_entry, 3, 1, 20 , 1);
            // app properties header
            Label launchsection_header = new Label("Application properties");
            addtask_grid.attach(launchsection_header, 1, 2, 1, 1);
            // command
            Label exec_label = new Label("Command*");
            addtask_grid.attach(exec_label, 1, 3, 1, 1);
            Entry exec_entry = new Entry();
            exec_entry.set_tooltip_text("Command to launch the window or application");
            exec_entry.set_text("");
            exec_entry.set_size_request(230, 10);
            addtask_grid.attach(exec_entry, 3, 3, 20, 1);
            // wmclass
            Label wmclass_label = new Label("WM class group*");
            addtask_grid.attach(wmclass_label, 1, 4, 1, 1);
            wmclass_entry = new Entry();
            wmclass_entry.set_text("");
            wmclass_entry.set_placeholder_text("Click a window to fetch");
            addtask_grid.attach(wmclass_entry, 3, 4, 20, 1);
            // wname
            Label wname_label = new Label("Window name");
            addtask_grid.attach(wname_label, 1, 5, 1, 1);
            Entry wname_entry = new Entry();
            wname_entry.set_text("");
            addtask_grid.attach(wname_entry, 3, 5, 20, 1);
            // geometry_header
            Label geometry_header = new Label("Grid & window geometry");
            addtask_grid.attach(geometry_header, 1, 6, 1, 1);
            // xsize
            Label grid_xsize_label = new Label("Grid columns");
            addtask_grid.attach(grid_xsize_label, 1, 7, 1, 1);
            SpinButton grid_xsize_spin = new Gtk.SpinButton.with_range(1, 10, 1);
            grid_xsize_spin.set_value(2);
            addtask_grid.attach(grid_xsize_spin, 3, 7, 1, 1);
            // ysize
            Label grid_ysize_label = new Label("Grid rows");
            addtask_grid.attach(grid_ysize_label, 1, 8, 1, 1);
            SpinButton grid_ysize_spin = new Gtk.SpinButton.with_range(1, 10, 1);
            grid_ysize_spin.set_value(2);
            addtask_grid.attach(grid_ysize_spin, 3, 8, 1, 1);
            // xpos
            Label xpos_label = new Label("Horizontal target position");
            addtask_grid.attach(xpos_label, 1, 9, 1, 1);
            SpinButton xpos_spin = new Gtk.SpinButton.with_range(0, 10, 1);
            xpos_spin.set_value(0);
            addtask_grid.attach(xpos_spin, 3, 9, 1, 1);
            // ypos
            Label ypos_label = new Label("Vertical target position");
            addtask_grid.attach(ypos_label, 1, 10, 1, 1);
            SpinButton ypos_spin = new Gtk.SpinButton.with_range(0, 10, 1);
            ypos_spin.set_value(0);
            addtask_grid.attach(ypos_spin, 3, 10, 1, 1);
            // xspan
            Label xspan_label = new Label("Horizontal cell span");
            addtask_grid.attach(xspan_label, 1, 11, 1, 1);
            SpinButton xspan_spin = new Gtk.SpinButton.with_range(1, 10, 1);
            xspan_spin.set_value(1);
            addtask_grid.attach(xspan_spin, 3, 11, 1, 1);
            // yspan
            Label yspan_label = new Label("Vertical cell span");
            addtask_grid.attach(yspan_label, 1, 12, 1, 1);
            SpinButton yspan_spin = new Gtk.SpinButton.with_range(1, 10, 1);
            yspan_spin.set_value(1);
            addtask_grid.attach(yspan_spin, 3, 12, 1, 1);
            // misc header
            Label misc_header = new Label("Miscellaneous");
            addtask_grid.attach(misc_header, 1, 13, 1, 1);
            // targetmonitor
            Label targetmonitor_label = new Label("Target monitor");
            addtask_grid.attach(targetmonitor_label, 1, 14, 1, 1);
            ComboBoxText screendropdown = new ComboBoxText();
            string[] mons = get_monitornames();
            foreach (string m in mons) {
                screendropdown.append_text(m);
            }
            addtask_grid.attach(screendropdown, 3, 14, 1, 1);
            Label tryexisting_label = new Label("Try to move existing window");
            addtask_grid.attach(tryexisting_label, 1, 15, 1, 1);
            CheckButton tryexist_checkbox = new Gtk.CheckButton();
            addtask_grid.attach(tryexist_checkbox, 3, 15, 1, 1);
            // set style on headers & fields / widgets
            Label[] headers = {
                launchsection_header, geometry_header, misc_header
            };
            foreach (Label l in headers) {
                set_widgetstyle(l, "secondheader");
            }
            Label[] all_labels = {
                launchsection_header, exec_label, wmclass_label, wname_label,
                geometry_header, grid_xsize_label, grid_ysize_label,
                xpos_label, ypos_label, xspan_label, yspan_label, misc_header,
                targetmonitor_label, tryexisting_label
            };
            foreach (Label l in all_labels) {
                l.xalign = 0;
            }
            addtask_grid.attach(new Label(""), 1, 50, 1, 1);
            Gtk.Box testaction_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            addtask_grid.attach(testaction_box, 1, 51, 2, 1);
            Button testwindowtask_button = new Gtk.Button();
            testwindowtask_button.label = "Test";
            testaction_box.pack_start(testwindowtask_button, false, false, 0);
            Gtk.Box dialogaction_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Button applytask_button = new Gtk.Button();
            applytask_button.label = "Apply";
            applytask_button.set_size_request(90, 10);
            Button canceltask_button = new Gtk.Button();
            canceltask_button.label = "Cancel";
            canceltask_button.set_size_request(90, 10);
            canceltask_button.clicked.connect(()=> {
                get_task.destroy();
                //  get_task.close();// werkt pas na twee keer?
            });
            dialogaction_box.pack_end(canceltask_button, false, false, 2);
            dialogaction_box.pack_end(applytask_button, false, false, 2);
            addtask_grid.attach(dialogaction_box, 1, 52, 50, 1);
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
                if (set_monitor != "" && string_inlist(set_monitor, mons) == -1) {
                    screendropdown.append_text(set_monitor);
                }
                int foundindex = string_inlist((string)currtask_data.get_child_value(9), mons);
                screendropdown.active = foundindex;
                tryexist_checkbox.set_active(
                    (string)currtask_data.get_child_value(10) == "true"
                );
            }
            // optimize please
            testwindowtask_button.clicked.connect(()=> {
                string candidate_content = create_filecontent(
                    exec_entry, xpos_spin, ypos_spin, grid_xsize_spin,
                    grid_ysize_spin, xspan_spin, yspan_spin, wmclass_entry,
                    wname_entry, screendropdown, tryexist_checkbox
                );
                apply_taskedit(candidate_content);
            });

            applytask_button.clicked.connect(()=> {
                string candidate_content = create_filecontent(
                    exec_entry, xpos_spin, ypos_spin, grid_xsize_spin,
                    grid_ysize_spin, xspan_spin, yspan_spin, wmclass_entry,
                    wname_entry, screendropdown, tryexist_checkbox
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
            });
            contentarea.show_all();
            get_task.run();
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
            Entry exec_entry, SpinButton xpos_spin, SpinButton ypos_spin,
            SpinButton grid_xsize_spin, SpinButton grid_ysize_spin,
            SpinButton xspan_spin, SpinButton yspan_spin, Entry wmclass_entry,
            Entry wname_entry, ComboBoxText screendropdown,
            ToggleButton tryexist_checkbox
        ) {
            // creates the content of a task file from the fields
            bool try_isset = tryexist_checkbox.get_active();
            int curr_xpos = (int)xpos_spin.get_value();
            int curr_ypos = (int)ypos_spin.get_value();
            int curr_cols = (int)grid_xsize_spin.get_value();
            int curr_rows = (int)grid_ysize_spin.get_value();
            int curr_xspan = (int)xspan_spin.get_value();
            int curr_yspan = (int)yspan_spin.get_value();
            return "Exec=" + exec_entry.get_text().concat(
                "\nXPosition=" + @"$curr_xpos", "\nYPosition=" + @"$curr_ypos",
                "\nCols=" + @"$curr_cols", "\nRows=" + @"$curr_rows",
                "\nXSpan=" + @"$curr_xspan", "\nYSpan=" + @"$curr_yspan",
                "\nWMClass=" + wmclass_entry.get_text(),
                "\nWName=" + wname_entry.get_text(),
                "\nMonitor=" + screendropdown.get_active_text(),
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
                taskbutton.label = s;
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
                taskdeletebutton.clicked.connect(()=>{
                    File todelete = File.new_for_path(
                        searchpath.concat("/", layoutsubject, "/", s)
                    );
                    delete_file(todelete);
                    update_stackgrid_editlayout(layoutsubject);
                });
                taskbutton.clicked.connect(()=> {
                    //  string exec_path = Config.SHUFFLER_DIR + "/run_layout";
                    // keep for quick compile & test
                    string exec_path = "/lib/budgie-window-shuffler/run_layout";
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
                    last_layoutname = s;
                    mastergrid.show_all();
                });
                newlauyoutbutton.set_size_request(300, 45);
                neweditbutton.set_can_focus(false);
                neweditbutton.set_relief(Gtk.ReliefStyle.NONE);
                Gtk.Button newdeletebutton = new Button.from_icon_name(
                    "user-trash-symbolic", Gtk.IconSize.BUTTON
                );
                newdeletebutton.set_size_request(45, 45);
                newdeletebutton.set_can_focus(false);
                newdeletebutton.set_relief(Gtk.ReliefStyle.NONE);
                newdeletebutton.clicked.connect(()=> {
                    File todelete = File.new_for_path(combine_pathsteps(s));
                    string[] child_items = get_layouttasks(s);
                    foreach (string sub in child_items) {
                        string path = combine_pathsteps(s, sub);
                        delete_file(null, path);
                    }
                    delete_file(todelete);
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
            layouts = new PopupWindow();
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
        File triggerdir = File.new_for_path(triggerpath);
        popuptrigger = File.new_for_path(triggerpath.concat("/layoutspopup"));
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