/**
 * Whether we need to replace an existing daemon
 */
static bool replace = false;

const GLib.OptionEntry[] options = {
    { "replace", 0, 0, OptionArg.NONE, ref replace, "Replace currently running daemon" },
    { null }
};

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
        stderr.printf("Error: %s\n", e.message);
        return 0;
    }

    manager = new BudgieExtras.KeybinderManager(replace);

    /* Enter main loop */
    Gtk.main();

    /* Deref - clean */
    manager = null;

    return 0;
}
