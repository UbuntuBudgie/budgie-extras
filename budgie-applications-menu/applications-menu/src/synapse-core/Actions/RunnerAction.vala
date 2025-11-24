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
                /*
                appinfo.launch has difficulty running pkexec
                based apps so lets spawn an async process instead
                */
                var commandline =  app.get_commandline();
                string[] spawn_args = {};
                const string checkstr = "pkexec";
                if (commandline.contains(checkstr)) {
                    spawn_args = commandline.split(" ");
                }
                if (spawn_args.length >= 2 && spawn_args[0] == checkstr) {
                    string[] spawn_env = Environ.get();
                    Pid child_pid;
                    Process.spawn_async("/",
                        spawn_args,
                        spawn_env,
                        SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                        null, out child_pid);
                    ChildWatch.add(child_pid, (pid, status) => {
                        Process.close_pid(pid);
                    });
                }
                else {
                    var context = display.get_app_launch_context ();

                    if (app_info != null) {
                        bool use_default_gpu = !app_info.get_boolean ("PrefersNonDefaultGPU");
                        switcheroo_control.apply_gpu_environment (context, use_default_gpu);
                    }

                    app.launch (null, context);

                    RelevancyService.get_default ().application_launched (app);
                }
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
