using Gtk;
using Gdk;
using GLib.Math;
using Json;
using Notify;

/*
* HotCornersII
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

namespace HCSupport {

    /*
    * Here we keep the (possibly) shared stuff, or general functions, to
    * keep the main code clean and readable
    * OK, need to clean up these ones some day. Silly idea.
    */

    private void remove_fromgrid(Grid grid, Widget? widget) {
        if (widget != null) {
            grid.remove(widget);
        }
    }

    private bool locked () {
        string cmd = Config.PACKAGE_BINDIR + "/pgrep -f gnome-screensaver-dialog";
        string output;
        try {
            GLib.Process.spawn_command_line_sync(cmd, out output);
            if (output == "") {
                return false;
            }
        }
        /* on an occasional exception, just don't run the command */
        catch (SpawnError e) {
            return true;
        }
        return true;
    }

    private GLib.Settings get_settings(string path) {
        var settings = new GLib.Settings(path);
        return settings;
    }

    private bool command_isdefault(string cmd, string[] defaults) {
        /* yep, silly repeated code. who cares? this is vala */
        for (int i=0; i < defaults.length; i++) {
            if(cmd == defaults[i]) return true;
        } return false;
    }

    private int get_stringindex (string s, string[] arr) {
        for (int i=0; i < arr.length; i++) {
            if(s == arr[i]) return i;
        } return -1;
    }

    private int get_togglebuttonindex (
        ToggleButton button, ToggleButton[] arr
        ) {
        for (int i=0; i < arr.length; i++) {
            if(button == arr[i]) return i;
        } return -1;
    }

    private int get_cboxindex (ComboBox c, ComboBox[] arr) {
        for (int i=0; i < arr.length; i++) {
            if(c == arr[i]) return i;
        } return -1;
    }

    private int get_checkbuttonindex (
        ToggleButton button, CheckButton[] arr
        ) {
        for (int i=0; i < arr.length; i++) {
            if(button == arr[i]) return i;
        } return -1;
    }

    private int get_entryindex (Editable entry, Entry[] arr) {
        for (int i=0; i < arr.length; i++) {
            if(entry == arr[i]) return i;
        } return -1;
    }
}


namespace HotCornersApplet {

    // shared vars & functions
    GLib.Settings hc_settings;
    Gdk.Screen gdkscreen;
    private string[] commands;
    bool showpanelicon;

    private void read_setcommands () {
        /* get the initially set commands */
        commands = hc_settings.get_strv("commands");
    }


    class SettingsGrid : Gtk.Grid {

        private ToggleButton[] buttons;
        private CheckButton[] cbuttons;
        private string[] dropdown_namelist;
        private string[] dropdown_cmdlist;
        private Entry[] entries;
        private ComboBox[] dropdowns;
        string css_data;

