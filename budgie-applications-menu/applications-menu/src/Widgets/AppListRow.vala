/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 */

public class AppListRow : Gtk.ListBoxRow {
    public string app_id { get; construct; }
    public string desktop_path { get; construct; }
    public GLib.DesktopAppInfo app_info { get; private set; }

    public AppListRow (string app_id, string desktop_path) {
        Object (
            app_id: app_id,
            desktop_path: desktop_path
        );
    }

    construct {
        app_info = new GLib.DesktopAppInfo (app_id);

        var icon = app_info.get_icon ();
        weak Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
        if (icon == null || theme.lookup_by_gicon (icon, 32, Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }

        var image = new Gtk.Image ();
        image.gicon = icon;
        image.pixel_size = 32;

        var name_label = new Gtk.Label (app_info.get_display_name ());
        name_label.set_ellipsize (Pango.EllipsizeMode.END);
        name_label.xalign = 0;

        tooltip_text = app_info.get_description ();

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.add (image);
        grid.add (name_label);
        grid.margin = 6;
        grid.margin_start = 18;

        add (grid);
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
