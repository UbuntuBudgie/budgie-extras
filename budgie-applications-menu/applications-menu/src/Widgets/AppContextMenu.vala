/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2020-2021 Justin Haygood
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class Slingshot.AppContextMenu : Gtk.Menu {
    public signal void app_launched ();

    public string desktop_id { get; construct; }
    public string desktop_path { get; construct; }
    private DesktopAppInfo app_info;

    private bool has_system_item = false;
    //private string appstream_comp_id = "";

    private static GLib.Settings appmenu_settings { get; private set; default = null; }

    private Slingshot.Backend.SwitcherooControl switcheroo_control;
    //private Gtk.MenuItem uninstall_menuitem;
    //private Gtk.MenuItem appcenter_menuitem;

    private Slingshot.Backend.FavoritesManager favorites_manager;

#if HAS_PLANK
    private static Plank.DBusClient plank_client;
    private bool docked = false;
    private string desktop_uri {
        owned get {
            return File.new_for_path (desktop_path).get_uri ();
        }
    }
#endif

    public AppContextMenu (string desktop_id, string desktop_path) {
        Object (
            desktop_id: desktop_id,
            desktop_path: desktop_path
        );
    }

    static construct {
#if HAS_PLANK
        Plank.Paths.initialize ("plank", PKGDATADIR);
        plank_client = Plank.DBusClient.get_instance ();
#endif
        if (appmenu_settings == null) {
            appmenu_settings = new GLib.Settings ("org.ubuntubudgie.plugins.budgie-appmenu");
        }
    }

    construct {
        switcheroo_control = new Slingshot.Backend.SwitcherooControl ();

        app_info = new DesktopAppInfo (desktop_id);

        foreach (unowned string _action in app_info.list_actions ()) {
            string action = _action.dup ();
            var menuitem = new Gtk.MenuItem.with_mnemonic (app_info.get_action_name (action));
            add (menuitem);

            menuitem.activate.connect (() => {
                app_info.launch_action (action, new AppLaunchContext ());
                app_launched ();
            });
        }

        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            bool prefers_non_default_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");

            string gpu_name = switcheroo_control.get_gpu_name (prefers_non_default_gpu);

            // TRANSLATORS: This will display as either 'Open with Intel Graphics' or 'Open with 'NVidia Graphics'
            string label = _("Open with %s Graphics").printf (gpu_name);

            var menu_item = new Gtk.MenuItem.with_mnemonic (label);
            add (menu_item);

            menu_item.activate.connect (() => {
               try {
                   var context = new AppLaunchContext ();
                   switcheroo_control.apply_gpu_environment (context, prefers_non_default_gpu);
                   app_info.launch (null, context);
                   app_launched ();
               } catch (Error e) {
                   warning ("Failed to launch %s: %s", name, e.message);
               }

            });
        }

#if HAS_PLANK
        if (plank_client != null && plank_client.is_connected) {
            if (get_children ().length () > 0) {
                add (new Gtk.SeparatorMenuItem ());
            }

            has_system_item = true;

            var plank_menuitem = new Gtk.MenuItem ();
            plank_menuitem.use_underline = true;

            docked = (desktop_uri in plank_client.get_persistent_applications ());
            if (docked) {
                plank_menuitem.label = _("Remove from _Dock");
            } else {
                plank_menuitem.label = _("Add to _Dock");
            }

            plank_menuitem.activate.connect (plank_menuitem_activate);


            add (plank_menuitem );
        }
#endif
        if (Environment.find_program_in_path ("io.elementary.appcenter") != null) {
            if (!has_system_item && get_children ().length () > 0) {
                add (new Gtk.SeparatorMenuItem ());
            }
        }

        /*var appcenter = Backend.AppCenter.get_default ();
        appcenter.notify["dbus"].connect (() => on_appcenter_dbus_changed.begin (appcenter));
        on_appcenter_dbus_changed.begin (appcenter);
        */

        string captured_desktop_id = desktop_id;

        // Only show favorites option if the feature is enabled
        if (appmenu_settings.get_boolean ("enable-favorites")) {
            favorites_manager = Backend.FavoritesManager.get_default();
            var is_favorite = favorites_manager.is_favorite (desktop_id);
            var favorites_item = new Gtk.MenuItem.with_label (
                is_favorite ? _("Remove from Favorites") : _("Add to Favorites")
            );
            favorites_item.activate.connect (() => {
                // Re-check at execution time
                if (favorites_manager.is_favorite (captured_desktop_id)) {
                    favorites_manager.remove_favorite (captured_desktop_id);
                } else {
                    favorites_manager.add_favorite (captured_desktop_id);
                }
            });
            add (favorites_item);
        }

        show_all ();
    }

    /*private void uninstall_menuitem_activate () {
        var appcenter = Backend.AppCenter.get_default ();
        if (appcenter.dbus == null || appstream_comp_id == "") {
            return;
        }

        app_launched ();

        appcenter.dbus.uninstall.begin (appstream_comp_id, (obj, res) => {
            try {
                appcenter.dbus.uninstall.end (res);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        });
    }*/

    /*private void open_in_appcenter () {
        AppInfo.launch_default_for_uri_async.begin ("appstream://" + appstream_comp_id, null, null, (obj, res) => {
            try {
                AppInfo.launch_default_for_uri_async.end (res);
            } catch (Error error) {
                var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    "Unable to open %s in AppCenter".printf (app_info.get_display_name ()),
                    "",
                    "dialog-error",
                    Gtk.ButtonsType.CLOSE
                );
                message_dialog.show_error_details (error.message);
                message_dialog.run ();
                message_dialog.destroy ();
            } finally {
                app_launched ();
            }
        });
    }*/

    /*private async void on_appcenter_dbus_changed (Backend.AppCenter appcenter) {
        if (appcenter.dbus != null) {
            try {
                appstream_comp_id = yield appcenter.dbus.get_component_from_desktop_id (desktop_id);
            } catch (GLib.Error e) {
                appstream_comp_id = "";
                warning (e.message);
            }
        } else {
            appstream_comp_id = "";
        }
    }*/

#if HAS_PLANK
    private void plank_menuitem_activate () {
        if (plank_client == null || !plank_client.is_connected) {
            return;
        }

        if (docked) {
            plank_client.remove_item (desktop_uri);
        } else {
            plank_client.add_item (desktop_uri);
        }
    }
#endif
}
