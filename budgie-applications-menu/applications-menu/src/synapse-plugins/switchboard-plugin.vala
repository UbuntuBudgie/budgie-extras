/*
* Copyright 2020 elementary, Inc.
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
*/
[CCode (cname = "PLUGINSDIR")]
private extern const string PLUGINSDIR;

public struct Synapse.PlugInfo {
    public string title;
    public string icon;
    public string uri;
    public string[] path;
}

[DBus (name = "io.elementary.ApplicationsMenu.Switchboard")]
public class Synapse.SwitchboardExecutablePlugin : Object {
    private Synapse.PlugInfo[] plugs;

    public void set_plugs (Synapse.PlugInfo[] plugs) throws GLib.Error {
        this.plugs = plugs;
    }

    [DBus (visible = false)]
    public Synapse.PlugInfo[] get_plugs () {
        return plugs;
    }
}

public class Synapse.SwitchboardObject: Synapse.Match {
    public string uri { get; construct set; }

    public SwitchboardObject (Synapse.PlugInfo plug_info) {
        Object (
            title: plug_info.title,
            description: _("Open %s settings").printf (plug_info.title),
            icon_name: plug_info.icon,
            match_type: MatchType.APPLICATION,
            uri: plug_info.uri
        );
    }

    public override void execute (Match? match) {
        try {
            AppInfo.launch_default_for_uri ("settings://%s".printf (uri), null);
        } catch (Error e) {
            warning ("Failed to show URI for %s: %s\n".printf (uri, e.message));
        }
    }
}

public class Synapse.SwitchboardPlugin : Object, Activatable, ItemProvider {
    static void register_plugin () {
        DataSink.PluginRegistry.get_default ().register_plugin (
            typeof (SwitchboardPlugin),
            "Switchboard Search",
            _("Find switchboard plugs and open them."),
            "preferences-desktop",
            register_plugin
        );
    }

    static construct {
        register_plugin ();
    }

    Synapse.WorkerLink worker_link;
    GLib.Subprocess subprocess;
    Synapse.SwitchboardExecutablePlugin executable_plugin;

    construct {
        executable_plugin = new Synapse.SwitchboardExecutablePlugin ();
        worker_link = new Synapse.WorkerLink ();
        worker_link.on_connection_accepted.connect ((connection) => {
            try {
                connection.register_object ("/io/elementary/applicationsmenu", executable_plugin);
            } catch (Error e) {
                critical ("%s", e.message);
            }
        });

        worker_link.start ();

        var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.NONE);
        string[] argv = {
            GLib.Path.build_filename (PLUGINSDIR, "switchboard-plugin"),
            "--dbus-address=%s".printf (worker_link.address)
        };
        try {
            subprocess = launcher.spawnv (argv);
            subprocess.wait_check_async.begin (null, (obj, res) => {
                try {
                    subprocess.wait_check_async.end (res);
                } catch (GLib.Error e) {
                    critical ("%s", e.message);
                }

                subprocess = null;
            });
        } catch (Error e) {
            warning ("Failed to spawn %s", e.message);
        }

    }

    ~SwitchboardPlugin () {
        if (subprocess != null) {
            subprocess.force_exit ();
        }
    }

    public bool enabled { get; set; default = true; }

    public void activate () { }

    public void deactivate () { }

    public async ResultSet? search (Query q) throws SearchError {
        var plugs = executable_plugin.get_plugs ();

        var result = new ResultSet ();
        MatcherFlags flags;
        if (q.query_string.length == 1) {
            flags = MatcherFlags.NO_SUBSTRING | MatcherFlags.NO_PARTIAL | MatcherFlags.NO_FUZZY;
        } else {
            flags = 0;
        }
        var matchers = Query.get_matchers_for_query (q.query_string_folded, flags);

        string stripped = q.query_string.strip ();
        if (stripped == "") {
            return null;
        }

        foreach (unowned Synapse.PlugInfo plug in plugs) {
            // Retrieve the string that this plug/setting can be searched by
            string searchable_name = plug.path.length > 0 ? plug.path[plug.path.length - 1] : plug.title;

            foreach (var matcher in matchers) {
                MatchInfo info;
                if (matcher.key.match (searchable_name.down (), 0, out info)) {
                    result.add (new SwitchboardObject (plug), Match.Score.AVERAGE + Match.Score.INCREMENT_MEDIUM);
                    break;
                }

                if (matcher.key.match (plug.title.down (), 0, out info)) {
                    result.add (new SwitchboardObject (plug), Match.Score.AVERAGE + Match.Score.INCREMENT_MEDIUM);
                    break;
                }
            }
        }
        q.check_cancellable ();

        return result;
    }
}
