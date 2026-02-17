/*
* Copyright (c) 2010 Michal Hruby <michal.mhr@gmail.com>
*               2017 elementary LLC.
*               2020-2021 Justin Haygood
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
* Boston, MA 02110-1301 USA
*
* Authored by: Michal Hruby <michal.mhr@gmail.com>
*/

private class Synapse.RunnerAction: Synapse.BaseAction {

    private Slingshot.Backend.SwitcherooControl switcheroo_control;

    construct {
        switcheroo_control = new Slingshot.Backend.SwitcherooControl ();
    }

    public RunnerAction () {
        Object (title: _("Run"),
                description: _("Run an application, action or script"),
                icon_name: "system-run", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: Match.Score.EXCELLENT);
    }

    public override void do_execute (Match? match, Match? target = null) {
        if (match.match_type == MatchType.APPLICATION) {
            unowned ApplicationMatch? app_match = match as ApplicationMatch;
            return_if_fail (app_match != null);

            DesktopAppInfo app_info = null;
            AppInfo app;

            if (app_match.app_info != null) {
               app = app_match.app_info;
            } else {
                app_info = new DesktopAppInfo.from_filename (app_match.filename);
                app = app_info;
            }

            try {
                weak Gdk.Display display = Gdk.Display.get_default ();
                var cmd  = app.get_commandline();

                string[] parsed_args;
                GLib.Shell.parse_argv(cmd, out parsed_args);

                // Non-pkexec path unchanged
                if (parsed_args.length == 0 || parsed_args[0] != "pkexec") {
                    app.launch(null, null);
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
        
            } catch (Error err) {
                critical (err.message);
            }
        } else { // MatchType.ACTION
            match.execute (null);
        }
    }

    public override bool valid_for_match (Match match) {
        switch (match.match_type) {
            case MatchType.SEARCH:
                return true;
            case MatchType.ACTION:
                return true;
            case MatchType.APPLICATION:
                unowned ApplicationMatch? am = match as ApplicationMatch;
                return am == null || !am.needs_terminal;
            default:
                return false;
        }
    }
}
