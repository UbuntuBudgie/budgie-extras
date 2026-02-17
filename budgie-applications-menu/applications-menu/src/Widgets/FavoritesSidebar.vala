/*
 * Copyright 2026 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

public class Slingshot.Widgets.FavoritesSidebar : Gtk.Box {
    public signal void app_launched ();

    private Gtk.ListBox favorites_list;
    private Gtk.Button session_button;
    private Gtk.Menu? session_menu = null;
    private Backend.FavoritesManager favorites_manager;
    private Backend.AppSystem app_system;

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        width_request = 64;

        favorites_manager = Backend.FavoritesManager.get_default ();

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled.vexpand = true;

        favorites_list = new Gtk.ListBox ();
        favorites_list.selection_mode = Gtk.SelectionMode.NONE;
        favorites_list.get_style_context ().add_class ("favorites-list");

        scrolled.add (favorites_list);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

        // Session button with icon (like Windows Start button power icon)
        session_button = new Gtk.Button ();
        session_button.relief = Gtk.ReliefStyle.NONE;
        session_button.halign = Gtk.Align.CENTER;
        session_button.valign = Gtk.Align.CENTER;
        session_button.margin = 6;

        var session_icon = new Gtk.Image.from_icon_name ("system-shutdown-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        session_icon.pixel_size = 24;
        session_button.add (session_icon);
        session_button.tooltip_text = _("Power Options");

        var session_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        session_box.pack_start (session_button, false, false, 0);

        pack_start (scrolled, true, true, 0);
        pack_start (separator, false, false, 0);
        pack_start (session_box, false, false, 0);

        session_button.clicked.connect (() => {
            show_session_menu ();
        });

        favorites_list.row_activated.connect ((row) => {
            var fav_row = row as FavoriteRow;
            if (fav_row != null) {
                fav_row.launch ();
                app_launched ();
            }
        });

        favorites_manager.favorites_changed.connect (() => {
            populate_favorites ();
        });

        this.show_all();
    }

    public void set_app_system (Backend.AppSystem system) {
        app_system = system;
        populate_favorites ();
    }

    public void validate_and_populate () {
        favorites_manager.validate_favorites ();
        populate_favorites ();
    }

    private void populate_favorites () {
        favorites_list.foreach ((widget) => {
            widget.destroy ();
        });

        if (app_system == null) return;

        var favorites = favorites_manager.get_favorites ();
        var dfs = Synapse.DesktopFileService.get_default ();

        foreach (string desktop_id in favorites) {
            var info = dfs.get_desktop_file_for_id (desktop_id);
            if (info != null && !info.is_hidden && info.is_valid) {
                var row = new FavoriteRow (desktop_id, info.filename);
                row.show_context_menu.connect ((event) => {
                    return create_context_menu (event, row);
                });
                favorites_list.add (row);
            }
        }

        favorites_list.show_all ();
    }

    private void show_session_menu () {
        if (session_menu != null) {
            session_menu.destroy ();
        }

        session_menu = new Gtk.Menu ();
        var session_manager = Backend.SessionManager.get_default ();

        var shutdown_item = new Gtk.MenuItem.with_label (_("Shut Down"));
        shutdown_item.activate.connect (() => {
            session_manager.shutdown ();
            app_launched ();
        });
        session_menu.add (shutdown_item);

        var suspend_item = new Gtk.MenuItem.with_label (_("Suspend"));
        suspend_item.activate.connect (() => {
            session_manager.suspend ();
            app_launched ();
        });
        session_menu.add (suspend_item);

        var restart_item = new Gtk.MenuItem.with_label (_("Restart"));
        restart_item.activate.connect (() => {
            session_manager.restart ();
            app_launched ();
        });
        session_menu.add (restart_item);

        var lock_item = new Gtk.MenuItem.with_label (_("Lock"));
        lock_item.activate.connect (() => {
            session_manager.lock ();
            app_launched ();
        });
        session_menu.add (lock_item);

        var logout_item = new Gtk.MenuItem.with_label (_("Log Out"));
        logout_item.activate.connect (() => {
            session_manager.logout ();
            app_launched ();
        });
        session_menu.add (logout_item);

        session_menu.show_all ();
        session_menu.popup_at_widget (
            session_button,
            Gdk.Gravity.NORTH_EAST,
            Gdk.Gravity.SOUTH_WEST,
            null
        );
    }

    private bool create_context_menu (Gdk.Event event, FavoriteRow? row) {
        if (row == null) return Gdk.EVENT_PROPAGATE;

        // Capture the desktop_id now, not in the callback
        string desktop_id_to_remove = row.desktop_id;

        // Create menu manually to avoid duplicate "Remove from Favorites"
        var menu = new Gtk.Menu ();

        // Add "Remove from Favorites" first
        var remove_item = new Gtk.MenuItem.with_label (_("Remove from Favorites"));
        remove_item.activate.connect (() => {
            favorites_manager.remove_favorite (desktop_id_to_remove);
        });
        menu.add (remove_item);

        // Get app info for additional actions
        var app_info = new DesktopAppInfo (row.desktop_id);

        // Add application-specific actions
        foreach (unowned string _action in app_info.list_actions ()) {
            string action = _action.dup ();
            var menuitem = new Gtk.MenuItem.with_mnemonic (app_info.get_action_name (action));
            menu.add (menuitem);

            menuitem.activate.connect (() => {
                app_info.launch_action (action, new AppLaunchContext ());
                app_launched ();
            });
        }

        // Only add separator if there are app actions
        if (app_info.list_actions ().length > 0) {
            var separator = new Gtk.SeparatorMenuItem ();
            menu.insert (separator, 1);  // Insert after "Remove from Favorites"
        }

        // Add GPU selection if available
        var switcheroo_control = new Slingshot.Backend.SwitcherooControl ();
        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            bool prefers_non_default_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");
            string gpu_name = switcheroo_control.get_gpu_name (prefers_non_default_gpu);
            string label = _("Open with %s Graphics").printf (gpu_name);

            var menu_item = new Gtk.MenuItem.with_mnemonic (label);
            menu.add (menu_item);

            menu_item.activate.connect (() => {
               try {
                   var context = new AppLaunchContext ();
                   switcheroo_control.apply_gpu_environment (context, prefers_non_default_gpu);
                   app_info.launch (null, context);
                   app_launched ();
               } catch (Error e) {
                   warning ("Failed to launch %s: %s", app_info.get_name (), e.message);
               }
            });
        }

#if HAS_PLANK
        // Add Plank dock integration
        var plank_client = Plank.DBusClient.get_instance ();
        if (plank_client != null && plank_client.is_connected) {
            var desktop_uri = File.new_for_path (row.desktop_path).get_uri ();

            var plank_menuitem = new Gtk.MenuItem ();
            plank_menuitem.use_underline = true;

            bool docked = (desktop_uri in plank_client.get_persistent_applications ());
            if (docked) {
                plank_menuitem.label = _("Remove from _Dock");
            } else {
                plank_menuitem.label = _("Add to _Dock");
            }

            plank_menuitem.activate.connect (() => {
                if (docked) {
                    plank_client.remove_item (desktop_uri);
                } else {
                    plank_client.add_item (desktop_uri);
                }
            });

            menu.add (plank_menuitem);
        }
#endif

        menu.show_all ();

        if (event.type == Gdk.EventType.BUTTON_PRESS) {
            menu.popup_at_pointer (event);
            return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private class FavoriteRow : Gtk.ListBoxRow {
        public signal bool show_context_menu (Gdk.Event event);
	public string desktop_id { get; construct; }
        public string desktop_path { get; construct; }
        private GLib.DesktopAppInfo app_info;
        private Gtk.Label? tooltip_label = null;
        private uint timeout_id = 0;

        public FavoriteRow (string desktop_id, string desktop_path) {
            Object (
                desktop_id: desktop_id,
                desktop_path: desktop_path
            );
        }

        construct {
            app_info = new GLib.DesktopAppInfo (desktop_id);

            var icon = app_info.get_icon ();
            if (icon == null) {
                icon = new ThemedIcon ("application-default-icon");
            }

            var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.INVALID);
            image.pixel_size = 32;
            image.margin = 8;

            var event_box = new Gtk.EventBox ();
            event_box.add (image);
            event_box.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);

            add (event_box);

            // Create persistent tooltip label that will be shown/hidden
            tooltip_label = new Gtk.Label (null);
            tooltip_label.set_markup (
                "<b>%s</b>\n<small>%s</small>".printf (
                    Markup.escape_text (app_info.get_display_name ()),
                    Markup.escape_text (app_info.get_description () ?? "")
                )
            );
            tooltip_label.halign = Gtk.Align.START;
            tooltip_label.margin = 8;
            tooltip_label.get_style_context ().add_class ("tooltip");
            tooltip_label.get_style_context ().add_class ("background");

            // Use standard tooltip instead of popover to avoid positioning issues
            var tooltip_text = app_info.get_display_name ();
            if (app_info.get_description () != null && app_info.get_description () != "") {
                tooltip_text += "\n" + app_info.get_description ();
            }
            this.tooltip_text = tooltip_text;

            // Connect context menu directly to this row
            this.button_press_event.connect ((event) => {
                if (event.button == Gdk.BUTTON_SECONDARY) {
                    return show_context_menu (event);
                }
                return Gdk.EVENT_PROPAGATE;
            });

            this.key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Menu) {
                    return show_context_menu (event);
                }
                return Gdk.EVENT_PROPAGATE;
            });
        }

        public void launch () {
            try {
                var cmd  = app_info.get_commandline();

                string[] parsed_args;
                GLib.Shell.parse_argv(cmd, out parsed_args);

                // Non-pkexec path unchanged
                if (parsed_args.length == 0 || parsed_args[0] != "pkexec") {
                    app_info.launch(null, null);
                    return;
                }

                // Scan pkexec options: pkexec [opts...] <command> [args...]
                int i = 1;
                while (i < parsed_args.length && parsed_args[i].has_prefix("-")) {
                    i++;
                }

                // Gather Wayland info from the *user* environment
                var wayland_display = GLib.Environment.get_variable("WAYLAND_DISPLAY"); // e.g. "wayland-0"
                var xdg_runtime_dir = GLib.Environment.get_variable("XDG_RUNTIME_DIR"); // e.g. "/run/user/1000"

                // Build argv directly (no intermediate List<> needed)
                string[] argv = {};
                argv += "pkexec";

                // Append pkexec options (parsed_args[1..i-1])
                for (int j = 1; j < i; j++) {
                    argv += parsed_args[j];
                }

                // Always invoke env under pkexec so we can inject vars
                argv += "env";

                // Only append variables if present
                if (wayland_display != null && wayland_display.length > 0) {
                    argv += "WAYLAND_DISPLAY=%s".printf(wayland_display);
                }
                if (xdg_runtime_dir != null && xdg_runtime_dir.length > 0) {
                    argv += "XDG_RUNTIME_DIR=%s".printf(xdg_runtime_dir);
                }

                // Append original executable + its arguments (parsed_args[i..end])
                for (int j = i; j < parsed_args.length; j++) {
                    argv += parsed_args[j];
                }

                // Spawn async
                string[] envv = GLib.Environ.get();
                Pid child_pid;

                GLib.Process.spawn_async(
                    "/",
                    argv,
                    envv,
                    GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
                    null,
                    out child_pid
                );

                GLib.ChildWatch.add(child_pid, (pid, status) => {
                    GLib.Process.close_pid(pid);
                });

                return;

            } catch (Error e) {
                warning("Failed to launch application '%s': %s", name, e.message);
                return;
            }
        }
    }
}
