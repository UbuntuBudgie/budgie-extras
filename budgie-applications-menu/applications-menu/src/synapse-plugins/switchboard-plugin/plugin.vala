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

private static string? dbus_address = null;
private const GLib.OptionEntry[] OPTIONS = {
    { "dbus-address", 0, 0, OptionArg.STRING, ref dbus_address, "D-Bus server address", "ADDRESS" },
    { null }
};

public struct PlugInfo {
    public string title;
    public string icon;
    public string uri;
    public string[] path;
}

public class SwitchboardPlugin : GLib.Object {
    private GLib.DBusConnection connection;
    private SourceFunc callback;
    const string DBUS_INTERFACE = "io.elementary.ApplicationsMenu.Switchboard";
    const string DBUS_PATH = "/io/elementary/applicationsmenu";

    construct {
        var loop = new GLib.MainLoop (null, true);
        run_dbus.begin ((obj, res) => {
            run_dbus.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private async void run_dbus () {
        callback = run_dbus.callback;
        debug ("Connecting to %s", dbus_address);

        try {
            connection = yield new DBusConnection.for_address (
                dbus_address,
                GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT | GLib.DBusConnectionFlags.DELAY_MESSAGE_PROCESSING
            );
            connection.start_message_processing ();
        } catch (Error e) {
            error ("D-Bus failure: %s", e.message);
        }
        yield load_plugs ();
        yield;
    }

    private async void load_plugs () {
        var plugs_manager = Switchboard.PlugsManager.get_default ();
        Variant[] children = {};
        foreach (var plug in plugs_manager.get_plugs ()) {
            var settings = plug.supported_settings;
            if (settings == null || settings.size <= 0) {
                continue;
            }

            string uri = settings.keys.to_array ()[0];
            var plug_info = PlugInfo () {
                title = plug.display_name,
                icon = plug.icon,
                uri = uri,
                path = {}
            };
            children += plug_info;

            // Using search to get sub settings
            var search_results = yield plug.search ("");
            foreach (var result in search_results.entries) {
                unowned string title = result.key;
                var view = result.value;

                // get uri from plug's supported_settings
                // Use main plug uri as fallback
                string sub_uri = uri;
                if (view != "") {
                    foreach (var setting in settings.entries) {
                        if (setting.value == view) {
                            sub_uri = setting.key;
                            break;
                        }
                    }
                }

                string[] path = title.split (" → ");

                plug_info = PlugInfo () {
                    title = title,
                    icon = plug.icon,
                    uri = (owned) sub_uri,
                    path = (owned) path
                };
                children += plug_info;
            }
        }

        var parameters = new Variant.tuple ({new Variant.array (new GLib.VariantType ("(sssas)"), children)});
        try {
            yield connection.call (null, DBUS_PATH, DBUS_INTERFACE, "SetPlugs", parameters, null, GLib.DBusCallFlags.NO_AUTO_START, -1);
        } catch (GLib.Error e) {
            critical (e.message);
        }

        if (callback != null) {
            Idle.add ((owned)callback);
        }
    }
}

public static int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.textdomain (GETTEXT_PACKAGE);
    Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
    Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

    try {
        var opt_context = new GLib.OptionContext ("Plugin options");
        opt_context.set_help_enabled (true);
        opt_context.add_main_entries (OPTIONS, null);
        opt_context.parse (ref args);
    } catch (GLib.OptionError e) {
        printerr ("error: %s\n", e.message);
        printerr ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
        return 1;
    }

    if (dbus_address == null) {
        printerr ("The --dbus-address argument is mandatory\n");
        return 1;
    }

    new SwitchboardPlugin ();
    return 0;
}
