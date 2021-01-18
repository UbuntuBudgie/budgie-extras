using Gtk;
using Gdk;

namespace ShufflerControls2 {

    class OwnSpinButton : Gtk.Grid{

        public Gtk.Entry spinvalue;
        Gtk.Button up;
        Gtk.Button down;

        // css stuff
        string spin_stylecss = """
        .arrowbutton {
            padding: 0px;
            border-width: 0px;
        }
        """;
        private void set_widgetstyle(Widget w, string css_style, bool remove = false) {
            var widgets_stylecontext = w.get_style_context();
            if (!remove) {
                widgets_stylecontext.add_class(css_style);
            }
            else {
                widgets_stylecontext.remove_class(css_style);
            }
        }

        public OwnSpinButton(
           string orientation, int min = 0, int max = 10
        ) {
            // css stuff
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

        Gtk.ScrolledWindow settings_scrolledwindow;
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
        """;

        public ShufflerControlsWindow() {

            this.title = "Window Shuffler Controls";

            // icons
            string iconpath = "/usr/share/pixmaps/";
            Pixbuf tilingicon = new Pixbuf.from_file_at_size(
                iconpath + "tilingicon.svg", 32, 32
            );
            Pixbuf layoutsicon = new Pixbuf.from_file_at_size(
                iconpath + "layoutsicon.svg", 32, 32
            );
            Pixbuf rulesicon = new Pixbuf.from_file_at_size(
                iconpath + "rulesicon.svg", 32, 32
            );
            Pixbuf generalprefs = new Pixbuf.from_file_at_size(
                iconpath + "shuffler-generalprefs.svg", 32, 32
            );

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
            listbox.set_size_request(200, 500);
            // content
            Label title0 = new Label("General Preferences");
            title0.set_xalign(0);
            Label title1 = new Label("Tiling");
            title1.set_xalign(0);
            Label title2 = new Label("Layouts");
            title2.set_xalign(0);
            Label title3 = new Label("Window rules");
            title3.set_xalign(0);
            listbox.insert(get_rowgrid(title0, generalprefs), 1);
            listbox.insert(get_rowgrid(title1, tilingicon), 1);
            listbox.insert(get_rowgrid(title2, layoutsicon), 2);
            listbox.insert(get_rowgrid(title3, rulesicon), 3);
            // Scrolled Window
            settings_scrolledwindow = new ScrolledWindow(null, null);
            settings_scrolledwindow.set_min_content_height(500);
            settings_scrolledwindow.set_min_content_width(600);
            maingrid.attach(settings_scrolledwindow, 2, 1, 1, 1);
            // stack
            allsettings_stack = new Gtk.Stack();
            allsettings_stack.set_transition_type(StackTransitionType.OVER_UP_DOWN);
            settings_scrolledwindow.add(allsettings_stack);

            // GENERAL SETTINGS PAGE
            Grid general_settingsgrid = new Gtk.Grid();
            general_settingsgrid.set_row_spacing(10);
            set_margins(general_settingsgrid, 50, 50, 50, 50);
            // margin header
            Label margins_header = new Label("Margins between virtual grid and screen edges");
            margins_header.get_style_context().add_class("justbold");
            margins_header.xalign = 0;
            general_settingsgrid.attach(margins_header, 0, 0, 100, 1);
            OwnSpinButton leftmarginspin = new OwnSpinButton("vert", 0, 200);
            OwnSpinButton rightmarginspin = new OwnSpinButton("vert", 0, 200);
            OwnSpinButton topmarginspin = new OwnSpinButton("vert", 0, 200);
            OwnSpinButton bottommarginspin = new OwnSpinButton("vert", 0, 200);
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
            OwnSpinButton paddingspin = new OwnSpinButton("vert", 0, 200);
            paddinggrid.attach(paddingspin, 2, 0, 1, 1);
            general_settingsgrid.attach(paddinggrid, 0, 7, 10, 1);
            general_settingsgrid.attach(new Label(""), 0, 8, 1, 1);
            // misc header
            Label misc_header = new Label("Miscellaneous");
            misc_header.get_style_context().add_class("justbold");
            misc_header.xalign = 0;
            general_settingsgrid.attach(misc_header, 0, 9, 3, 1);
            // animation
            Label animtionlabel = new Label("Enable animation");
            animtionlabel.xalign = 0; // optimize please
            general_settingsgrid.attach(animtionlabel, 0, 10, 1, 1);
            general_settingsgrid.attach(new Label("\t"), 1, 10, 1, 1);
            CheckButton toggle_animation = new CheckButton();
            general_settingsgrid.attach(toggle_animation, 2, 10, 1, 1);
            // notification
            Label notificationlabel = new Label("Show notification on incorrect window size");
            notificationlabel.xalign = 0; // optimize please
            general_settingsgrid.attach(notificationlabel, 0, 11, 1, 1);
            general_settingsgrid.attach(new Label("\t"), 1, 11, 1, 1);
            CheckButton toggle_notification = new CheckButton();
            general_settingsgrid.attach(toggle_notification, 2, 11, 1, 1);
            allsettings_stack.add_named(general_settingsgrid, "general");

            // TILING PAGE
            Grid tilinggrid = new Gtk.Grid();
            tilinggrid.set_row_spacing(10);
            set_margins(tilinggrid, 50, 50, 50, 50);
            // enable tiling shortcuts
            Grid subtilinggrid_enable = new Grid();
            subtilinggrid_enable.set_row_spacing(10);
            Label enable_tiling_label = new Label("Enable tiling shortcuts");
            enable_tiling_label.xalign = 0;
            subtilinggrid_enable.attach(enable_tiling_label, 0, 0, 1, 1);
            subtilinggrid_enable.attach(new Label("\t"), 1, 0, 1, 1);
            Gtk.Switch enable_tilingswitch = new Gtk.Switch();
            subtilinggrid_enable.attach(enable_tilingswitch, 2, 0, 1, 1);
            tilinggrid.attach(subtilinggrid_enable, 0, 0, 10, 1);
            Label enable_gridgui_label = new Label("Enable grid GUI");
            enable_gridgui_label.xalign = 0;
            subtilinggrid_enable.attach(enable_gridgui_label, 0, 1, 1, 1);
            subtilinggrid_enable.attach(new Label("\t"), 1, 1, 1, 1);
            Gtk.Switch enable_gridguiswitch = new Gtk.Switch();
            subtilinggrid_enable.attach(enable_gridguiswitch, 2, 1, 1, 1);
            subtilinggrid_enable.attach(new Label(""), 0, 10, 1, 1);
            // gridsize
            Grid gridsizegrid = new Gtk.Grid();
            gridsizegrid.set_row_spacing(10);
            Label gridsize_header = new Label(
                "Default gridsize for moving & resizing"
            );
            gridsize_header.xalign = 0;
            gridsize_header.get_style_context().add_class("justbold");
            gridsizegrid.attach(gridsize_header, 0, 0, 1, 1);
            tilinggrid.attach(gridsizegrid, 0, 1, 10, 1);




            // swap windows
            Label swap_label = new Label(
                "Swap windows when moving window to an occupied position"
            );
            tilinggrid.attach(swap_label, 0, 10, 2, 1);
            swap_label.xalign = 0;
            tilinggrid.attach(new Label("\t"), 2, 10, 1, 1);
            CheckButton toggle_swapwindows = new CheckButton();
            tilinggrid.attach(toggle_swapwindows, 3, 10, 1, 1);
            allsettings_stack.add_named(tilinggrid, "tiling");


            // Layouts page
            Grid layoutsgrid = new Gtk.Grid();
            layoutsgrid.attach(new Label("layouts"), 0, 0, 1, 1);
            allsettings_stack.add_named(layoutsgrid, "layouts");
            // Rules page
            Grid rulesgrid = new Gtk.Grid();
            rulesgrid.attach(new Label("rules"), 0, 0, 1, 1);
            allsettings_stack.add_named(rulesgrid, "rules");

            listbox.row_activated.connect(get_row);
            listbox.select_row(listbox.get_row_at_index(0));
            this.add(maingrid);
            listbox.show_all();
            maingrid.show_all();
            this.show_all();
        }

        private Grid get_rowgrid(Label label, Pixbuf pixbuf) {
            Image sectionimage = new Gtk.Image();
            sectionimage.set_from_pixbuf(pixbuf);
            Grid rowgrid = new Gtk.Grid();
            rowgrid.set_column_spacing(6);
            set_margins(rowgrid, 10, 3, 7, 7);
            rowgrid.attach(sectionimage, 0, 0, 1, 1);
            rowgrid.attach(label, 1, 0, 1, 1);
            return rowgrid;
        }

        private void get_row(ListBoxRow row) {
            int row_index = row.get_index();
            switch (row_index) {
                case 0:
                allsettings_stack.set_visible_child_name("general");
                break;
                case 1:
                allsettings_stack.set_visible_child_name("tiling");
                break;
                case 2:
                allsettings_stack.set_visible_child_name("layouts");
                break;
                case 3:
                allsettings_stack.set_visible_child_name("rules");
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