        public SettingsGrid () {

            this.set_row_spacing(7);
            this.set_column_spacing(7);
            css_data = """
            .label {
                padding-bottom: 3px;
                padding-top: 3px;
                font-weight: bold;
            }
            """;
            this.attach(new Gtk.Label("\n"), 0, 0, 1, 1);
            populate_dropdown ();
            /* Corner label */
            var cornerlabel = new Gtk.Label(" " + (_("Corner")));
            cornerlabel.set_xalign(0);
            this.attach(cornerlabel, 0, 0, 1, 1);
            /* Action label */
            var actionlabel = new Gtk.Label(" " + (_("Action")));
            actionlabel.set_xalign(0);
            this.attach(actionlabel, 1, 0, 1, 1);
            /* Custom label */
            var customlabel = new Gtk.Label(" " + (_("Custom")));
            customlabel.set_xalign(0);
            this.attach(customlabel, 2, 0, 2, 1);
            Label[] headers = {
                cornerlabel, actionlabel, customlabel
            };
            var css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(css_data);
                Gtk.StyleContext.add_provider_for_screen(
                    gdkscreen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
                foreach (Label l in headers) {
                    l.get_style_context().add_class("label");
                };
            }
            catch (Error e) {
                print("Could not load css\n");
            }
            string[] namelist = {"⬉", "⬈", "⬋", "⬊"};
            /* create rows */
            int y_pos = 1;
            foreach (string name in namelist) {
                /* create toggle buttons */
                var latest_togglebutton = new ToggleButton.with_label(name);
                buttons += latest_togglebutton;
                this.attach(latest_togglebutton, 0, y_pos, 1, 1);
                /* create entries */
                var latest_entry = new Entry();
                entries += latest_entry;
                latest_entry.set_size_request(220, 20);
                /* create dropdown */
                var command_combo = new ComboBoxText();
                command_combo.set_size_request(220, 20);
                foreach (string cmd_name in dropdown_namelist) {
                    command_combo.append_text(cmd_name);
                }
                dropdowns += command_combo;
                /* space */
                var spacer = new Label(" ");
                this.attach(spacer, 2, y_pos, 1, 1);
                var spacer2 = new Label(" ");
                this.attach(spacer2, 4, y_pos, 1, 1);
                /* checkbutton custom command */
                var latest_check = new CheckButton();
                this.cbuttons += latest_check;
                this.attach(latest_check, 3, y_pos, 1, 1);
                /* populate with command situation */
                string set_command = commands[y_pos - 1];
                if (set_command == "") {
                    latest_togglebutton.set_active(false);
                    this.attach(command_combo, 1, y_pos, 1, 1);
                    command_combo.set_sensitive(false);
                    latest_check.set_sensitive(false);
                }
                else {
                    latest_togglebutton.set_active(true);
                    bool test = HCSupport.command_isdefault(
                        set_command, dropdown_cmdlist
                    );
                    if (test) {
                        this.attach(command_combo, 1, y_pos, 1, 1);
                        int combo_index = HCSupport.get_stringindex(
                            set_command, dropdown_cmdlist
                        );
                        command_combo.active = combo_index;
                        latest_check.set_active(false);
                    }
                    else {
                        this.attach(latest_entry, 1, y_pos, 1, 1);
                        latest_entry.set_text(set_command);
                        latest_check.set_active(true);
                    }
                }
                latest_togglebutton.toggled.connect(toggle_corner);
                latest_check.toggled.connect(act_on_checkbuttontoggle);
                command_combo.changed.connect(get_fromcombo);
                latest_entry.changed.connect(update_fromentry);
                hc_settings.set_strv("commands", commands);
                y_pos += 1;
            }
            this.show_all();
        }

        private void update_fromentry(Editable entry) {
            /* reads the entry and edits the corner / commands list */
            int buttonindex = HCSupport.get_entryindex(
                entry, entries
            );
            string new_cmd = entry.get_chars(0, 100);
            commands[buttonindex] = new_cmd;
            hc_settings.set_strv("commands", commands);
        }

        private void check_dependencies (string newcommand) {
            string? match = null;
            string[] command_keywords = {
                "previews", "shuffler/togglegui", "shuffler"
            };
            foreach (string keyword in command_keywords) {
                if (newcommand.contains(keyword)) {
                    match = keyword;
                    break;
                }
            }
            if (match != null) {
                string msg_header = "";
                string msg = "";
                string? proc_tocheck = null;
                switch (match) {
                    case "previews": {
                        msg_header = (_("Missing process"));
                        proc_tocheck = "budgie-previews/previews_daemon";
                        //TRANSLATORS: Window Previews is the name of the application and does not need to be translated
                        msg = (_(
                            (_("Please enable Window Previews"))
                        ));
                        break;
                    }
                    // todo: check below proc-to-check: false warning
                    case "shuffler/togglegui": {
                        msg_header = (_("Missing process"));
                        proc_tocheck = "budgie-window-shuffler/gridwindow";
                        //TRANSLATORS: Window Previews is the name of the application and does not need to be translated
                        msg = (_(
                            (_("Please enable Window Shuffler"))
                        ));
                        break;
                    }
                    case "shuffler": {
                        msg_header = (_("Missing process"));
                        proc_tocheck = "budgie-window-shuffler/windowshufflerdaemon";
                        msg = (_(
                            "Please enable Window Shuffler"
                        ));
                        break;
                    }
                }
                if (proc_tocheck != null) {
                    if (!procruns(proc_tocheck)) {
                        sendwarning(msg_header, msg);
                    }
                }
            }
        }

        private void sendwarning(
            string title, string body, string icon = "budgie-hotcorners-symbolic"
        ) {
            var notification = new Notify.Notification(title, body, icon);
            notification.set_urgency(Notify.Urgency.NORMAL);
            try {
                new Thread<int>.try("clipboard-notify-thread", () => {
                    try{
                        notification.show();
                    } catch (Error e) {
                        error ("Unable to send notification: %s", e.message);
                    }
                    return 0;
                });
            } catch (Error e) {
                error ("Error: %s", e.message);
            }
        }

