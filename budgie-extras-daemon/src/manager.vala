

namespace BudgieExtras
{

/**
 * Main lifecycle management, handle all the various session and GTK+ bits
 */
public class KeybinderManager : GLib.Object
{
    /**
     * Construct a new KeybinderManager and initialiase appropriately
     */
    public KeybinderManager(bool replace)
    {
        // Global key bindings
        Keybinder.init ();
        message("syspath %s", BudgieExtras.SYSCONFDIR);
        message("datapath %s", BudgieExtras.DATADIR);
        message("userpath %s/%s", Environment.get_user_data_dir(), BudgieExtras.DAEMONNAME);
    }

 
} /* End KeybinderManager */

} /* End namespace BudgieExtras */
