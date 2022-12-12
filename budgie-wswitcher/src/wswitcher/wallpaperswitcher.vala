using Gtk;

/*
* WallpaperSwitcher II
* Author: Jacob Vlijm
* Copyright © 2017-2022 Ubuntu Budgie Developers
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


namespace WallpaperSwitcherApplet {

    private GLib.Settings switchersettings;

    public class WallpaperSwitcherSettings : Gtk.Grid {

        // strings
        const string SETTRUE = (_("Stop"));
        const string SETFALSE = (_("Start"));
        const string EXPLAIN = (_("Wallpaper Workspace Switcher automatically remembers which wallpaper was set per workspace"));
        const string NOPANELICON = (_("Applet runs without a panel icon"));

        public WallpaperSwitcherSettings() {
            // initial situation
            bool runsornot = switchersettings.get_boolean("runwswitcher");
            string buttonlabel;
            if (runsornot) {buttonlabel = SETTRUE;}
            else {buttonlabel = SETFALSE;}
            var toggle_run_wswitcher = new Gtk.ToggleButton.with_label (
                buttonlabel
            );
            toggle_run_wswitcher.set_active(runsornot);
            toggle_run_wswitcher.toggled.connect (() => {
                string newlabel = "";
                bool newactive = toggle_run_wswitcher.get_active();
                switchersettings.set_boolean("runwswitcher", newactive);
                if (newactive) {
                    newlabel = SETTRUE;
                }
                else {
                    newlabel = SETFALSE;
                }
                toggle_run_wswitcher.set_label (newlabel);
                //  update_workspace();
            });
            toggle_run_wswitcher.set_size_request (90, 10);
            this.attach (toggle_run_wswitcher, 0, 0, 1, 1);
            Gtk.Label explainlabel = new Gtk.Label(EXPLAIN);
            explainlabel.set_xalign(0);
            explainlabel.wrap = true;
            this.attach (new Gtk.Label(""), 0, 1, 2, 1);
            this.attach (explainlabel, 0, 2, 100, 1);
            this.attach (new Gtk.Label(""), 0, 3, 2, 1);
            Gtk.Label nopanelicon = new Gtk.Label(NOPANELICON);
            nopanelicon.set_xalign(0);
            this.attach (nopanelicon, 0, 4, 100, 1);
            this.show_all ();
        }
    }

    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {

        public Budgie.Applet get_panel_widget(string uuid) {
            string cmd = Config.WSWITCHER_DIR + @"/wallpaperswitcher_runner $uuid";
            Idle.add(() => {
                try {
                    Process.spawn_command_line_async(cmd);
                }
                catch (Error e) {

                }
                return false;
            });
            return new Applet();
        }
    }


    public class Applet : Budgie.Applet {

        public string uuid { public set; public get; }

        /* specifically to the settings section */
        public override bool supports_settings() {
            return true;
        }
        public override Gtk.Widget? get_settings_ui() {
            return new WallpaperSwitcherSettings();
        }
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

        public Applet() {
            switchersettings = new GLib.Settings (
                "org.ubuntubudgie.plugins.budgie-wswitcher"
            );
            initialiseLocaleLanguageSupport();
        }
    }
}


[ModuleInit]
public void peas_register_types(TypeModule module){
    /* boilerplate - all modules need this */
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(WallpaperSwitcherApplet.Plugin)
    );
}