        private void read_json(
            Json.Parser parser, string command
            ) {
            /* reads json data from gsettings name/command couples */
            try {
                parser.load_from_data (command);
                var root_object = parser.get_root ().get_object ();
                string test = root_object.get_string_member ("name");
                string test2 = root_object.get_string_member ("command");
                dropdown_namelist += translate_gsettingsval(test);
                dropdown_cmdlist += test2;
            }
            catch (Error e) {
                print("Unable to read commands- data\n");
            }
        }

        private void populate_dropdown () {
            /*
            * reads the default dropdown commands/names and populates
            * the dropdown menu
            */
            dropdown_namelist = {};
            var parser = new Json.Parser ();
            string[] dropdown_source = hc_settings.get_strv("dropdown");
            foreach (string s in dropdown_source) {
                read_json(parser, s);
            }
        }

        private void act_on_checkbuttontoggle(ToggleButton button) {
            /*
            * if custom checkbox is toggled, both GUI and command list changes
            * need to take place
            */
            int b_index = HCSupport.get_checkbuttonindex(
                button, cbuttons
            );
            bool active = button.get_active();
            string newcmd = "";
            if (active) {
                Entry new_source = entries[b_index];
                this.attach(new_source, 1, b_index + 1, 1, 1);
                HCSupport.remove_fromgrid(this, dropdowns[b_index]);
                new_source.set_text("");
            }
            else {
                HCSupport.remove_fromgrid(this, entries[b_index]);
                ComboBox newsource = dropdowns[b_index];
                newsource.set_active(0);
                this.attach(newsource, 1, b_index + 1, 1, 1);
                newcmd = dropdown_cmdlist[0];
            }
            commands[b_index] = newcmd;
            hc_settings.set_strv("commands", commands);
            this.show_all();
        }

        private void get_fromcombo (ComboBox combo) {
            /*
            * reads the chosen command from the ComboBoxText and updates
            * the hotcorner/commands list
            */
            /* corner index */
            int combo_index = HCSupport.get_cboxindex(
                combo, dropdowns
            );
            /* command index */
            int command_index = combo.get_active();
            string new_cmd = dropdown_cmdlist[command_index];
            check_dependencies(new_cmd);
            commands[combo_index] = new_cmd;
            hc_settings.set_strv("commands", commands);
        }

        private void toggle_corner(ToggleButton button) {
            /* updates GUI if button is toggled, updates commands accordingly */
            bool active = button.get_active();
            int buttonindex = HCSupport.get_togglebuttonindex(
                button, buttons
            );
            CheckButton currcheck = cbuttons[buttonindex];
            bool custom_isset = currcheck.get_active();
            Entry currentry = entries[buttonindex];
            currentry.set_text("");
            ComboBox currdrop = dropdowns[buttonindex];
            string newcmd = "";
            if (active) {
                if (custom_isset) {
                    currentry.set_sensitive(true);
                }
                else {
                    currdrop.set_sensitive(true);
                    newcmd = dropdown_cmdlist[0];
                    currdrop.set_active(0);
                }
            }
            else {
                if (custom_isset) {
                    currentry.set_sensitive(false);
                }
                else {
                    currdrop.set_sensitive(false);
                }
            }
            commands[buttonindex] = newcmd;
            hc_settings.set_strv("commands", commands);
            currcheck.set_sensitive(active);
        }
    }

    private string translate_gsettingsval (string fetched) {
        string translated = (_(fetched));
        return translated;
    }

    private bool procruns (string processname) {
        string cmd = Config.PACKAGE_BINDIR + @"/pgrep -f $processname";
        string output;
        try {
            GLib.Process.spawn_command_line_sync(cmd, out output);
            if (output == "") {
                return false;
            }
        }
        /* on an unlike to happen exception, return true */
        catch (SpawnError e) {
            return true;
        }
        return true;
    }


    public class HotCornersSettings : Gtk.Grid {
        /* Budgie Settings -section */
        GLib.Settings? settings = null;
        Gtk.Grid testgrid;
        Gtk.Label spacelabel1;

