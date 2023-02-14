using Gtk;
using Json;

/*
* HotCornersIII
* Author: Jacob Vlijm
* Copyright © 2017 Ubuntu Budgie Developers
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

// valac --pkg json-glib-1.0 --pkg gtk+-3.0



namespace HotCornerSettings {

    /* dbus client for freedesktop list names) */
    [DBus (name = "org.freedesktop.DBus")]
    interface FreeDesktopClient : GLib.Object {
        public abstract string[] ListNames () throws Error;
    }

    /* dbus client for shufflerdaemon (then skip action) */
    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]
    interface ShufflerInfoClient : GLib.Object {
        public abstract void ActivateWindowByname (string wname) throws Error;
    }

    /* dbus server, to guarantee single instance*/
    [DBus (name = "org.UbuntuBudgie.HotCornersControlRuns")]
    private class HotCornersServer : GLib.Object {
    }

    void on_bus_acquired (DBusConnection conn) {
        // register the bus
        try {
            conn.register_object ("/org/ubuntubudgie/hotcornerscontrolruns",
                new HotCornersServer ());
        }
        catch (IOError e) {
            stderr.printf ("Could not register service\n");
        }
    }


    class HotCornerSettingsWindow : Gtk.Window {

        enum CornerButtons {
            LEFT,
            TOPLEFT,
            TOP,
            TOPRIGHT,
            RIGHT,
            BOTTOMRIGHT,
            BOTTOM,
            BOTTOMLEFT
        }

        enum SettingsFlow {
            NONE,
            WIDGETSTOSETTINGS,
            SETTINGSTOWIDGETS
        }

        string hotc_css = """
        .windowbutton {
            margin: 0px;
            box-shadow: none;
            min-width: 4px;
            min-height: 4px;
            border-radius: 4px;
        }
        .messagetext {
            font-style: italic;
            color: red;
        }
        .justbold {
            font-weight: bold;
        }
        .justitalic {
            font-style: italic;
        }""";

        string[] default_names; /* command names dropdown */
        string[] default_commands; /* corresponding commands */
        Gtk.ComboBoxText[] dropdowns; /* corresponding dropdowns */
        Gtk.Entry[] command_entries; /* entries for custom commands */
        Gtk.Box[] page_boxes; /* box per stack page */
        Gtk.Switch[] onoffs; /* toggle corenr on-off */
        Gtk.ToggleButton[] togglecustoms; /* toggle custom command */
        Gtk.Button[] cornerbuttons; /* bullets */
        string[] set_commands = new string[8]; /* currently set commands (8 spots) */
        Gtk.Image[] buttonimages_off; /* bunch of images for bullets */
        Gtk.Image[] buttonimages_edit_off;
        Gtk.Image[] buttonimages_on;
        Gtk.Image[] buttonimages_edit_on;
        bool[] buttonstates = new bool[8];
        /* stuff for managing content of dropdown */
        GLib.Settings[] applist_settings;
        string[] schema_checklist = {};
        Label reload_message;

        int timeout = 0;

        int settingsflow = SettingsFlow.NONE;

        FreeDesktopClient? freed_client;
        ShufflerInfoClient? shufflerinfoclient;

        Stack pages = new Gtk.Stack();
        Grid maingrid;
        GLib.Settings newhcornersettings;
        Gtk.Scale delay_slider;
        Gtk.Scale pressure_slider;
        int currently_edited = 0;


        public HotCornerSettingsWindow () {

            setup_freed_client();
            get_shuffler_client();

            string title = "Hotcorners settings";
            this.set_title(title);

            if (
                !service_ison("org.UbuntuBudgie.HotCornersControlRuns")
            ) {
                setup_dbus_server();
            }
            else {
                message("Hotcorners Settings already runs");
                activate_byname(title);
                Process.exit(0);
            }

            /* gsettings */
            newhcornersettings = new GLib.Settings(
                //  "org.ubuntubudgie.plugins.budgie-newhotcorners"
                "org.ubuntubudgie.budgie-extras.HotCorners"
            );

            newhcornersettings.changed["delay"].connect(()=> {
                if (!try_block_settingsflow(SettingsFlow.SETTINGSTOWIDGETS)) {
                    return;
                }
                update_delay_fromgsettings();
            });

            newhcornersettings.changed["pressure"].connect(()=> {
                if (!try_block_settingsflow(SettingsFlow.SETTINGSTOWIDGETS)) {
                    return;
                }
                update_pressure_fromgsettings();
            });

            newhcornersettings.changed["commands"].connect(()=> {
                if (!try_block_settingsflow(SettingsFlow.SETTINGSTOWIDGETS)) {
                    return;
                }
                int n = currently_edited;
                update_commands_fromsettings(n);
                update_bulletview(n);
            });
            /* css stuff */
            Gdk.Screen gdk_scr = this.get_screen();
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(hotc_css);
                Gtk.StyleContext.add_provider_for_screen(
                    gdk_scr, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }
            /* let's get some information first, and prepare dropdown */
            get_commands();
            /* maingrid */
            maingrid = new Gtk.Grid();
            set_margins(maingrid, 30, 30, 30, 30);
            this.add(maingrid);
            /* Headers & switch */
            Box masterswitchbox = new Gtk.Box(HORIZONTAL, 0);
            set_margins(masterswitchbox, 0, 0, 0, 30);
            masterswitchbox.pack_start (
                makelabel("Activate hotcorners", {0, 0, 0, 0}, "justbold")
            );
            Switch masterswitch = new Gtk.Switch();
            newhcornersettings.bind(
                "active", masterswitch, "state", SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            masterswitchbox.pack_end(masterswitch, false, false, 40);
            maingrid.attach(masterswitchbox, 0, 0, 10, 1);
            maingrid.attach (
                makelabel(
                    "Corner settings", {0, 0, 0, 20}, "justbold"), 0, 2, 10, 1
            );
            maingrid.attach (makelabel(
                "Click a spot to edit", {0, 0, 0, 20}, "justitalic"), 0, 3, 10, 1);
            /* pages section */
            make_pages();
            maingrid.attach(pages, 0, 20, 10, 1);
            pages.set_transition_type(StackTransitionType.SLIDE_LEFT_RIGHT);
            /* general config */
            maingrid.attach (
                makelabel(
                    "General configuration", {0, 0, 50, 20}, "justbold"), 0, 30, 10, 1
            );
            /* Delay section */
            maingrid.attach (makelabel("Delay", {0, 0, 0, 10}, "justitalic"), 0, 35, 10, 1);
            delay_slider = new Gtk.Scale.with_range(
                Gtk.Orientation.HORIZONTAL, 0, 100, 5
            );
            set_margins(delay_slider, 30, 30, 0, 30);
            maingrid.attach(delay_slider, 0, 40, 10, 1);
            /* Pressure section */
            maingrid.attach (makelabel("Pressure", {0, 0, 0, 10}, "justitalic"), 0, 45, 10, 1);
            pressure_slider = new Gtk.Scale.with_range(
                Gtk.Orientation.HORIZONTAL, 0, 100, 5
            );
            set_margins(pressure_slider, 30, 30, 0, 20); // bottom of window
            maingrid.attach(pressure_slider, 0, 50, 10, 1);
            /* message label */


            reload_message = makelabel(
                "\n", {0, 0, 0, 0}, "messagetext"
            );
            maingrid.attach(reload_message, 0, 60, 10, 1);

            update_delay_fromgsettings();
            update_pressure_fromgsettings();
            delay_slider.value_changed.connect(()=> {
                if (!try_block_settingsflow(SettingsFlow.WIDGETSTOSETTINGS)) {
                    return;
                }
                update_settings_fromdelay();
            });
            pressure_slider.value_changed.connect(()=> {
                if (!try_block_settingsflow(SettingsFlow.WIDGETSTOSETTINGS)) {
                    return;
                }
                update_settings_frompressure();
            });
            this.show_all();
            /*
            to set left-right space, we need allocated space of the window.
            so, show first, then calculate, show again.
            */
            int w; int h;
            this.get_size(out w, out h);
            /* left/right, top, bottom, inner-hor, inner-vert */
            make_bulletsection((int)(w - 185)/2, 15, 50, 10, 2);

            set_interface_sensitive(newhcornersettings.get_boolean("active"));
            masterswitch.state_set.connect((newstate)=> {
                set_interface_sensitive(newstate);
                return false;
            });

            this.show_all();
            if (try_block_settingsflow(SettingsFlow.SETTINGSTOWIDGETS)) {
                /*
                pretty late, because of gui appearance on startup (sliding
                pages). since it is after the connect(), block loopback.
                */
                update_commands_fromsettings();
            }
            pages.set_visible_child_name("empty_page");
            this.destroy.connect(Gtk.main_quit);
        }

        private void activate_byname (string name) {
            if (!service_ison("org.UbuntuBudgie.ShufflerInfoDaemon")) {
                return;
            }
            try {
                shufflerinfoclient.ActivateWindowByname(name);
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private void get_shuffler_client () {
            try {
                shufflerinfoclient = Bus.get_proxy_sync (
                    BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                    ("/org/ubuntubudgie/shufflerinfodaemon")
                );
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        void setup_dbus_server () {
            Bus.own_name (
                BusType.SESSION, "org.UbuntuBudgie.HotCornersControlRuns",
                BusNameOwnerFlags.NONE, on_bus_acquired,
                () => {},
                () => stderr.printf ("Could not acquire name\n")
            );
        }

        private bool service_ison (string id) {
            string[] names = get_dbus_namelist();
            //  string hotc = "org.UbuntuBudgie.HotCornerSwitch";
            for (int i=0; i<names.length; i++) {
                if (id == names[i]) {
                    return true;
                }
            }
            return false;
        }

        private void setup_freed_client () {
            try {
                freed_client = Bus.get_proxy_sync (
                    BusType.SESSION, "org.freedesktop.DBus",
                    ("/org/freedesktop/DBus")
                );
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private string[] get_dbus_namelist () {
            try {
                return freed_client.ListNames();
            }
            catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return {};
            }
        }

        private bool try_block_settingsflow(int newflow) {
            /*
            for various reasons, directly binding widgets to gsettings is not
            possible just like that. We still want to make the gui and settings
            editable in a bidirectional way though, so need to cut off the loop
            back if either one is edited. we do that by blocking it, what comes
            first, settings or gui, will set a timeout for the other, updated in
            case of repeated/continuous signal like the slider.
            */

            if (settingsflow == SettingsFlow.NONE) {
                /* action starts, either from gsettings or GUI, start countdown */
                timeout = 5;
                settingsflow = newflow;
            }
            else if (newflow == settingsflow) {
                /* repeated action (slider), reset timer, no new countdown! */
                timeout = 5;
                return true;
            }
            else {
                /* we're busy, block loop back, no new countdown!  */
                return false;
            }

            GLib.Timeout.add(25, ()=>{
                timeout -= 1;
                if (timeout <= 0) {
                    settingsflow = SettingsFlow.NONE;
                    return false;
                }
                return true;
            });
            return true;
        }

        private void update_commands_fromsettings (int? orig_current = null) {
            set_commands = newhcornersettings.get_strv("commands");
            int i = 0;
            foreach (string s in set_commands) {
                /* make sure connections are respected according to i */
                currently_edited = i;
                bool ison = true;
                ComboBoxText currdrop = dropdowns[i];
                if (s == "") {
                    ison = false;
                }
                buttonstates[i] = ison;
                onoffs[i].set_active(ison);
                /* don't always be so sensitive */
                command_entries[i].set_sensitive(ison);
                currdrop.set_sensitive(ison);
                togglecustoms[i].set_sensitive(ison);
                /* set entry or dropdown */
                int dropdownindex = get_stringindex(s, default_commands);
                bool iscustom = ison && dropdownindex == -1;
                togglecustoms[i].set_active(iscustom);
                if (iscustom) {
                    command_entries[i].set_text(s);
                }
                if (ison && !iscustom) {
                    /* set dropdown */
                    currdrop.set_active(dropdownindex);
                }
                i += 1;
            }

            update_bulletview();

            if (orig_current != null) {
                currently_edited = orig_current;
            }
        }

        private void update_delay_fromgsettings () {
            delay_slider.set_value(newhcornersettings.get_int("delay"));
        }

        private void update_pressure_fromgsettings () {
            pressure_slider.set_value(newhcornersettings.get_int("pressure"));
        }

        private void update_settings_fromdelay () {
            newhcornersettings.set_int("delay", (int)delay_slider.get_value());
        }

        private void update_settings_frompressure () {
            newhcornersettings.set_int("pressure", (int)pressure_slider.get_value());
        }

        private void set_margins (
            Widget w, int l, int r, int t, int b
        ) {
            w.set_margin_start(l);
            w.set_margin_end(r);
            w.set_margin_top(t);
            w.set_margin_bottom(b);
        }

        private void set_stuff_sensitive (bool newstate) {
            Entry currentry = command_entries[currently_edited];
            ComboBoxText currcombo = dropdowns[currently_edited];
            Widget[] toset = {
                currentry, currcombo, togglecustoms[currently_edited]
            };
            foreach (Widget w in toset) {
                w.set_sensitive(newstate);
            }
            if (!newstate) {
                currcombo.set_active(-1);
                currentry.set_text("");
            }
        }

        private int get_stringindex (string s, string[] arr) {
            for (int i=0; i < arr.length; i++) {
                if(s == arr[i]) return i;
            } return -1;
        }

        private Label makelabel (
            string tekst, int[] mrg, string? style = null
        ) {
            Label newlabel = new Label(tekst);
            if (style != null) {
                newlabel.get_style_context().add_class(style);
            }
            newlabel.xalign = 0;
            set_margins(newlabel, mrg[0], mrg[1], mrg[2], mrg[3]);
            return newlabel;
        }

        private void switch_dropdown_entry(bool state) {
            /* toggkling custom command, toggle entry/combo */
            Box currbox = page_boxes[currently_edited];
            Entry entry = command_entries[currently_edited];
            ComboBoxText combo = dropdowns[currently_edited];
            if (state) {
                combo.set_active(-1);
                currbox.remove(combo);
                currbox.pack_start(entry);
            }
            else {
                entry.set_text("");
                currbox.remove(entry);
                currbox.pack_start(combo);
            }
            currbox.show_all();
        }

        private void make_pages () {
            /* let's make the combo's, fetch data */
            pages.add_named(new Gtk.Grid(), "empty_page");

            for (int i=0; i<8; i++) {
                /* combo */
                Gtk.ComboBoxText combo = new Gtk.ComboBoxText();
                combo.changed.connect(()=> {
                    if (!try_block_settingsflow(SettingsFlow.WIDGETSTOSETTINGS)) {
                        return;
                    }
                    string newcommand = "";
                    string? currname = "";
                    currname = combo.get_active_text();
                    if (currname != null) {
                        newcommand = default_commands[get_stringindex(
                            currname, default_names
                        )];
                    }
                    set_commands[currently_edited] = newcommand;
                    newhcornersettings.set_strv("commands", set_commands);
                    int n = currently_edited;
                    update_bulletview(n);
                });
                combo.set_size_request(260, 10);
                foreach (string s in default_names) {
                    combo.append_text(s);
                }
                dropdowns += combo;
                /* entry */
                Gtk.Entry cmd_entry = new Gtk.Entry();
                cmd_entry.set_placeholder_text("Enter a command here");
                cmd_entry.set_size_request(260, 10);
                cmd_entry.changed.connect((newtext)=> {
                    if (!try_block_settingsflow(SettingsFlow.WIDGETSTOSETTINGS)) {
                        return;
                    }
                    set_commands[currently_edited] = cmd_entry.get_text();
                    newhcornersettings.set_strv("commands", set_commands);
                    int n = currently_edited;
                    update_bulletview(n);
                });
                command_entries += cmd_entry;
                /* onoff Switch */
                Switch onoffswitch = new Gtk.Switch();
                onoffswitch.set_tooltip_text("Toggle hotcorner on-off");
                set_margins(onoffswitch, 10, 5, 2, 2);
                onoffswitch.state_set.connect((newstate)=> {
                    set_stuff_sensitive(newstate);
                    update_bulletview(currently_edited);
                    return false;
                });
                onoffs += onoffswitch;
                /* toggle custom command */
                ToggleButton togglecustom = new Gtk.ToggleButton();
                togglecustom.set_tooltip_text("Set a custom command");
                togglecustom.toggled.connect((button)=> {
                    bool newstate = button.get_active();
                    switch_dropdown_entry(newstate);
                });
                Image togglecustomimage = new Gtk.Image.from_icon_name(
                    "edit-symbolic", Gtk.IconSize.BUTTON
                );
                togglecustomimage.set_pixel_size(20);
                togglecustom.image = togglecustomimage;
                togglecustom.set_relief(Gtk.ReliefStyle.NONE);
                set_margins(togglecustom, 0, 0, 2, 2);
                togglecustoms += togglecustom;
                /* Box per page */
                Box pagebox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
                pagebox.pack_start(combo);
                pagebox.pack_end(togglecustom);
                pagebox.pack_end(onoffswitch);
                page_boxes += pagebox;
                pages.add_named(pagebox, @"page_$i");
            }
        }

        private void make_bulletsection (
            int lr, int tp, int bt, int hsp, int vsp
        ) {
            /* lr = left/right, bt = bottom, hsp = inner-hor, vsp = inner-vert */

            make_iconset();

            cornerbuttons = {
                makeactionbutton(lr, hsp, vsp, vsp, CornerButtons.LEFT),
                makeactionbutton(lr, hsp, tp, vsp, CornerButtons.TOPLEFT),
                makeactionbutton(hsp, hsp, tp, vsp, CornerButtons.TOP),
                makeactionbutton(hsp, lr, tp, vsp, CornerButtons.TOPRIGHT),
                makeactionbutton(hsp, lr, vsp, vsp, CornerButtons.RIGHT),
                makeactionbutton(hsp, lr, vsp, bt, CornerButtons.BOTTOMRIGHT),
                makeactionbutton(hsp, hsp, vsp, bt, CornerButtons.BOTTOM),
                makeactionbutton(lr, hsp, vsp, bt, CornerButtons.BOTTOMLEFT),
            };

            maingrid.attach(cornerbuttons[CornerButtons.LEFT], 0, 7, 1, 1);
            maingrid.attach(cornerbuttons[CornerButtons.TOPLEFT], 0, 6, 1, 1);
            maingrid.attach(cornerbuttons[CornerButtons.TOP], 1, 6, 1, 1);
            maingrid.attach(cornerbuttons[CornerButtons.TOPRIGHT], 2, 6, 1, 1);
            maingrid.attach(cornerbuttons[CornerButtons.RIGHT], 2, 7, 1, 1);
            maingrid.attach(cornerbuttons[CornerButtons.BOTTOMRIGHT], 2, 8, 1, 1);
            maingrid.attach(cornerbuttons[CornerButtons.BOTTOM], 1, 8, 1, 1);
            maingrid.attach(cornerbuttons[CornerButtons.BOTTOMLEFT], 0, 8, 1, 1);
        }

        private Button makeactionbutton (
            int l, int r, int t, int b, int index
        ) {
            Gtk.Image offspot = new Gtk.Image.from_icon_name(
                "budgie-hotcgui-symbolic", Gtk.IconSize.BUTTON
            );
            Button actionbutton = new Gtk.Button();
            actionbutton.image = offspot;
            actionbutton.set_relief(Gtk.ReliefStyle.NONE);
            actionbutton.set_can_focus(false);
            actionbutton.get_style_context().add_class("windowbutton");
            set_margins(actionbutton, l, r, t, b);
            actionbutton.clicked.connect(()=> {
                pages.set_visible_child_name(@"page_$index");
                currently_edited = index;
                buttonstates[index] = true;
                update_bulletview(index);
            });
            return actionbutton;
        }

        private void make_iconset() {
            for (int i=0; i<8; i++) {
                buttonimages_off += new Gtk.Image.from_icon_name(
                    "budgie-hotcgui-symbolic", Gtk.IconSize.BUTTON
                );
                buttonimages_edit_off += new Gtk.Image.from_icon_name(
                    "budgie-hotcgui-edit-symbolic", Gtk.IconSize.BUTTON
                );
                buttonimages_on += new Gtk.Image.from_icon_name(
                    "budgie-hotcgui-red", Gtk.IconSize.BUTTON
                );
                buttonimages_edit_on += new Gtk.Image.from_icon_name(
                    "budgie-hotcgui-edit-red", Gtk.IconSize.BUTTON
                );
            }
        }

        private void set_interface_sensitive (bool newstate) {
            foreach (Widget w in cornerbuttons) {
                w.set_sensitive(newstate);
            }
            pages.set_sensitive(newstate);
            delay_slider.set_sensitive(newstate);
            pressure_slider.set_sensitive(newstate);
        }

        private void update_bulletview (int? currtarget = null) {
            /* does nothing with gsettings, so safe to control from gsettings -and- gui */
            bool validpage = pages.get_visible_child_name() != "empty_page";
            for (int i = 0; i < 8; i++) {

                bool state = set_commands[i] != "";
                Button b = cornerbuttons[i];
                Image bimg = buttonimages_on[i];
                if (state) {
                    if (i == currtarget && validpage) {
                        bimg = buttonimages_edit_on[i];
                    }
                }
                else {
                    bimg = buttonimages_off[i];
                    if (i == currtarget && validpage) {
                        bimg = buttonimages_edit_off[i];
                    }
                }
                b.set_image(bimg);
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

        private bool check_schema (string schema) {
            SettingsSchemaSource src = SettingsSchemaSource.get_default();
            string[] nonloc; string[] loc;
            src.list_schemas(false, out nonloc, out loc);
            foreach (string s in nonloc) {
                if (s == schema) {
                    return true;
                }
            }
            return false;
        }

        private bool get_active (string schema, string val) {
            string idstring = schema + val;
            GLib.Settings checkbool = new GLib.Settings(schema);
            if (get_stringindex(idstring, schema_checklist) == -1) {
                schema_checklist += idstring;
                checkbool.changed[val].connect(()=> {
                    /* we need to add stuff here in furure to reset the gui */
                    reload_message.set_text(
                        "Available dropdown items changed\n" +
                        "please restart settingswindow"
                    );
                });
                applist_settings += checkbool;
            }
            bool runs = checkbool.get_boolean(val);
            return runs;
        }

        private void read_json(Json.Parser parser, string command) {
            /* reads json data from gsettings name/command couples */
            try {
                parser.load_from_data (command);
            }
            catch (Error e) {
                message("Could not load data for dropdown");
                return;
            }
            var root_object = parser.get_root ().get_object ();
            string name = root_object.get_string_member ("name");
            string cmd = root_object.get_string_member ("command");
            if (root_object.has_member("gsettingsboolean")) {
                string gset = root_object.get_string_member ("gsettingsboolean");
                string[] gdata = gset.split(" ");
                string schema = gdata[0];
                if (check_schema(schema)) {
                    if (get_active(schema, gdata[1])) {
                        /* add name & command */
                        add_tolist(name, cmd);
                    }
                }
            }
            else {
                add_tolist(name, cmd);
            }
        }

        private void add_tolist (string name, string command) {
            default_names += name;
            default_commands += command;
        }

        private void get_commands() {
            string[] jsondata = readfile(
                "/usr/share/budgie-hotcorners/defaults"
            ).strip().split("\n");
            var parser = new Json.Parser ();
            foreach (string l in jsondata) {
                read_json(parser, l);
            }
        }
    }

    public static void main(string[] args) {
        Gtk.init(ref args);
        new HotCornerSettingsWindow();
        Gtk.main();
    }
}

// 684 - todo: path to defaults -file / translations / config paths
