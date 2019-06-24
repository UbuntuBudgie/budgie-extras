

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
    }

 
} /* End KeybinderManager */

} /* End namespace BudgieExtras */