        public HotCornersSettings(GLib.Settings? settings)
        {
            this.settings = settings;
            // toggle settings via panel icon
            Gtk.CheckButton toggle_settingslocation = new Gtk.CheckButton.with_label(
                (_("Manage corners from panel icon"))
            );
            this.attach(toggle_settingslocation, 0, 1, 1, 1);
            spacelabel1 = new Label("");
            toggle_settingslocation.toggled.connect(toggle_cornersection);
            toggle_settingslocation.set_active(showpanelicon);
            add_cornersection(!showpanelicon);
            // prevent-unintended section
            // - label
            this.attach(new Gtk.Label("\n"), 0, 9, 1, 1);
            Label prevent_unintendedlabel = new Label(_(
                "To prevent unintended activation, use:"
            ) + "\n");
            prevent_unintendedlabel.set_xalign(0);
            this.attach(prevent_unintendedlabel, 0, 19, 1, 1);
            // - dropdown
            Box preventbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            string[] preventstrings = {"Pressure", "Delay", "None"};
            var delay_orpressure_combo = new ComboBoxText();
            delay_orpressure_combo.set_size_request(100, 20);
            string[] conditions = {
                _("Pressure"),
                _("Delay"),
                _("Nothing")
            };
            foreach (string effect in conditions) {
                delay_orpressure_combo.append_text(effect);
            }
            // initiate-gui elements
            update_preventmethodcombo(delay_orpressure_combo, preventstrings); // make vice versa, nah, not for now?
            // - delay-slider
            Gtk.Scale delay_slider = new Gtk.Scale.with_range(
                Gtk.Orientation.HORIZONTAL, 0, 100, 5
            );
            delay_slider.draw_value = false;
            delay_slider.set_value(hc_settings.get_int("delay"));
            delay_slider.value_changed.connect(()=> {
                hc_settings.set_value("delay", (int)delay_slider.get_value());
            });
            // - pressure-slider
            Gtk.Scale pressure_slider = new Gtk.Scale.with_range(
                Gtk.Orientation.HORIZONTAL, 0, 100, 5
            );
            pressure_slider.draw_value = false;
            pressure_slider.set_value(hc_settings.get_int("pressure"));
            pressure_slider.value_changed.connect(()=> {
                hc_settings.set_value("pressure", (int)pressure_slider.get_value());
            });
            // set action
            delay_orpressure_combo.changed.connect(()=> {
                string newval = preventstrings[delay_orpressure_combo.get_active()];
                hc_settings.set_string("preventmethod", newval);
                grid_slider(this, delay_slider, pressure_slider);
            });
            preventbox.pack_start(delay_orpressure_combo, false, false, 0);
            this.attach(preventbox, 0, 20, 1, 1);
            this.attach(new Gtk.Label(""), 0, 21, 1, 1);
            grid_slider(this, delay_slider, pressure_slider);
            this.show_all();
        }

        private void grid_slider (
            Gtk.Grid grid, Gtk.Scale delayslider, Gtk.Scale pressureslider
        ) {
            HCSupport.remove_fromgrid(grid, delayslider);
            HCSupport.remove_fromgrid(grid, pressureslider);
            string method = hc_settings.get_string("preventmethod");
            switch (method) {
                case "Delay":
                grid.attach(delayslider, 0, 22, 1, 1);
                break;
                case "Pressure":
                grid.attach(pressureslider, 0, 22, 1, 1);
                break;
            }
            grid.show_all();
        }

        private void update_preventmethodcombo (ComboBoxText combo, string[] preventstrings) {
            string currmethod = hc_settings.get_string("preventmethod");
            int currmethodindex = HCSupport.get_stringindex (currmethod, preventstrings);
            combo.set_active(currmethodindex);
        }

        private void add_cornersection (bool showsection) {
            if (showsection) {
                testgrid = new SettingsGrid();
                this.attach(testgrid, 0, 3, 3, 1);
                this.attach(spacelabel1, 0, 2, 1, 1);
            }
        }

        private void toggle_cornersection (ToggleButton b) {
            bool newval = b.get_active();
            if (newval) {
                HCSupport.remove_fromgrid(this, testgrid);
                HCSupport.remove_fromgrid(this, spacelabel1);
            }
            else {
                add_cornersection(true);
            }
            hc_settings.set_boolean("panelicon", newval);
        }
    }


    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {

        public Budgie.Applet get_panel_widget(string uuid) {
            return new Applet(uuid);
        }
    }


    public class HotCornersPopover : Budgie.Popover {

        private Gtk.EventBox indicatorBox;
        private Gtk.Image indicatorIcon;

