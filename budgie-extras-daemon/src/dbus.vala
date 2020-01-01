/*
* BudgieExtrasDaemon
* Author: David Mohammed
* Copyright © 2020 Ubuntu Budgie Developers
* Website=https://ubuntubudgie.org
* This program is free software: you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the Free
* Software Foundation, either version 3 of the License, or any later version.
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
* more details. You should have received a copy of the GNU General Public
* License along with this program.  If not, see
* <https://www.gnu.org/licenses/>.
*/

namespace BudgieExtras
{

/**
 * Our name on the session bus. Reserved for BudgieExtras use
 */
public const string EXTRAS_DBUS_NAME        = "org.UbuntuBudgie.ExtrasDaemon";

/**
 * Unique object path on DBUS_NAME
 */
public const string EXTRAS_DBUS_OBJECT_PATH = "/org/ubuntubudgie/extrasdaemon";


/**
 * DbusManager is responsible for managing interaction of budgie extras
 * applets/apps over dbus
 */
[DBus (name = "org.UbuntuBudgie.ExtrasDaemon")]
public class DbusManager : Object
{
    KeybinderManager keybinder;

    [DBus (visible = false)]
    public DbusManager(KeybinderManager km)
    {
        keybinder = km;
    }

    /**
     * Own the DBUS_NAME
     */
    [DBus (visible = false)]
    public void setup_dbus(bool replace)
    {
        var flags = BusNameOwnerFlags.ALLOW_REPLACEMENT;
        if (replace) {
            flags |= BusNameOwnerFlags.REPLACE;
        }
        Bus.own_name(BusType.SESSION, BudgieExtras.EXTRAS_DBUS_NAME, flags,
            on_bus_acquired, ()=> {}, BudgieExtras.DaemonNameLost);
    }

    /**
     * Find the shortcut key string for the bde file name key
     */
    public string GetShortcut(string key_name) {
        string shortcut = "";

        var ret = keybinder.get_shortcut(key_name, out shortcut);

        if (ret)
        {
            debug("output %s", shortcut);
            return shortcut;
        }

        debug("nothing to return");
        return "";

    }
    /**
     * Acquired EXTRAS_DBUS_NAME, register ourselves on the bus
     */
    private void on_bus_acquired(DBusConnection conn)
    {
        try {
            conn.register_object(BudgieExtras.EXTRAS_DBUS_OBJECT_PATH, this);
        } catch (Error e) {
            stderr.printf("Error registering Extras DbusManager: %s\n", e.message);
        }
        BudgieExtras.setup = true;
    }

} /* End class DbusManager */

} /* End namespace BudgieExtras */
