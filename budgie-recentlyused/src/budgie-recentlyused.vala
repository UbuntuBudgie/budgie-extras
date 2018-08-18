using Gtk;

/* 
* RecentlyUsed
* Author: Jacob Vlijm
* Copyright © 2017-2018 Ubuntu Budgie Developers
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

    private int n_show;
    private bool showtooltips;
    private bool showicons;
    private GLib.Settings rused_settings;
    private Gtk.RecentChooserMenu recent;


    public class RecentlyUsedSettings : Gtk.Grid {

        public RecentlyUsedSettings(GLib.Settings? settings) {
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
            CheckButton set_tooltips = new Gtk.CheckButton.with_label(
                (_("Show tooltips"))
            );
            set_tooltips.set_active(showtooltips);
            set_tooltips.toggled.connect(update_settootips);
            this.attach(set_tooltips, 0, 3, 2, 1);
            CheckButton set_icons = new Gtk.CheckButton.with_label(
                (_("Show icons"))
            );
            set_icons.set_active(showicons);
            set_icons.toggled.connect(update_showicons);
            this.attach(set_icons, 0, 6, 2, 1);
            this.show_all();
        }

        private void update_settootips(ToggleButton btn) {
            bool newval = btn.get_active();
            rused_settings.set_boolean("showtooltips", newval);
        }

        private void update_showicons(ToggleButton btn) {
            bool newval = btn.get_active();
            rused_settings.set_boolean("showicons", newval);
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
        Gtk.MenuButton button;
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
            rused_settings = new GLib.Settings(
                "org.ubuntubudgie.plugins.budgie-recentlyused"
            );
            rused_settings.changed.connect(update_menu);
            button = new Gtk.MenuButton();
            button.set_relief(Gtk.ReliefStyle.NONE);
            var indicatorIcon = new Gtk.Image.from_icon_name(
               "document-open-recent-symbolic", Gtk.IconSize.MENU
            );
            button.set_image(indicatorIcon);
            update_menu();
            initialiseLocaleLanguageSupport();
            /* box */
            indicatorBox = new Gtk.EventBox();
            add(indicatorBox);
            indicatorBox.add(button);
            show_all();
        }

        private void update_menu() {
            recent.destroy();
            recent = new Gtk.RecentChooserMenu ();
            showtooltips = rused_settings.get_boolean("showtooltips");
            recent.set_show_tips(showtooltips);
            showicons = rused_settings.get_boolean("showicons");
            recent.show_icons = showicons;
            n_show = rused_settings.get_int("nitems");
            recent.limit = n_show;
            recent.item_activated.connect (() => {
                Gtk.RecentInfo info = recent.get_current_item ();
                string foundfile = info.get_uri();
                string command = "xdg-open " + foundfile;
                try {
                    Process.spawn_command_line_async(command);
                }
                catch (GLib.SpawnError err) {
                    /* 
                    * in case an error occurs, the file most likely is
                    * unavailable or cannot be opened.
                    * not much use for any action.
                    */
                }
            });
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
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(RecentlyUsedApplet.Plugin)
    );
}