        public HotCornersPopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);
            this.indicatorBox = indicatorBox;
            /* set icon */
            this.indicatorIcon = new Gtk.Image.from_icon_name(
                "budgie-hotcorners-symbolic", Gtk.IconSize.MENU
            );
            indicatorBox.add(this.indicatorIcon);
            Gtk.Grid popoversettings = new SettingsGrid();
            this.add(popoversettings);
        }
    }


    public class Applet : Budgie.Applet {

        GLib.Settings? panel_settings;
        GLib.Settings? currpanelsubject_settings;
        bool hotc_onpanel = true;

        string general_path = "com.solus-project.budgie-panel";

        private bool find_applet (string uuid, string[] applets) {
            for (int i = 0; i < applets.length; i++) {
                if (applets[i] == uuid) {
                    return true;
                }
            }
            return false;
        }

        void watchapplet (string uuid) {
            // make applet's loop end if applet is removed
            string[] applets;
            panel_settings = new GLib.Settings(general_path);
            string[] allpanels_list = panel_settings.get_strv("panels");
            foreach (string p in allpanels_list) {
                string panelpath = "/com/solus-project/budgie-panel/panels/".concat("{", p, "}/");
                currpanelsubject_settings = new GLib.Settings.with_path(
                    general_path + ".panel", panelpath
                );

                applets = currpanelsubject_settings.get_strv("applets");
                if (find_applet(uuid, applets)) {
                    currpanelsubject_settings.changed["applets"].connect(() => {
                        applets = currpanelsubject_settings.get_strv("applets");
                        if (!find_applet(uuid, applets)) {
                            hotc_onpanel = false;
                        }
                    });
                    break;
                }
            }
        }






        private Gtk.EventBox indicatorBox;
        private HotCornersPopover popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        public string uuid { public set; public get; }
        /* specifically to the settings section */
        public override bool supports_settings()
        {
            return true;
        }
        public override Gtk.Widget? get_settings_ui()
        {
            return new HotCornersSettings(this.get_applet_settings(uuid));
        }
        private int action_area;
        private bool include_pressure;
        private bool include_delay;
        private int[] x_arr;
        private int[] y_arr;
        private int pressure;
        private int delay;
        private int time_steps;
        int scale;
        int width;
        int height;
        int screen_xpos;
        int screen_ypos;
        Gdk.Display gdkdisplay;
        Gdk.Seat seat;

        public Applet(string uuid) {
            // watch if applet is removed from the panel
            GLib.Timeout.add_seconds(1, ()=> {
                watchapplet(uuid);
                return false;
            });
            // initialize notifications
            Notify.init("Hotcorners");
            hc_settings = HCSupport.get_settings(
                "org.ubuntubudgie.plugins.budgie-hotcorners"
            );
            read_setcommands();
            gdkscreen = this.get_screen();
            showpanelicon = hc_settings.get_boolean("panelicon");
            initialiseLocaleLanguageSupport();
            /* box */
            indicatorBox = new Gtk.EventBox();
            /* Popover */
            popover = new HotCornersPopover(indicatorBox);
            if (showpanelicon) {
                add(indicatorBox);
            }
            hc_settings.changed["panelicon"].connect(set_panelicon);
            /* On Press indicatorBox */
            set_action();
            popover.get_child().show_all();
            show_all();
            gdkscreen.monitors_changed.connect(check_res);
            gdkdisplay = Gdk.Display.get_default();
            seat = gdkdisplay.get_default_seat();
            update_pressure();
            hc_settings.changed.connect(update_pressure);
            watch_loop();
        }

        private void set_action () {
            /* On Press indicatorBox */
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
        }

        private void set_panelicon () {
            showpanelicon = hc_settings.get_boolean("panelicon");
            if (showpanelicon) {
                indicatorBox = new Gtk.EventBox();
                popover = new HotCornersPopover(indicatorBox);
                this.manager.register_popover(indicatorBox, popover);
                set_action();
                this.add(indicatorBox);
                popover.get_child().show_all();
                show_all();
            }
            else {
                indicatorBox.destroy();
            }
        }

        private void check_res() {
            /* see what is the resolution on the primary monitor */
            var prim = gdkdisplay.get_primary_monitor();
            scale = getscale(prim);
            var geo = prim.get_geometry();
            width = geo.width * scale;
            height = geo.height * scale;
            screen_xpos = geo.x * scale;
            screen_ypos = geo.y * scale;
        }

        private int check_corner() {
            /* see if we are in a corner, if so, which one */
            int x;
            int y;
            seat.get_pointer().get_position(null, out x, out y);
            x = x * scale;
            y = y * scale;
            /* add coords to array, edit array */
            x_arr += x;
            x_arr = keepsection(x_arr, this.time_steps);
            y_arr += y;
            y_arr = keepsection(y_arr, this.time_steps);
            int n = -1;
            int innerleft = screen_xpos + this.action_area;
            int innertop = screen_ypos + this.action_area;
            int rightside = screen_xpos + width;
            int bottom = screen_ypos + height;
            int innerbottom = bottom - this.action_area;
            int innerright = rightside - this.action_area;
            bool[] tests = {
                (screen_xpos <= x < innerleft && screen_ypos <= y < innertop), // topleft
                (innerright < x <= rightside && screen_ypos <= y < innertop), // topright
                (screen_xpos <= x < innerleft && innerbottom < y <= bottom), // bottomleft
                (innerright < x <= rightside && innerbottom < y <= bottom) // bottomright
            };
            foreach (bool test in tests) {
                n += 1;
                if (test) {
                    return n;
                }
            }
            return -1;
        }

        private bool decide_onpressure () {
            /* decide if the pressure is enough */
            double x_travel = Math.pow(
                x_arr[0] - x_arr[this.time_steps - 1], 2
            );
            double y_travel = Math.pow(
                y_arr[0] - y_arr[this.time_steps - 1], 2
            );
            double travel = Math.pow(x_travel + y_travel, 0.5);
            if (travel > pressure * 6) {
                return true;
            }
            else {
                return false;
            }
        }

        private int getscale(Gdk.Monitor? prim) {
            // get scale factor of primary (which we are using)

            if (prim != null) {
                return prim.get_scale_factor();
            }
            return 1;
        }

        private int[] keepsection(int[] arr_in, int lastn) {
            /*
            * the last <n> positions will be kept in mind,
            * to decide on pressure
            */
            int[] temparr = {};
            int currlen = arr_in.length;
            if (currlen > lastn) {
                int remove_element = currlen - lastn;
                temparr = arr_in[remove_element:currlen];
                return temparr;
            }
            return arr_in;
        }

        private void update_pressure () {
            // if preventmethod, pressure or delay settings change, update conditions to work with
            pressure = hc_settings.get_int("pressure");
            delay = hc_settings.get_int("delay");
            string preventmethod = hc_settings.get_string("preventmethod");
            switch (preventmethod) {
                case "None":
                include_pressure = false;
                include_delay = false;
                break;
                case "Delay":
                include_pressure = false;
                include_delay = true;
                break;
                case "Pressure":
                include_pressure = true;
                include_delay = false;
                break;
            }
        }

        private int watch_loop(string[] ? args = null) {
            check_res();
            /* here we set the size of the array (20 = 1 sec.) */
            this.action_area = 5;
            /* here we set the time steps (size of array, 20 = last 1 second) */
            this.time_steps = 3;
            x_arr = {0};
            y_arr = {0};
            // reported = command already fired
            bool reported = false;
            int t_delay = 0;
            GLib.Timeout.add (50, () => {
                // check if we arrived at one of the corners
                int corner = check_corner();
                if (corner != -1 && !reported) {
                    // since this is only fired if we are in a corner *and*
                    // command did not run, we can afford to check multiple conditions
                    if (t_delay < 101) {
                        t_delay += 1;
                    }
                    if (check_ifactivate(t_delay)) {
                        run_command(corner);
                        reported = true;
                    }
                }
                else if (corner == -1 ){
                    reported = false;
                    t_delay = 0;
                }
                return hotc_onpanel;
            });
            return 0;
        }

        private bool check_ifactivate(int t_delay) {
            if (
                !(include_pressure || include_delay) ||
                (include_pressure && check_onpressure()) ||
                (include_delay && t_delay > (int)(delay/5))
            ) {
                return true;
            }
            return false;
        }

        private bool check_onpressure () {
            if (include_pressure) {
                bool approve = decide_onpressure();
                return approve;
            }
            else {
                return true;
            }
        }

        private void run_command (int corner) {
            /* execute the command */
            string cmd = commands[corner];
            if (cmd != "" && !HCSupport.locked()) {
                try {
                    Process.spawn_command_line_async(cmd);
                }
                catch (GLib.SpawnError err) {
                    /*
                    * in case an error occurs, the command most likely is
                    * incorrect not much use for any action
                    */
                }
            }
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
}

[ModuleInit]
public void peas_register_types(TypeModule module){
    /* boilerplate - all modules need this */
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(HotCornersApplet.Plugin)
    );
}
