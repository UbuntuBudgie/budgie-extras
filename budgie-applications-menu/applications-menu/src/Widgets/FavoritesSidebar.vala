/*
 * Copyright 2026 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

public class Slingshot.Widgets.FavoritesSidebar : Gtk.Box {
    private delegate void Action ();

    public signal void app_launched ();
    // Emitted when a row is right-clicked; carries a ready-built menu widget
    // and the Y centre of the row in sidebar coordinates so the caller can
    // position an overlay at the right height.
    public signal void show_context_menu (Gtk.Widget menu_widget, int y_center);
    public signal void hide_context_menu ();

    private Gtk.ListBox favorites_list;
    private FavoriteRow? open_menu_row = null;
    private Gtk.Button session_button;
    private Gtk.Revealer session_revealer;
    private bool session_expanded = false;
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

        // ── Inline session actions ────────────────────────────────────────
        var session_manager = Backend.SessionManager.get_default ();
        var session_actions_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        session_actions_box.add (make_session_btn ("system-shutdown-symbolic", _("Shut Down"), () => {
            collapse_session (); session_manager.shutdown (); app_launched ();
        }));
        session_actions_box.add (make_session_btn ("system-suspend-symbolic", _("Suspend"), () => {
            collapse_session (); session_manager.suspend (); app_launched ();
        }));
        session_actions_box.add (make_session_btn ("system-restart-symbolic", _("Restart"), () => {
            collapse_session (); session_manager.restart (); app_launched ();
        }));
        session_actions_box.add (make_session_btn ("system-lock-screen-symbolic", _("Lock"), () => {
            collapse_session (); session_manager.lock (); app_launched ();
        }));
        session_actions_box.add (make_session_btn ("system-log-out-symbolic", _("Log Out"), () => {
            collapse_session (); session_manager.logout (); app_launched ();
        }));

        session_revealer = new Gtk.Revealer ();
        session_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        session_revealer.transition_duration = 150;
        session_revealer.add (session_actions_box);
        session_revealer.reveal_child = false;

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

        session_button = new Gtk.Button ();
        session_button.relief = Gtk.ReliefStyle.NONE;
        session_button.halign = Gtk.Align.CENTER;
        session_button.valign = Gtk.Align.CENTER;
        session_button.margin = 6;
        var session_icon = new Gtk.Image.from_icon_name (
            "system-shutdown-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        session_icon.pixel_size = 24;
        session_button.add (session_icon);
        session_button.tooltip_text = _("Power Options");

        pack_start (scrolled, true, true, 0);
        pack_start (separator, false, false, 0);
        pack_start (session_revealer, false, false, 0);
        pack_start (session_button, false, false, 0);

        session_button.clicked.connect (() => {
            open_menu_row = null;
            hide_context_menu ();
            session_expanded = !session_expanded;
            session_revealer.reveal_child = session_expanded;
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

        this.show_all ();
        session_revealer.reveal_child = false;
    }

    private void collapse_session () {
        session_expanded = false;
        session_revealer.reveal_child = false;
    }

    private Gtk.Button make_session_btn (string icon_name, string label,
                                         owned Action action) {
        var btn = new Gtk.Button ();
        btn.relief = Gtk.ReliefStyle.NONE;
        btn.halign = Gtk.Align.CENTER;
        btn.tooltip_text = label;
        var img = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.SMALL_TOOLBAR);
        img.pixel_size = 16;
        btn.add (img);
        btn.clicked.connect (() => { action (); });
        return btn;
    }

    public void set_app_system (Backend.AppSystem system) {
        app_system = system;
        populate_favorites ();
    }

    public void close_context_menu () {
        open_menu_row = null;
        hide_context_menu ();
    }

    public void validate_and_populate () {
        favorites_manager.validate_favorites ();
        populate_favorites ();
    }

    private void populate_favorites () {
        open_menu_row = null;
        hide_context_menu ();
        favorites_list.foreach ((widget) => { widget.destroy (); });

        if (app_system == null) return;

        var favorites = favorites_manager.get_favorites ();
        var dfs = Synapse.DesktopFileService.get_default ();

        foreach (string desktop_id in favorites) {
            var info = dfs.get_desktop_file_for_id (desktop_id);
            if (info != null && !info.is_hidden && info.is_valid) {
                var row = new FavoriteRow (desktop_id, info.filename);
                row.context_menu_requested.connect (() => {
                    emit_context_menu_for_row (row);
                });
                favorites_list.add (row);
            }
        }

        favorites_list.show_all ();
    }

    private void emit_context_menu_for_row (FavoriteRow row) {
        // Toggle: clicking the same row again closes the menu
        if (open_menu_row == row) {
            open_menu_row = null;
            hide_context_menu ();
            return;
        }
        open_menu_row = row;
        hide_context_menu ();
        collapse_session ();

        string desktop_id_captured = row.desktop_id;
        var app_info = row.app_info;

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        // "context-menu" is the standard GTK style class for floating menus;
        // it gives the box a themed background so it doesn't bleed into the
        // content behind the overlay.
        box.get_style_context ().add_class ("context-menu");

        box.add (make_menu_btn (_("Remove from Favorites"), () => {
            hide_context_menu ();
            favorites_manager.remove_favorite (desktop_id_captured);
        }));

        string[] actions = app_info.list_actions ();
        if (actions.length > 0) {
            box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            foreach (unowned string _action in actions) {
                string action = _action.dup ();
                box.add (make_menu_btn (app_info.get_action_name (action), () => {
                    hide_context_menu ();
                    app_info.launch_action (action, new AppLaunchContext ());
                    app_launched ();
                }));
            }
        }

        var switcheroo = new Slingshot.Backend.SwitcherooControl ();
        if (switcheroo != null && switcheroo.has_dual_gpu) {
            bool prefers_non_default = app_info.get_boolean ("PrefersNonDefaultGPU");
            string gpu_name = switcheroo.get_gpu_name (prefers_non_default);
            box.add (make_menu_btn (_("Open with %s Graphics").printf (gpu_name), () => {
                hide_context_menu ();
                try {
                    var ctx = new AppLaunchContext ();
                    switcheroo.apply_gpu_environment (ctx, prefers_non_default);
                    app_info.launch (null, ctx);
                    app_launched ();
                } catch (Error e) {
                    warning ("GPU launch failed: %s", e.message);
                }
            }));
        }

#if HAS_PLANK
        var plank_client = Plank.DBusClient.get_instance ();
        if (plank_client != null && plank_client.is_connected) {
            var desktop_uri = File.new_for_path (row.desktop_path).get_uri ();
            bool docked = (desktop_uri in plank_client.get_persistent_applications ());
            box.add (make_menu_btn (docked ? _("Remove from Dock") : _("Add to Dock"), () => {
                hide_context_menu ();
                if (docked) plank_client.remove_item (desktop_uri);
                else        plank_client.add_item (desktop_uri);
            }));
        }
#endif

        box.show_all ();

        // Calculate the Y centre of this row in sidebar coordinates
        int _rx, ry;
        row.translate_coordinates (this, 0, 0, out _rx, out ry);
        int y_center = ry + row.get_allocated_height () / 2;

        show_context_menu (box, y_center);
    }

    private static Gtk.Button make_menu_btn (string label, owned Action action) {
        var btn = new Gtk.Button.with_label (label);
        btn.relief = Gtk.ReliefStyle.NONE;
        btn.halign = Gtk.Align.FILL;
        unowned Gtk.Label lbl = (Gtk.Label) btn.get_child ();
        lbl.halign = Gtk.Align.START;
        lbl.ellipsize = Pango.EllipsizeMode.END;
        btn.clicked.connect (() => { action (); });
        return btn;
    }

    // ── FavoriteRow ───────────────────────────────────────────────────────
    private class FavoriteRow : Gtk.ListBoxRow {
        public signal void context_menu_requested ();

        public string desktop_id { get; construct; }
        public string desktop_path { get; construct; }
        public GLib.DesktopAppInfo app_info { get; private set; }

        public FavoriteRow (string desktop_id, string desktop_path) {
            Object (desktop_id: desktop_id, desktop_path: desktop_path);
        }

        construct {
            app_info = new GLib.DesktopAppInfo (desktop_id);

            var icon = app_info.get_icon () ?? new ThemedIcon ("application-default-icon");
            var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.INVALID);
            image.pixel_size = 32;
            image.margin = 8;

            var event_box = new Gtk.EventBox ();
            event_box.add (image);
            event_box.add_events (
                Gdk.EventMask.BUTTON_PRESS_MASK |
                Gdk.EventMask.ENTER_NOTIFY_MASK |
                Gdk.EventMask.LEAVE_NOTIFY_MASK
            );
            add (event_box);

            var tooltip_text = app_info.get_display_name ();
            string? desc = app_info.get_description ();
            if (desc != null && desc != "") tooltip_text += "\n" + desc;
            this.tooltip_text = tooltip_text;

            event_box.button_press_event.connect ((ev) => {
                if (ev.button == Gdk.BUTTON_SECONDARY) {
                    context_menu_requested ();
                    return Gdk.EVENT_STOP;
                }
                return Gdk.EVENT_PROPAGATE;
            });

            this.key_press_event.connect ((ev) => {
                if (ev.keyval == Gdk.Key.Menu) {
                    context_menu_requested ();
                    return Gdk.EVENT_STOP;
                }
                return Gdk.EVENT_PROPAGATE;
            });
        }

        public void launch () {
            try {
                var cmd = app_info.get_commandline ();
                string[] parsed_args;
                GLib.Shell.parse_argv (cmd, out parsed_args);

                if (parsed_args.length == 0 || parsed_args[0] != "pkexec") {
                    app_info.launch (null, null);
                    return;
                }

                int i = 1;
                while (i < parsed_args.length && parsed_args[i].has_prefix ("-")) i++;

                var wayland_display = GLib.Environment.get_variable ("WAYLAND_DISPLAY");
                var xdg_runtime_dir  = GLib.Environment.get_variable ("XDG_RUNTIME_DIR");

                string[] argv = { "pkexec" };
                for (int j = 1; j < i; j++) argv += parsed_args[j];
                argv += "env";
                if (wayland_display != null && wayland_display.length > 0)
                    argv += "WAYLAND_DISPLAY=%s".printf (wayland_display);
                if (xdg_runtime_dir != null && xdg_runtime_dir.length > 0)
                    argv += "XDG_RUNTIME_DIR=%s".printf (xdg_runtime_dir);
                for (int j = i; j < parsed_args.length; j++) argv += parsed_args[j];

                Pid child_pid;
                GLib.Process.spawn_async (
                    "/", argv, GLib.Environ.get (),
                    GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out child_pid
                );
                GLib.ChildWatch.add (child_pid, (pid, _) => GLib.Process.close_pid (pid));

            } catch (Error e) {
                warning ("Failed to launch '%s': %s", desktop_id, e.message);
            }
        }
    }
}
