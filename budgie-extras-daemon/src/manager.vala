

namespace BudgieExtras
{

public class BDEFile
{
    private bool valid_file = false;
    private KeyFile keyfile = null;

    private string key_shortcut = null;
    private string settings_path = null;
    private string settings_key = null;
    private string command_action = null;

    /**
    * location: full path to file with .bde extension
    */
    public BDEFile(string location)
    {
        keyfile = new KeyFile();
        try {
            keyfile.load_from_file(location, KeyFileFlags.NONE);

            string group = "Daemon";

            if (!keyfile.has_group(group)) return;

            bool todo = false;
            if (!keyfile.has_key(group, "shortcut")) return;

            key_shortcut = keyfile.get_string(group, "shortcut");

            if (key_shortcut == null || key_shortcut == "") return;

            if (keyfile.has_key(group, "path") &&
                keyfile.has_key(group, "key-name"))
            {
                settings_path = keyfile.get_string(group, "path");
                settings_key = keyfile.get_string(group, "key-name");

                if (settings_path == null ||
                    settings_key == null ||
                    settings_path == "" ||
                    settings_key == "") return;

                todo = true;
            }

            if (keyfile.has_key(group, "command")) {
                command_action =  keyfile.get_string(group, "command");

                if (command_action == null || command_action == "") return;

                todo = true;
            }

            if (!todo) return;

        }
        catch (GLib.Error e)
        {
            message("BDE File: %s", e.message);
            return;
        }

        //  got this file so the bde file must be valid
        valid_file = true;
    }

    public bool is_valid()
    {
        return valid_file;
    }

    public string get_shortcut()
    {
        if (valid_file) return key_shortcut;

        return "";
    }

    public void callback (string keystring)
    {

    }
    public bool connect()
    {
        if (!valid_file) return false;

        return Keybinder.bind_full(key_shortcut, this.callback);
    }
}

/**
 * Main lifecycle management, handle all the various session and GTK+ bits
 */
public class KeybinderManager : GLib.Object
{
    private HashTable<string, BDEFile> shortcuts = null;
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

        shortcuts = new HashTable<string, BDEFile>(str_hash, str_equal);

        string datapath = BudgieExtras.DATADIR;
        string syspath = BudgieExtras.SYSCONFDIR;
        string localpath = Environment.get_user_data_dir() + "/" + BudgieExtras.DAEMONNAME;

        string paths[] = {datapath, syspath, localpath};

        foreach (var path in paths)
        {
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
                continue;
            }

            FileInfo info = null;

            try {
                while (enumerator != null && ((info = enumerator.next_file (null)) != null)) {
                    if (info.get_file_type () == FileType.REGULAR) {
                        message ("%s\n", info.get_name ());

                        BDEFile bfile = new BDEFile(path + "/" + info.get_name());

                        if (bfile.is_valid())
                        {
                            shortcuts[bfile.get_shortcut()] = bfile;
                        }
                    }
                }
            }
            catch (GLib.Error e) {
                message("enumerator next file %s", e.message);
            }
        }

        HashTableIter<string, BDEFile> iter = HashTableIter<string, BDEFile> (shortcuts);
        string shortcut;
        BDEFile bdefile;
        while (iter.next(out shortcut, out bdefile))
        {
            bdefile.connect();
        }
    }


} /* End KeybinderManager */

} /* End namespace BudgieExtras */
