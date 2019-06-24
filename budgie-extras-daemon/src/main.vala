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

    BudgieExtras.ServiceManager? manager = null;

    ctx = new OptionContext("- Budgie Extras Daemon");
    ctx.set_help_enabled(true);
    ctx.add_main_entries(options, null);
    ctx.add_group(Gtk.get_option_group(false));

    try {
        ctx.parse(ref args);
    } catch (Error e) {
        stderr.printf("Error: %s\n", e.message);
        return 0;
    }

    manager = new BudgieExtras.ServiceManager(replace);
    // Global key bindings
    Keybinder.init ();

    /* Enter main loop */
    Gtk.main();

    /* Deref - clean */
    manager = null;

    return 0;
}
