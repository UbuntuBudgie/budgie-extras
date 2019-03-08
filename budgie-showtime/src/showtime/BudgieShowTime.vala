using Gtk;
using Gdk;
using Math;
using Wnck;

/*
* BudgieShowTimeII
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


namespace BudgieShowTimeApplet {

    private string moduledir;

    public class BudgieShowTimeSettings : Gtk.Grid {

        /* Budgie Settings -section */
        GLib.Settings? settings = null;
        Button dragbutton;
        RadioButton[] anchorbuttons;
        string[] anchors;
        string curr_anchor;
        CheckButton leftalign;
        CheckButton twelve_hrs;
        Gtk.FontButton timefontbutton;
        Gtk.FontButton datefontbutton;
        Gtk.ColorButton timecolor;
        Gtk.ColorButton datecolor;
        Gtk.SpinButton linespacing;
        GLib.Settings showtime_settings;
        Label draghint;
        string dragposition;
        string fixposition;
        Grid anchorgrid;
        CheckButton autopos;
        Label spinlabel;

        public BudgieShowTimeSettings(GLib.Settings? settings) {

            this.settings = settings;
            // translated strings
            dragposition = (_("Drag position"));
            fixposition = (_("Save position"));
            string stsettings_css = ".st_header {font-weight: bold;}";
            string dragtext = (_(
                "Enable Super + drag to set time position. Click ´Save position´ to save."
            ));
            showtime_settings =  new GLib.Settings(
                "org.ubuntubudgie.plugins.budgie-showtime"
            );
            var screen = this.get_screen();
            // window content
            this.set_row_spacing(10);
            var position_header = new Gtk.Label(_("Position & anchor"));
            position_header.xalign = 0;
            this.attach(position_header, 0, 0, 10, 1);
            // automatic positioning
            autopos = new CheckButton.with_label((_("Automatic")));
            // first get setting
            autopos.toggled.connect(toggle_autopos);
            this.attach(autopos, 0, 1, 10, 1);
            // drag button
            dragbutton = new Gtk.Button();
            dragbutton.set_tooltip_text(dragtext);
            dragbutton.set_label(_("Drag position"));
            dragbutton.set_size_request(150, 10);
            draghint = new Gtk.Label("");
            draghint.xalign = (float)0.5;
            //this.attach(draghint, 0, 2, 2, 1);
            // anchor section
            anchorgrid = new Gtk.Grid();
            var leftspace = new Gtk.Label("\t");
            var centerlabel = new Gtk.Label("\t");
            anchorgrid.attach(leftspace, 1, 0, 1, 1);
            anchorgrid.attach(centerlabel, 3, 1, 1, 1);
            // group leader
            var nw = new RadioButton(null);
            // group
            anchors = {"nw", "ne", "se", "sw"};
            var ne = new RadioButton(nw.get_group());
            var se = new RadioButton(nw.get_group());
            var sw = new RadioButton(nw.get_group());
            anchorgrid.attach(nw, 2, 0, 1, 1);
            anchorgrid.attach(ne, 4, 0, 1, 1);
            anchorgrid.attach(se, 4, 2, 1, 1);
            anchorgrid.attach(sw, 2, 2, 1, 1);
            anchorgrid.attach(dragbutton, 0, 1, 1, 1);
            anchorgrid.attach(draghint, 0, 0, 1, 1);
            this.attach(anchorgrid, 0, 2, 2, 1);
            // group stuff
            anchorbuttons = {nw, ne, se, sw};
            anchors = {"nw", "ne", "se", "sw"};
            curr_anchor = showtime_settings.get_string("anchor");
            anchorbuttons[
                get_stringindex(anchors, curr_anchor)
            ].set_active(true);
            // time font settings -> boxed!!
            var time_header = new Gtk.Label(_("Time font, size & color"));
            time_header.xalign = 0;
            this.attach(time_header, 0, 6, 10, 1);
            var timebox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.attach(timebox, 0, 7, 10, 1);
            timefontbutton = new FontButton();
            timebox.pack_start(timefontbutton, false, false, 0);
            timecolor = new Gtk.ColorButton();
            timebox.pack_start(timecolor, false, false, 0);
            var spacelabel3 = new Gtk.Label("");
            this.attach(spacelabel3, 1, 8, 1, 1);
            // date font settings
            var date_header = new Gtk.Label(_("Date font, size & color"));
            date_header.xalign = 0;
            this.attach(date_header, 0, 10, 10, 1);
            var datebox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.attach(datebox, 0, 11, 10, 1);
            datefontbutton = new FontButton();
            datebox.pack_start(datefontbutton, false, false, 0);
            datecolor = new Gtk.ColorButton();
            datebox.pack_start(datecolor, false, false, 0);
            var spacelabel5 = new Gtk.Label("");
            this.attach(spacelabel5, 1, 12, 1, 1);
            // miscellaneous section
            var general_header = new Gtk.Label(_("Miscellaneous"));
            general_header.xalign = 0;
            this.attach(general_header, 0, 20, 10, 1);
            leftalign = new Gtk.CheckButton.with_label(_("Left align text"));
            this.attach(leftalign, 0, 21, 10, 1);
            twelve_hrs = new Gtk.CheckButton.with_label(_("Use 12hr time format"));
            this.attach(twelve_hrs, 0, 22, 10, 1);
            var spacelabel6 = new Gtk.Label("");
            this.attach(spacelabel6, 1, 23, 1, 1);
            Gtk.Box linespacebox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            this.attach(linespacebox, 0, 30, 3, 1);
            linespacing = new Gtk.SpinButton.with_range (-50, 50, 1);
            linespacebox.pack_start(linespacing, false, false, 0);
            spinlabel = new Gtk.Label(_("Linespacing"));
            linespacebox.pack_start(spinlabel, false, false, 0);
            // Set style on headers
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(stsettings_css);
                Gtk.StyleContext.add_provider_for_screen(
                    screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }
            Label[] boldones = {
                time_header, date_header, general_header, position_header
            };
            foreach (Label l in boldones) {
                l.get_style_context().add_class("st_header");
            };
            set_initialvals();
            connect_widgets();
            this.show_all();
        }

        private int get_stringindex (string[] arr, string lookfor) {
            // get index of string in list
            for (int i=0; i < arr.length; i++) {
                if(lookfor == arr[i]) return i;
            }
            return -1;
        }

        private void set_anchor (ToggleButton button) {
            int n = 0;
            string newanchor = "se";
            foreach (ToggleButton b in anchorbuttons) {
                if (b == button) {
                    newanchor = anchors[n];
                }
                n += 1;
            }
            update_xy_gsettings(newanchor);
        }

        private void update_xy_gsettings (string newanchor) {
            /*
            if anchor or dragged position changes,
            update gsettings position and anchor
            */
            int[] windata = getwindata();
            int newx = windata[0];
            int newy = windata[1];
            if (newanchor.contains("e")) {
                newx = windata[0] + windata[2];
            }
            if (newanchor.contains("s")) {
                newy = windata[1] + windata[3];
            }
            curr_anchor = newanchor;
            // Set gsettings!! both xpos/ypos & anchor...
            showtime_settings.set_string("anchor", curr_anchor);
            showtime_settings.set_int("xposition", newx);
            showtime_settings.set_int("yposition", newy);
        }

        private int[] getwindata () {
            int x;
            int y;
            int wth;
            int hth;
            unowned Wnck.Screen scr = Wnck.Screen.get_default();
            scr.force_update();
            unowned List<Wnck.Window> wins = scr.get_windows();
            foreach (Wnck.Window w in wins) {
                if (w.get_name() == "Showtime") {
                    w.get_geometry(out x, out y, out wth, out hth);
                    return {x, y, wth, hth};
                }
            }
            return {0, 0, 0, 0};
        }

        private void set_newlinespacing (SpinButton button, string setting) {
            // get current settings from button, set gsetings
            int newval = (int)button.get_value();
            showtime_settings.set_int(setting, newval);
        }

        private void set_initialvals () {
            // fetch current settings, set widgets
            set_initiallinespacing(linespacing, "linespacing");
            set_initialdrag();
            set_initialcolor(timecolor, "timefontcolor");
            set_initialcolor(datecolor, "datefontcolor");
            set_initialcheck(leftalign, "leftalign");
            set_initialcheck(twelve_hrs, "twelvehrs");
            set_initialfont(timefontbutton, "timefont");
            set_initialfont(datefontbutton, "datefont");
            set_initialautopos();
        }

        public void set_initialautopos () {
            bool newval = showtime_settings.get_boolean("autoposition");
            autopos.set_active(newval);
            anchorgrid.set_sensitive(!newval);
        }

        private void set_initialfont (FontButton button, string setting) {
            // color to show on the button
            string currval = showtime_settings.get_string(setting);
            button.set_font(currval);
        }

        private void set_initiallinespacing (SpinButton button, string setting) {
            // color to show on the button
            int currval = showtime_settings.get_int(setting);
            button.set_value(currval);
        }

        private void set_initialcheck (CheckButton button, string setting) {
            // checkboxes - initials
            bool currval = showtime_settings.get_boolean(setting);
            button.set_active(currval);
        }

        private void connect_widgets () {
            // as the name sais
            linespacing.value_changed.connect (() => {
                set_newlinespacing(linespacing, "linespacing");
            });
            dragbutton.clicked.connect(toggle_drag);
            timecolor.color_set.connect (() => {
                set_hexcolor(timecolor, "timefontcolor");
            });
            datecolor.color_set.connect (() => {
                set_hexcolor(datecolor, "datefontcolor");
            });
            timefontbutton.font_set.connect (() => {
                set_newfont(timefontbutton, "timefont");
            });
            datefontbutton.font_set.connect (() => {
                set_newfont(datefontbutton, "datefont");
            });
            leftalign.toggled.connect (() => {
                toggle_value(leftalign, "leftalign");
            });
            twelve_hrs.toggled.connect (() => {
                toggle_value(twelve_hrs, "twelvehrs");
            });
            // connect anchors
            foreach (RadioButton b in anchorbuttons) {
                b.toggled.connect (() => {
                    filter_active(b);
                });
            }
        }

        private void filter_active (ToggleButton button) {
            // only act on activating button, not on deactivating
            if (button.get_active()) {
                set_anchor(button);
            }
        }

        private void toggle_autopos (ToggleButton button) {
            bool val = button.get_active();
            if (!val) {
                /*
                if automatic is switched off start off from the current
                position and anchor settings
                */
                int[] currpos = getwindata();
                int newx = currpos[0] + currpos[2];
                int newy = currpos[1] + currpos[3];
                showtime_settings.set_int("xposition", newx);
                showtime_settings.set_int("yposition", newy);
                showtime_settings.set_string("anchor", "se");
            }
            anchorbuttons[2].set_active(true);
            anchorgrid.set_sensitive(!val);
            showtime_settings.set_boolean("autoposition", val);
        }

        private void set_hexcolor(ColorButton button, string setting) {
            Gdk.RGBA c = button.get_rgba();
            string s =
            "#%02x%02x%02x"
            .printf((uint)(Math.round(c.red*255)),
                    (uint)(Math.round(c.green*255)),
                    (uint)(Math.round(c.blue*255))).up();
            showtime_settings.set_string(setting, s);
        }

        private void set_newfont(FontButton button, string newfont) {
            showtime_settings.set_string(newfont, button.get_font());
        }

        private void toggle_value (CheckButton button, string setting) {
            // toggle callback
            bool newval = button.get_active();
            showtime_settings.set_boolean(setting, newval);
        }

        private void set_initialcolor (ColorButton button, string setting) {
            // get current settings from gsetting, set button color
            Gdk.RGBA currcolor = Gdk.RGBA();
            currcolor.parse(showtime_settings.get_string(setting));
            button.set_rgba(currcolor);
        }

        private void set_initialdrag () {
            // get current settings from gsettinsg, set dragbutton label
            bool curr_draggable = showtime_settings.get_boolean("draggable");
            toggle_sensitive(!curr_draggable);
            dragbutton.set_label(dragposition);
            if (curr_draggable) {
                dragbutton.set_label(fixposition);
            }
        }

        private void toggle_sensitive (bool active) {
            autopos.set_sensitive(active);
            foreach (RadioButton b in anchorbuttons) {
                b.set_sensitive(active);
            }
            datefontbutton.set_sensitive(active);
            datecolor.set_sensitive(active);
            timefontbutton.set_sensitive(active);
            timecolor.set_sensitive(active);
            leftalign.set_sensitive(active);
            twelve_hrs.set_sensitive(active);
            linespacing.set_sensitive(active);
            spinlabel.set_sensitive(active);
        }

        private void toggle_drag () {
            // act on toggling drag, change label, set widgets
            bool curr_draggable = showtime_settings.get_boolean("draggable");
            toggle_sensitive(curr_draggable);
            // update gsettings toggle setting
            showtime_settings.set_boolean("draggable", !curr_draggable);
            if (curr_draggable) {
                dragbutton.set_label(dragposition);
                draghint.set_text("");
                update_xy_gsettings(curr_anchor);
            }
            else {
                dragbutton.set_label(fixposition);
                draghint.set_text(_("Super + drag"));
            }
        }
    }

    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {

        public Budgie.Applet get_panel_widget(string uuid) {
            var info = this.get_plugin_info();
            moduledir = info.get_module_dir();
            return new Applet();
        }
    }

    public class Applet : Budgie.Applet {

        public string uuid { public set; public get; }
        public override bool supports_settings()
        {
            return true;
        }
        public override Gtk.Widget? get_settings_ui()
        {
            return new BudgieShowTimeSettings(this.get_applet_settings(uuid));
        }

        private void open_window(string path) {
            // call the desktop showtime window
            bool win_exists = check_onwindow(path);
            if (!win_exists) {
                try {
                    Process.spawn_command_line_async(path);
                }
                catch (SpawnError e) {
                    /* nothing to be done */
                }
            }
        }

        private bool check_onwindow(string path) {
            // check if the desktop window exists
            string cmd_check = "pgrep -f " + path;
            string output;
            try {
                GLib.Process.spawn_command_line_sync(cmd_check, out output);
                if (output == "") {
                    return false;
                }
            }
            catch (SpawnError e) {
                /* let's say it always works */
               return false;
            }
            return true;
        }

        public Applet() {
            // call desktop window
            open_window(moduledir.concat("/showtime_desktop"));
            initialiseLocaleLanguageSupport();
        }

        public void initialiseLocaleLanguageSupport() {
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
        Budgie.Plugin), typeof(BudgieShowTimeApplet.Plugin)
    );
}