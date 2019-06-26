

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

        string path = BudgieExtras.DATADIR;
        path += "/bde";

        File file = File.new_for_path(path);

        FileEnumerator enumerator = null;
        try {
            enumerator = file.enumerate_children (
            "standard::*.bde",
            FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
            null
            );
        }
        catch (GLib.Error e) {
            message("Cannot enumerate %s", e.message);
        }

        FileInfo info = null;

        try {
            while (enumerator != null && ((info = enumerator.next_file (null)) != null)) {
                if (info.get_file_type () == FileType.REGULAR) {
                    print ("%s\n", info.get_name ());

                    KeyFile keyfile = new KeyFile();
                    message("full file %s", path + "/" + info.get_name());
                    keyfile.load_from_file(path + "/" + info.get_name(), KeyFileFlags.NONE);

                    string group = "Daemon";

                    if (keyfile.has_group(group) && keyfile.has_key(group, "path")) {
                        message("path %s", keyfile.get_string(group, "path"));
                    }

                }
            }
        }
        catch (GLib.Error e) {
            message("enumerator next file %s", e.message);
        }

    }


} /* End KeybinderManager */

} /* End namespace BudgieExtras */
