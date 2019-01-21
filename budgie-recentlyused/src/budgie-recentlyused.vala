using Gtk;
using Gee;

/*
* RecentlyUsed
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

namespace RecentlyUsedApplet {

    private GLib.Settings rused_settings;
    private int n_show;
    private bool showtooltips;
    private bool hidepath;


    public class RecentlyUsedSettings : Gtk.Grid {
        public RecentlyUsedSettings(GLib.Settings? settings) {
            // spinbutton section (menu length)
            Label spbuttonlabel = new Gtk.Label(
                "\n" + (_("Show last used")) + ":\n"
            );
            this.attach(spbuttonlabel, 0, 0, 2, 1);
            spbuttonlabel.xalign = 0;
            Gtk.SpinButton show_n = new Gtk.SpinButton.with_range(5, 30, 5);
            show_n.set_value(n_show);
            show_n.value_changed.connect(update_n_show);
            this.attach(show_n, 0, 1, 1, 1);
            Label distlabel = new Label("\n");
            this.attach(distlabel, 0, 2, 2, 1);
            // show tooltips section
            CheckButton set_tooltips = new Gtk.CheckButton.with_label(
                (_("Show tooltips"))
            );
            set_tooltips.set_active(showtooltips);
            set_tooltips.toggled.connect(update_settootips);
            this.attach(set_tooltips, 0, 3, 2, 1);
            Label distlabel2 = new Label("\n");
            this.attach(distlabel2, 0, 4, 2, 1);
            // hide path section
            CheckButton set_hidepath = new Gtk.CheckButton.with_label(
                (_("Hide path in menu"))
            );
            set_hidepath.set_active(hidepath);
            set_hidepath.toggled.connect(update_hidepath);
            this.attach(set_hidepath, 0, 5, 2, 1);
            this.show_all();
        }

        private void update_settootips(ToggleButton btn) {
            bool newval = btn.get_active();
            rused_settings.set_boolean("showtooltips", newval);
        }

        private void update_hidepath(ToggleButton btn) {
            bool newval = btn.get_active();
            rused_settings.set_boolean("hidepath", newval);
        }

        private void update_n_show(SpinButton btn) {
            int newval = (int) btn.get_value();
            rused_settings.set_value("nitems", newval);
        }
    }


    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget(string uuid) {
            return new Applet();
        }
    }


    public class Applet : Budgie.Applet {

        private File infofile;
        private Gtk.Menu recent;
        private FileMonitor monitor;
        private Gtk.MenuButton button;
        private Gtk.EventBox indicatorBox;
        public string uuid { public set; public get; }
        /* specifically to the settings section */
        public override bool supports_settings()
        {
            return true;
        }
        public override Gtk.Widget? get_settings_ui()
        {
            return new RecentlyUsedSettings(this.get_applet_settings(uuid));
        }

        public Applet() {
            string home = GLib.Environment.get_home_dir();
            string infosrc = home.concat("/.local/share/recently-used.xbel");
            infofile = File.new_for_path(infosrc);
            rused_settings = new GLib.Settings(
                "org.ubuntubudgie.plugins.budgie-recentlyused"
            );
            rused_settings.changed.connect(update_menu);
            // monitor the .xbel file for changes
            monitor = infofile.monitor (FileMonitorFlags.NONE, null);
            monitor.changed.connect(update_menu);
            button = new Gtk.MenuButton();
            button.set_relief(Gtk.ReliefStyle.NONE);
            var indicatorIcon = new Gtk.Image.from_icon_name(
               "document-open-recent-symbolic", Gtk.IconSize.MENU
            );
            button.set_image(indicatorIcon);
            // fetch initial context
            update_menu();
            initialiseLocaleLanguageSupport();
            /* box */
            indicatorBox = new Gtk.EventBox();
            add(indicatorBox);
            indicatorBox.add(button);
            show_all();
        }

        private Gtk.Menu create_menu() {
            // get relevant lines
            var dis = new DataInputStream (infofile.read ());
            string line;
            var sortlist = new ArrayList<string> ();
            HashMap<string, string> sortdict = new HashMap<string, string>();
            while ((line = dis.read_line (null)) != null) {
                if (line.contains("<bookmark href=\"file://")) {
                    string[] subject = line.split("=\"");
                    string timestamp = subject[3];
                    // trim file path
                    string path = replace(subject[1]);
                    int len = path.char_count();
                    sortdict[timestamp] = path[0:len-7];
                    sortlist.add(timestamp);
                }
            }
            // take care of sorting, slice
            sortlist.sort((a, b) => - a.collate(b));
            int n = 0;
            string[] menu_source = {};
            foreach (string s in sortlist) {
                string menuitem = sortdict[s];
                File checkexists = File.new_for_path(menuitem);
                if (menuitem in menu_source) {
                }
                else {
                    if(checkexists.query_exists() == true) {
                        menu_source += menuitem;
                        n += 1;
                    }
                }
                if (n == n_show) {
                    break;
                }
            }
            // create menu & menuitems
            Gtk.Menu newmenu = new Gtk.Menu();
            foreach (string longname in menu_source) {
                // menu name
                string menuname = getmenuname(longname);
                Gtk.MenuItem newitem = new Gtk.MenuItem.with_label(menuname);
                // command
                string command = "xdg-open " + "'" + longname.replace(
                    "'", "'\\''"
                ) + "'";;
                // tooltip
                string tooltip = (_("Open")) +": " + longname;
                if (showtooltips == true) {
                    newitem.set_tooltip_text(tooltip);
                }
                newmenu.append(newitem);
                // connect AFTER appending to menu please :)
                newitem.activate.connect (() => {
                    try {
                        Process.spawn_command_line_async(command);
                    }
                    catch (GLib.SpawnError err) {
                        /*
                        * in case an error occurs, the file most likely is unavailable
                        * or cannot be opened otherwise. not much use for any action.
                        */
                    }
                });
            }
            return newmenu;
        }

        private string getmenuname (string longname) {
            // read settings, split off filename if set to
            if (hidepath == true) {
                string[] filedata = longname.split("/");
                int last = filedata.length - 1;
                return filedata[last];
            }
            return longname;
        }

        private string replace (string toreplace) {
            // replace special characters
            string output;
            string[,] replacements = {
                {"%23", "#"}, {"%5D", "]"}, {"%5E", "^"}, {"file://", ""},
                {"%20", " "}, {"&apos;", "'"}
            };
            int lenrep = replacements.length[0];
            output = toreplace;
            for (int i=0; i < lenrep; i++) {
                output = toreplace.replace(
                    replacements[i, 0], replacements[i, 1]
                );
                toreplace = output;
            }
            return output;
        }

        private void update_menu() {
            // empty menu, fill with updated content
            recent.destroy();
            showtooltips = rused_settings.get_boolean("showtooltips");
            hidepath = rused_settings.get_boolean("hidepath");
            n_show = rused_settings.get_int("nitems");
            recent = create_menu();
            recent.show_all();
            this.button.set_popup(recent);
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
    objmodule.register_extension_type(
        typeof(Budgie.Plugin),
        typeof(RecentlyUsedApplet.Plugin)
    );
}
