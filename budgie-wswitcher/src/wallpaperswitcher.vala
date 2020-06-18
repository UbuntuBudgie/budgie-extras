using Gtk;

/*
* WallpaperSwitcher II
* Author: Jacob Vlijm
* Copyright © 2017-2020 Ubuntu Budgie Developers
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

    private Wnck.Screen wnck_scr;
    private GLib.Settings wallsettings;
    private GLib.Settings switchersettings;
    private uint curr_wsindex;
    private string[] curr_wallist;
    private bool runsornot;


    public class WallpaperSwitcherSettings : Gtk.Grid {

        // strings
        const string SETTRUE = (_("Stop"));
        const string SETFALSE = (_("Run"));
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
                update_workspace();
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

    private void update_workspace () {
        // find out what workspace we land on
        unowned GLib.List<Wnck.Workspace> currspaces = wnck_scr.get_workspaces ();
        var curr_ws = wnck_scr.get_active_workspace ();
        curr_wsindex = currspaces.index (curr_ws);
        // and make sure we've got enough image entries
        curr_wallist = switchersettings.get_strv("wallpapers");
        uint n_workspaces = currspaces.length ();
        while (curr_wallist.length < n_workspaces) {
            curr_wallist += "";
        }
        switchersettings.set_strv("wallpapers", curr_wallist);
        // then see if we need to change wallpaper
        string new_wall = curr_wallist[curr_wsindex];
        if (new_wall != "" && runsornot) {
            wallsettings.set_string("picture-uri", new_wall);
        }
    }


    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {

        public Budgie.Applet get_panel_widget(string uuid) {
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
            wnck_scr = Wnck.Screen.get_default ();
            wnck_scr.active_workspace_changed.connect (update_workspace);
            wallsettings = new GLib.Settings (
                "org.gnome.desktop.background"
            );
            wallsettings.changed["picture-uri"].connect(update_wallpaperlist);
            switchersettings = new GLib.Settings (
                "org.ubuntubudgie.plugins.budgie-wswitcher"
            );
            runsornot = switchersettings.get_boolean("runwswitcher");
            switchersettings.changed["runwswitcher"].connect(() => {
                runsornot = switchersettings.get_boolean("runwswitcher");
            });
            initialiseLocaleLanguageSupport();
            update_workspace();
            update_wallpaperlist();
        }

        private void update_wallpaperlist () {
            string new_wall = wallsettings.get_string("picture-uri");
            if (curr_wallist[curr_wsindex] != new_wall) {
                curr_wallist[curr_wsindex] = new_wall;
                switchersettings.set_strv("wallpapers", curr_wallist);
            }
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