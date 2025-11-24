/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *           2013-2014 Akshay Shekher
 *           2011-2012 Giulio Collura
 *           2020-2021 Justin Haygood
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

public class Slingshot.Backend.App : Object {
    public signal void launched (App app);
    //public signal void start_search (Synapse.SearchMatch search_match, Synapse.Match? target); UB apparently unnecessary

    public enum AppType {
        APP,
        COMMAND,
        SYNAPSE
    }

    public string name { get; construct set; }
    public string description { get; private set; default = ""; }
    public string desktop_id { get; construct set; }
    public string exec { get; private set; }
    public string[] keywords { get; private set;}
    public Icon icon { get; private set; default = new ThemedIcon ("application-default-icon"); }
    public double popularity { get; set; }
    public string desktop_path { get; private set; }
    public string categories { get; private set; }
    public string generic_name { get; private set; default = ""; }
    public bool prefers_default_gpu { get; private set; default = false; }
    public AppType app_type { get; private set; default = AppType.APP; }
    public bool terminal { get; private set; default = false; }

#if HAS_PLANK
    private string? unity_sender_name = null;
    public bool count_visible { get; private set; default = false; }
    public int64 current_count { get; private set; default = 0; }
#endif

    public Synapse.Match? match { get; private set; default = null; }
    public Synapse.Match? target { get; private set; default = null; }

    private Slingshot.Backend.SwitcherooControl switcheroo_control;

    construct {
        switcheroo_control = new Slingshot.Backend.SwitcherooControl ();
    }

    public App (GLib.DesktopAppInfo info) {

        app_type = AppType.APP;

        name = info.get_display_name ();
        description = info.get_description () ?? name;
        exec = info.get_commandline ();
        desktop_id = info.get_id ();
        desktop_path = info.get_filename ();
        keywords = info.get_keywords ();
        categories = info.get_categories ();
        generic_name = info.get_generic_name ();
        prefers_default_gpu = !info.get_boolean ("PrefersNonDefaultGPU");
        terminal = info.get_boolean ("Terminal");

        var desktop_icon = info.get_icon ();
        if (desktop_icon != null) {
            icon = desktop_icon;
        }

        weak Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
        if (theme.lookup_by_gicon (icon, 64, Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }
    }

    public App.from_command (string command) {
        app_type = AppType.COMMAND;

        name = command;
        description = _("Run this command…");
        exec = command;
        desktop_id = command;
        icon = new ThemedIcon ("system-run");
    }

    public App.from_synapse_match (Synapse.Match match, Synapse.Match? target = null) {
        app_type = AppType.SYNAPSE;

        name = match.title;
        description = match.description;

        if (match.match_type == Synapse.MatchType.CONTACT && match.has_thumbnail) {
            var file = File.new_for_path (match.thumbnail_path);
            icon = new FileIcon (file);
        } else if (match.icon_name != null) {
            icon = new ThemedIcon (match.icon_name);
        }

        weak Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
        if (theme.lookup_by_gicon (icon, 64, Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }

        if (match is Synapse.ApplicationMatch) {

            var app_match = (Synapse.ApplicationMatch) match;

            var app_info = app_match.app_info;

            this.desktop_id = app_info.get_id ();

            if (app_info is DesktopAppInfo) {
                var desktop_app_info = (DesktopAppInfo) app_info;
                this.desktop_path = desktop_app_info.get_filename ();
                this.prefers_default_gpu = !desktop_app_info.get_boolean ("PrefersNonDefaultGPU");
            }
        }

        this.match = match;
        this.target = target;
    }

    public bool launch () {
        try {
            switch (app_type) {
                case AppType.COMMAND:
                    debug (@"Launching command: $name");
                    Process.spawn_command_line_async (exec);
                    break;
                case AppType.APP:
                    launched (this); // Emit launched signal
                    var info = new DesktopAppInfo (desktop_id);
                    //new DesktopAppInfo (desktop_id).launch (null, null);
                    /*
                    appinfo.launch has difficulty running pkexec
                    based apps so lets spawn an async process instead
                    */
                    var commandline =  info.get_commandline();
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
                        var context = new AppLaunchContext ();
                        switcheroo_control.apply_gpu_environment (context, prefers_default_gpu);

                        new DesktopAppInfo (desktop_id).launch (null, context);

                        debug (@"Launching application: $name");
                    }
                    break;
                case AppType.SYNAPSE:
                    if (match.match_type == Synapse.MatchType.SEARCH) {
                        //start_search (match as Synapse.SearchMatch, target); UB apparently unnecessary
                        return false;
                    } else {
                        if (target == null)
                            Backend.SynapseSearch.find_actions_for_match (match).get (0).execute_with_target (match);
                        else
                            match.execute_with_target (target);
                    }
                    break;
            }
        } catch (Error e) {
            warning ("Failed to launch %s: %s", name, exec);
        }

        return true;
    }

#if HAS_PLANK
    public void perform_unity_update (string sender_name, VariantIter prop_iter) {
        unity_sender_name = sender_name;

        string prop_key;
        Variant prop_value;
        while (prop_iter.next ("{sv}", out prop_key, out prop_value)) {
            if (prop_key == "count") {
                current_count = prop_value.get_int64 ();
            } else if (prop_key == "count-visible") {
                count_visible = prop_value.get_boolean ();
            }
        }
    }

    public void remove_launcher_entry (string sender_name) {
        if (unity_sender_name == sender_name) {
            unity_sender_name = null;
            count_visible = false;
            current_count = 0;
        }
    }
#endif
}
