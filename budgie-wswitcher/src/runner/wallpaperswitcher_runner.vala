// valac --pkg gtk+-3.0 --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE"

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


namespace NewWallPaperSwitcher {

    Wnck.Screen wnck_scr;
    GLib.Settings wallsettings;
    GLib.Settings switchersettings;
    int curr_wsindex;
    string[] curr_wallist;
    private bool runsornot;


    private class WatchApplet {

        /*
        with the applet's uuid as argument, this class halts the Gtk mainloop
        if the applet is no longer on the panel
        */

        GLib.Settings? panel_settings;
        GLib.Settings? currpanelsubject_settings;

        string path = "com.solus-project.budgie-panel";
        private bool find_applet (string uuid, string[] applets) {
            for (int i = 0; i < applets.length; i++) {
                if (applets[i] == uuid) {
                    return true;
                }
            }
            return false;
        }

        public WatchApplet (string uuid) {
            string[] applets;
            panel_settings = new GLib.Settings(path);
            string[] allpanels_list = panel_settings.get_strv("panels");
            foreach (string p in allpanels_list) {
                string panelpath = "/com/solus-project/budgie-panel/panels/".concat("{", p, "}/");
                currpanelsubject_settings = new GLib.Settings.with_path(
                    path + ".panel", panelpath
                );
                applets = currpanelsubject_settings.get_strv("applets");
                if (find_applet(uuid, applets)) {
                    currpanelsubject_settings.changed["applets"].connect(() => {
                        applets = currpanelsubject_settings.get_strv("applets");
                        if (!find_applet(uuid, applets)) {
                            Gtk.main_quit();
                        }
                    });
                    break;
                }
            }
        }
    }

    public static void main (string[] args) {
        Gtk.init (ref args);
        wnck_scr = Wnck.Screen.get_default ();
        wnck_scr.force_update();
        wnck_scr.active_workspace_changed.connect (update_workspace);
        wnck_scr.workspace_created.connect (update_workspace);
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
        new WatchApplet (args[1]);
        update_workspace();
        update_wallpaperlist();
        Gtk.main ();
    }

    private void update_wallpaperlist () {
        string new_wall = wallsettings.get_string("picture-uri");
        if (curr_wallist[curr_wsindex] != new_wall) {
            curr_wallist[curr_wsindex] = new_wall;
            switchersettings.set_strv("wallpapers", curr_wallist);
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
}