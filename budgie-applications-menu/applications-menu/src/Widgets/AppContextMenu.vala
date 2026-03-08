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

public class Slingshot.AppContextMenu : Gtk.Popover {
    public signal void app_launched ();

    public string desktop_id { get; construct; }
    public string desktop_path { get; construct; }
    private DesktopAppInfo app_info;

    private static GLib.Settings appmenu_settings { get; private set; default = null; }
    private Slingshot.Backend.SwitcherooControl switcheroo_control;
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

    // Track whether we actually have any items so callers can check
    private bool _has_items = false;
    public bool has_items { get { return _has_items; } }

    public AppContextMenu (string desktop_id, string desktop_path, Gtk.Widget relative_to) {
        Object (
            desktop_id: desktop_id,
            desktop_path: desktop_path,
            relative_to: relative_to,
            position: Gtk.PositionType.BOTTOM
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

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.margin = 4;

        // Application-defined actions (e.g. "New Window", "Incognito Window" …)
        foreach (unowned string _action in app_info.list_actions ()) {
            string action = _action.dup ();
            var btn = make_button (app_info.get_action_name (action));
            btn.clicked.connect (() => {
                popdown ();
                app_info.launch_action (action, new AppLaunchContext ());
                app_launched ();
            });
            box.add (btn);
            _has_items = true;
        }

        // Discrete-GPU option
        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            bool prefers_non_default_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");
            string gpu_name = switcheroo_control.get_gpu_name (prefers_non_default_gpu);
            string label = _("Open with %s Graphics").printf (gpu_name);

            var btn = make_button (label);
            btn.clicked.connect (() => {
                popdown ();
                try {
                    var context = new AppLaunchContext ();
                    switcheroo_control.apply_gpu_environment (context, prefers_non_default_gpu);
                    app_info.launch (null, context);
                    app_launched ();
                } catch (Error e) {
                    warning ("Failed to launch %s: %s", desktop_id, e.message);
                }
            });
            box.add (btn);
            _has_items = true;
        }

#if HAS_PLANK
        if (plank_client != null && plank_client.is_connected) {
            if (_has_items) {
                box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            }

            docked = (desktop_uri in plank_client.get_persistent_applications ());
            string plank_label = docked ? _("Remove from _Dock") : _("Add to _Dock");

            var btn = make_button (plank_label);
            btn.use_underline = true;
            btn.clicked.connect (() => {
                popdown ();
                if (docked) {
                    plank_client.remove_item (desktop_uri);
                } else {
                    plank_client.add_item (desktop_uri);
                }
            });
            box.add (btn);
            _has_items = true;
        }
#endif

        // Favorites
        if (appmenu_settings.get_boolean ("enable-favorites")) {
            favorites_manager = Backend.FavoritesManager.get_default ();
            string captured_desktop_id = desktop_id;

            // Separator before favorites if there are items above
            if (_has_items) {
                box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            }

            bool is_favorite = favorites_manager.is_favorite (captured_desktop_id);
            string fav_label = is_favorite ? _("Remove from Favorites") : _("Add to Favorites");
            var fav_btn = make_button (fav_label);
            fav_btn.clicked.connect (() => {
                popdown ();
                if (favorites_manager.is_favorite (captured_desktop_id)) {
                    favorites_manager.remove_favorite (captured_desktop_id);
                } else {
                    favorites_manager.add_favorite (captured_desktop_id);
                }
            });
            box.add (fav_btn);
            _has_items = true;
        }

        add (box);
        box.show_all ();
    }

    // -----------------------------------------------------------------------
    // Convenience: point at a pixel coordinate inside `relative_to`
    // -----------------------------------------------------------------------
    public void popup_at_pointer_coords (double x, double y) {
        var rect = Gdk.Rectangle ();
        rect.x = (int) x;
        rect.y = (int) y;
        rect.width = 1;
        rect.height = 1;
        set_pointing_to (rect);
        popup ();
    }

    // -----------------------------------------------------------------------
    // Helper
    // -----------------------------------------------------------------------
    private static Gtk.ModelButton make_button (string label) {
        var btn = new Gtk.ModelButton ();
        btn.text = label;
        return btn;
    }
}
