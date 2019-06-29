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
public class DbusManager
{
    [DBus (visible = false)]
    public DbusManager()
    {

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
