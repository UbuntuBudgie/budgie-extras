/*
* Copyright (c) 2017 elementary LLC (https://elementary.io)
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

[DBus (name = "io.elementary.appcenter")]
public interface AppCenterDBus : Object {
    public abstract async void install (string component_id) throws GLib.Error;
    public abstract async void update (string component_id) throws GLib.Error;
    public abstract async void uninstall (string component_id) throws GLib.Error;
    public abstract async string get_component_from_desktop_id (string desktop_id) throws GLib.Error;
    public abstract async string[] search_components (string query) throws GLib.Error;
}

public class Slingshot.Backend.AppCenter : Object {
    private const string DBUS_NAME = "io.elementary.appcenter";
    private const string DBUS_PATH = "/io/elementary/appcenter";
    private const uint RECONNECT_TIMEOUT = 5000U;

    private static AppCenter? instance;
    public static unowned AppCenter get_default () {
        if (instance == null) {
            instance = new AppCenter ();
        }

        return instance;
    }

    public AppCenterDBus? dbus { public get; private set; default = null; }

    construct {
        Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.AUTO_START,
                        () => try_connect (), name_vanished_callback);
    }

    private AppCenter () {

    }

    private void try_connect () {
        Bus.get_proxy.begin<AppCenterDBus> (BusType.SESSION, DBUS_NAME, DBUS_PATH, 0, null, (obj, res) => {
            try {
                dbus = Bus.get_proxy.end (res);
            } catch (Error e) {
                warning (e.message);
                Timeout.add (RECONNECT_TIMEOUT, () => {
                    try_connect ();
                    return false;
                });
            }
        });
    }

    private void name_vanished_callback (DBusConnection connection, string name) {
        dbus = null;
    }
}
