using Gtk;
using Gdk;
using GLib.Math;
using Json;

/*
* HotCornersII
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

namespace HCSupport {

    /*
    * Here we keep the (possibly) shared stuff, or general functions, to
    * keep the main code clean and readable
    */

    private bool locked () {
        string cmd = "pgrep -f gnome-screensaver-dialog";
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

    private bool check_onapplet(string path, string applet_name) {
        /* check if the applet still runs */
        string cmd = "dconf dump " + path;
        string output;
        try {
            GLib.Process.spawn_command_line_sync(cmd, out output);
        }
        /* on an occasional exception, don't break the loop */
        catch (SpawnError e) {
            return true;
        }
        bool check = output.contains(applet_name);
        return check;
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

    public class HotCornersSettings : Gtk.Grid {
        /* Budgie Settings -section */
        GLib.Settings? settings = null;
        private GLib.Settings hc_settings;

        private void edit_pressure(Gtk.Range newpressure) {
            int newval = (int)newpressure.get_value();
            this.hc_settings.set_int("pressure", newval);
        }

        public HotCornersSettings(GLib.Settings? settings)
        {
            this.settings = settings;
            this.hc_settings = HCSupport.get_settings(
                "org.ubuntubudgie.plugins.budgie-hotcorners"
            );
            Gtk.Label pressure_label = new Gtk.Label(
                (_("Set pressure (0 = no pressure)")) + "\n"
            );
            this.attach(pressure_label, 0, 0, 1, 1);
            Gtk.Scale pressure_slider = new Gtk.Scale.with_range(
                Gtk.Orientation.HORIZONTAL, 0, 100, 5
            );
            this.attach(pressure_slider, 0, 1, 1, 1);
            double visible_pressure = (int)hc_settings.get_int("pressure");
            pressure_slider.set_value(visible_pressure);
            pressure_slider.value_changed.connect(edit_pressure);
            this.show_all();
        }
    }


    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {

        public Budgie.Applet get_panel_widget(string uuid) {
            return new Applet();
        }
    }


    public class HotCornersPopover : Budgie.Popover {

        private Gtk.EventBox indicatorBox;
        private Gtk.Image indicatorIcon;
        /* process stuff */
        private int action_area;
        private int[] x_arr;
        private int[] y_arr;
        private int pressure;
        private GLib.Settings hc_settings;
        private int time_steps;
        private bool include_pressure;
        /* GUI stuff */
        private Grid maingrid;
        private Entry[] entries;
        private ToggleButton[] buttons;
        private CheckButton[] cbuttons;
        private string[] commands;
        private ComboBox[] dropdowns;
        private string[] dropdown_namelist;
        private string[] dropdown_cmdlist;
        /* misc stuff */
        private string[] check_commands;
        private string[] check_applets;

        public HotCornersPopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);
            this.indicatorBox = indicatorBox;
            /* set icon */
            this.indicatorIcon = new Gtk.Image.from_icon_name(
                "budgie-hotcorners-symbolic", Gtk.IconSize.MENU
            );
            indicatorBox.add(this.indicatorIcon);

            /* gsettings stuff */
            this.hc_settings = HCSupport.get_settings(
                "org.ubuntubudgie.plugins.budgie-hotcorners"
            );
            populate_dropdown ();
            populate_checkups ();
            read_setcommands ();
            update_pressure ();
            this.hc_settings.changed["pressure"].connect(update_pressure);
            /* data */
            string css_data = """
            .label {
                padding-bottom: 3px;
                padding-top: 3px;
                font-weight: bold;
            }
            """;
            /* grid */
            this.maingrid = new Gtk.Grid();
            this.maingrid.set_row_spacing(7);
            this.maingrid.set_column_spacing(7);
            this.add(this.maingrid);
            /* Corner label */
            var cornerlabel = new Gtk.Label(" " + (_("Corner")));
            cornerlabel.set_xalign(0);
            this.maingrid.attach(cornerlabel, 0, 0, 1, 1);
            /* Action label */
            var actionlabel = new Gtk.Label(" " + (_("Action")));
            actionlabel.set_xalign(0);
            this.maingrid.attach(actionlabel, 1, 0, 1, 1);
            /* Custom label */
            var customlabel = new Gtk.Label(" " + (_("Custom")));
            customlabel.set_xalign(0);
            this.maingrid.attach(customlabel, 2, 0, 2, 1);
            /* set styling of headers */
            Label[] headers = {
                cornerlabel, actionlabel, customlabel
            };
            var screen = this.get_screen ();
            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_data(css_data);
            Gtk.StyleContext.add_provider_for_screen(
                screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
            );
            foreach (Label l in headers) {
                l.get_style_context().add_class("label");
            };
            /* toggle buttons -names*/
            string[] namelist = {
                (_("Top-left")), (_("Top-right")), (_("Bottom-left")), (_("Bottom-right"))
            };
            /* create rows */
            int y_pos = 1;
            foreach (string name in namelist) {
                /* create toggle buttons */
                var latest_togglebutton = new ToggleButton.with_label(name);
                buttons += latest_togglebutton;
                this.maingrid.attach(latest_togglebutton, 0, y_pos, 1, 1);
                /* create entries */
                var latest_entry = new Entry();
                this.entries += latest_entry;
                latest_entry.set_size_request(220, 20);
                /* create dropdown */
                var command_combo = new ComboBoxText();
                command_combo.set_size_request(220, 20);
                foreach (string cmd_name in this.dropdown_namelist) {
                    command_combo.append_text(cmd_name);
                }
                this.dropdowns += command_combo;
                /* space */
                var spacer = new Label(" ");
                this.maingrid.attach(spacer, 2, y_pos, 1, 1);
                var spacer2 = new Label(" ");
                this.maingrid.attach(spacer2, 4, y_pos, 1, 1);
                /* checkbutton cusom command */
                var latest_check = new CheckButton();
                this.cbuttons += latest_check;
                this.maingrid.attach(latest_check, 3, y_pos, 1, 1);
                /* populate with command situation */
                string set_command = this.commands[y_pos - 1];
                if (set_command == "") {
                    latest_togglebutton.set_active(false);
                    this.maingrid.attach(command_combo, 1, y_pos, 1, 1);
                    command_combo.set_sensitive(false);
                    latest_check.set_sensitive(false);
                }
                else {
                    latest_togglebutton.set_active(true);
                    bool test = HCSupport.command_isdefault(
                        set_command, this.dropdown_cmdlist
                    );
                    if (test == true) {
                        this.maingrid.attach(command_combo, 1, y_pos, 1, 1);
                        int combo_index = HCSupport.get_stringindex(
                            set_command, this.dropdown_cmdlist
                        );
                        command_combo.active = combo_index;
                        latest_check.set_active(false);
                    }
                    else {
                        this.maingrid.attach(latest_entry, 1, y_pos, 1, 1);
                        latest_entry.set_text(set_command);
                        latest_check.set_active(true);
                    }
                }
                latest_togglebutton.toggled.connect(toggle_corner);
                latest_check.toggled.connect(act_on_checkbuttontoggle);
                command_combo.changed.connect(get_fromcombo);
                latest_entry.changed.connect(update_fromentry);
                this.hc_settings.set_strv("commands", this.commands);
                y_pos += 1;
            }
            watch_loop();
        }

        private string translate_gsettingsval (string fetched) {
            string translated = (_(fetched));
            return translated;
        }

        private void update_pressure () {
            this.pressure = this.hc_settings.get_int("pressure");
            if (this.pressure > 0) {
                this.include_pressure = true;
            }
            else {
                this.include_pressure = false;
            }
        }

        private void sendwarning () {
            string set_icon = "notify-send -i budgie-hotcorners-symbolic ";
            string header = "'" + (_("Missing applet")) + "'";
            // WindowPreviews is the name of a Budgie Applet and does not need to be translated
            string body = " '" + (_("Please add WindowPreviews")) + "'";
            string command = set_icon.concat(header, body);
            Process.spawn_command_line_async(command);
        }

        private void update_fromentry(Editable entry) {
            /* reads the entry and edits the corner / commands list */
            int buttonindex = HCSupport.get_entryindex(
                entry, this.entries
            );
            string new_cmd = entry.get_chars(0, 100);
            this.commands[buttonindex] = new_cmd;
            this.hc_settings.set_strv("commands", this.commands);
        }

        private void get_fromcombo (ComboBox combo) {
            /*
            * reads the chosen command from the ComboBoxText and updates
            * the hotcorner/commands list
            */
            /* corner index */
            int combo_index = HCSupport.get_cboxindex(
                combo, this.dropdowns
            );
            /* command index */
            int command_index = combo.get_active();
            string new_cmd = dropdown_cmdlist[command_index];
            int matches_index = HCSupport.get_stringindex(
                new_cmd, this.check_commands
            );
            if (matches_index != -1) {
                string checkname = this.check_applets[matches_index];
                bool check = HCSupport.check_onapplet(
                    "/com/solus-project/budgie-panel/applets/",
                    checkname
                );
                if (check == false) {
                    sendwarning();
                }
            }
            this.commands[combo_index] = new_cmd;
            this.hc_settings.set_strv("commands", this.commands);
        }

        private void act_on_checkbuttontoggle(ToggleButton button) {
            /*
            * if custom checkbox is toggled, both GUI and command list changes
            * need to take place
            */
            int b_index = HCSupport.get_checkbuttonindex(
                button, this.cbuttons
            );
            bool active = button.get_active();
            string newcmd = "";
            if (active) {
                Entry new_source = this.entries[b_index];
                this.maingrid.attach(new_source, 1, b_index + 1, 1, 1);
                this.maingrid.remove(this.dropdowns[b_index]);
                new_source.set_text("");
            }
            else {
                this.maingrid.remove(this.entries[b_index]);
                ComboBox newsource = this.dropdowns[b_index];
                newsource.set_active(0);
                this.maingrid.attach(newsource, 1, b_index + 1, 1, 1);
                newcmd = this.dropdown_cmdlist[0];
            }
            this.commands[b_index] = newcmd;
            this.hc_settings.set_strv("commands", this.commands);
            this.show_all();
        }

        private void toggle_corner(ToggleButton button) {
            /* updates GUI if button is toggled, updates commands accordingly */
            bool active = button.get_active();
            int buttonindex = HCSupport.get_togglebuttonindex(
                button, this.buttons
            );
            CheckButton currcheck = this.cbuttons[buttonindex];
            bool custom_isset = currcheck.get_active();
            Entry currentry = this.entries[buttonindex];
            currentry.set_text("");
            ComboBox currdrop = this.dropdowns[buttonindex];
            string newcmd = "";
            if (active) {
                if (custom_isset) {
                    currentry.set_sensitive(true);
                }
                else {
                    currdrop.set_sensitive(true);
                    newcmd = this.dropdown_cmdlist[0];
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
            this.commands[buttonindex] = newcmd;
            this.hc_settings.set_strv("commands", this.commands);
            currcheck.set_sensitive(active);
        }

        private void populate_dropdown () {
            /*
            * reads the default dropdown commands/names and populates
            * the dropdown menu
            */
            var parser = new Json.Parser ();
            string[] dropdown_source = this.hc_settings.get_strv("dropdown");
            foreach (string s in dropdown_source) {
                read_json(parser, s);
            }
        }

        private void read_setcommands () {
            /* get the initially set commands */
            this.commands = this.hc_settings.get_strv("commands");
        }

        private void read_json(
            Json.Parser parser, string command
            ) {
            /* reads json data from gsettings name/command couples */
            parser.load_from_data (command);
            var root_object = parser.get_root ().get_object ();
            string test = root_object.get_string_member ("name");
            string test2 = root_object.get_string_member ("command");
            this.dropdown_namelist += translate_gsettingsval(test);
            this.dropdown_cmdlist += test2;
        }

        private void populate_checkups () {
            /*
            * reads the default checkups commands/names and populates
            * the arrays
            */
            var parser = new Json.Parser ();
            string[] checkup_source = this.hc_settings.get_strv(
                "appletdependencies"
            );
            foreach (string s in checkup_source) {
                read_checkups(parser, s);
            }
        }

        private void read_checkups(
            Json.Parser parser, string command
            ) {
            /* I know, stupidly repeated code, but hey, this is Vala */
            parser.load_from_data (command);
            var root_object = parser.get_root ().get_object ();
            string test = root_object.get_string_member ("name");
            string test2 = root_object.get_string_member ("command");
            this.check_applets += test;
            this.check_commands += test2;
        }

        private int[] keepsection(int[] arr_in, int lastn) {
            /*
            * the last <n> positions will be kept in mind,
            * to decide on pressure
            */
            int[] temparr = {};
            int currlen = arr_in.length;
            if (currlen > lastn) {
                int remove = currlen - lastn;
                temparr = arr_in[remove:currlen];
                return temparr;
            }
            return arr_in;
        }

        private int[] check_res() {
            /* see what is the resolution on the primary monitor */
            var prim = Gdk.Display.get_default().get_primary_monitor();
            var geo = prim.get_geometry();
            int width = geo.width;
            int height = geo.height;
            int screen_xpos = geo.x;
            int screen_ypos = geo.y;
            return {width, height, screen_xpos, screen_ypos};
        }

        private int check_corner(int xres, int yres, int x_offset, int y_offset, Seat seat) {
            /* see if we are in a corner, if so, which one */
            int x;
            int y;
            seat.get_pointer().get_position(null, out x, out y);
            /* add coords to array, edit array */
            this.x_arr += x;
            this.x_arr = keepsection(this.x_arr, this.time_steps);
            this.y_arr += y;
            this.y_arr = keepsection(this.y_arr, this.time_steps);
            int n = -1;

            int innerleft = x_offset + this.action_area;
            int innertop = y_offset + this.action_area;
            int rightside = x_offset + xres;
            int bottom = y_offset + yres;
            int innerbottom = bottom - this.action_area;
            int innerright = rightside - this.action_area;
            bool[] tests = {
                (x_offset <= x < innerleft && y_offset <= y < innertop),
                (innerright < x < rightside && y_offset <= y < innertop),
                (x_offset <= x < innerleft && innerbottom < y <= bottom),
                (innerright < x <= rightside && innerbottom < y <= bottom)
            };
            foreach (bool test in tests) {
                n += 1;
                if (test == true) {
                    return n;
                }
            }
            return -1;
        }

        private bool check_onpressure () {
            if (this.include_pressure == true) {
                bool approve = decide_onpressure();
                return approve;
            }
            else {
                return true;
            }
        }

        private bool decide_onpressure () {
            /* decide if the pressure is enough */
            double x_travel = Math.pow(
                this.x_arr[0] - this.x_arr[this.time_steps - 1], 2
            );
            double y_travel = Math.pow(
                this.y_arr[0] - this.y_arr[this.time_steps - 1], 2
            );
            double travel = Math.pow(x_travel + y_travel, 0.5);
            if (travel > this.pressure * 3) {
                return true;
            }
            else {
                return false;
            }
        }

        private int watch_loop(string[] ? args = null) {
            Gdk.init(ref args);
            Gdk.Seat seat = Gdk.Display.get_default().get_default_seat();
            int[] res = check_res();
            /* here we set the size of the array (20 = 1 sec.) */
            this.action_area = 5;
            /* here we set the time steps (size of array, 20 = last 1 second) */
            this.time_steps = 3;
            this.x_arr = {0};
            this.y_arr = {0};
            int xres = res[0];
            int yres = res[1];
            // new args
            int x_offset = res[2];
            int y_offset = res[3];
            bool reported = false;
            int t = 0;
            GLib.Timeout.add (50, () => {
                t += 1;
                if (t == 30) {
                    t = 0;
                    bool check = HCSupport.check_onapplet(
                        "/com/solus-project/budgie-panel/applets/",
                        "HotCorners"
                    );
                    if (check == false) {
                        return false;
                    }
                }
                int corner = check_corner(xres, yres, x_offset, y_offset, seat);
                if (corner != -1 && reported == false) {
                    if (check_onpressure() == true) {
                        run_command(corner);
                        reported = true;
                    }
                }
                else if (corner == -1) {
                    reported = false;
                }
                return true;
            });
            return 0;
        }

        private void run_command (int corner) {
            /* execute the command */
            string cmd = this.commands[corner];
            if (cmd != "" && HCSupport.locked() == false) {
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
    }


    public class Applet : Budgie.Applet {

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

        public Applet() {
            initialiseLocaleLanguageSupport();
            /* box */
            indicatorBox = new Gtk.EventBox();
            add(indicatorBox);
            /* Popover */
            popover = new HotCornersPopover(indicatorBox);
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
            popover.get_child().show_all();
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
}

[ModuleInit]
public void peas_register_types(TypeModule module){
    /* boilerplate - all modules need this */
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(HotCornersApplet.Plugin)
    );
}
