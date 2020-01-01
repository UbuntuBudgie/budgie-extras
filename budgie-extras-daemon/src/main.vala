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


/**
 * Whether we need to replace an existing daemon
 */
static bool replace = false;

const GLib.OptionEntry[] options = {
    { "replace", 0, 0, OptionArg.NONE, ref replace, "Replace currently running daemon" },
    { null }
};

namespace BudgieExtras {

    bool setup = false;
    bool spammed = false;

    void DaemonNameLost(DBusConnection conn, string name)
    {
        warning("budgie-extras-daemon lost d-bus name %s", name);
        if (!spammed) {
            if (setup) {
                message("Replaced existing budgie-extras-daemon");
            } else {
                message("Another instance of budgie-extras-daemon is running. Use --replace");
            }
            spammed = true;
        }
        Gtk.main_quit();
    }
}

/**
 * Main entry for the daemon
 */
public static int main(string[] args) {
    Gtk.init(ref args);
    OptionContext ctx;

    BudgieExtras.KeybinderManager? manager = null;

    ctx = new OptionContext("- Budgie Extras Daemon");
    ctx.set_help_enabled(true);
    ctx.add_main_entries(options, null);
    ctx.add_group(Gtk.get_option_group(false));

    try {
        ctx.parse(ref args);
    } catch (Error e) {
        message("Error: %s\n", e.message);
        return 0;
    }

    manager = new BudgieExtras.KeybinderManager(replace);

    /* Enter main loop */
    Gtk.main();

    /* Deref - clean */
    manager = null;

    return 0;
}
