/*
* BudgieExtrasDaemon
* Author: David Mohammed
* Copyright © 2019 Ubuntu Budgie Developers
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

public class BDEFile
{
    private bool valid_file = false;
    private KeyFile keyfile = null;

    private string key_shortcut = null;
    private string settings_path = null;
    private string settings_key = null;
    private string command_action = null;
    private string activate_path = null;
    private string activate_key = null;
    private string overlay_path = null;
    private string overlay_key = null;
    private string name = "";

    bool parse_gsettings(string group,
                         string name, ref string? key_path, ref string? key_name){
        debug("checking name %s", name);
        bool return_val = true;

        try {
            if (keyfile.has_key(group, name))
            {
                var toggle = keyfile.get_string(group, name);
                toggle = toggle.down().strip();
                string[] split_path = null;
                if (toggle.contains("gsettings ")) {
                    split_path = toggle.split(" ");
                    if (split_path.length != 3)
                    {
                        return_val = false;
                    }
                }

                if (split_path != null && split_path.length == 3)
                {
                    key_path = split_path[1];
                    key_name = split_path[2];
                }

                if (key_path == null ||
                    key_name == null ||
                    key_path == "" ||
                    key_name == "")
                {
                    key_name=null;
                    key_path=null;

                    return_val = false;
                    debug("invalid gsettings value");
                }
                debug("found key_name %s, key_path %s", key_name, key_path);
            }
        }
        catch (KeyFileError e)
        {
            message("key error %s: %s", name, e.message);
        }
        return return_val;
    }

    /**
    * location: full path to file with .bde extension
    */
    public BDEFile(string location)
    {
        keyfile = new KeyFile();
        try {
            keyfile.load_from_file(location, KeyFileFlags.NONE);

            string group = "Daemon";
            debug("before has_group");
            if (!keyfile.has_group(group)) return;

            bool todo = false;
            debug("before shortcut");
            if (!keyfile.has_key(group, "shortcut")) return;

            key_shortcut = keyfile.get_string(group, "shortcut");
            debug("key shortcut %s", key_shortcut);
            if (key_shortcut == null || key_shortcut == "") return;

            if (parse_gsettings(group, "toggle", ref settings_path, ref settings_key))
            {
                todo = true;
                debug("todo %s %s", settings_path, settings_key);
            }

            parse_gsettings(group, "onlyactivate", ref activate_path, ref activate_key);
            parse_gsettings(group, "overlay", ref overlay_path, ref overlay_key);

            if (keyfile.has_key(group, "command")) {
                command_action =  keyfile.get_string(group, "command");

                if (command_action == null || command_action == "") return;

                todo = true;
            }

            if (keyfile.has_key(group, "name")) {
                name = keyfile.get_string(group, "name");
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

    public string get_name()
    {
        return name.down().strip();
    }

    public void callback (string keystring)
    {
        debug("callback %s", keystring);
        if (this.command_action != null && this.command_action != "")
        {
            debug("command_action");
            try
            {
                Process.spawn_command_line_async(this.command_action);
            }
            catch (GLib.SpawnError e)
            {
                message("Failed to spawn %s", this.command_action);
            }

        }

        if (this.settings_path != null && this.settings_path != "")
        {
            debug("toggle");
            Settings settings = new Settings(settings_path);
            bool val = settings.get_boolean(settings_key);
            settings.set_boolean(settings_key, !val);
        }
    }

    public void reset_overlay() {
        if (overlay_path != null)
        {
            Settings settings = new Settings(overlay_path);
            /*
              only need to reset if the overlay contains an empty string
            */
            var keyval = settings.get_strv(overlay_key); 
            if (keyval.length == 1 && keyval[0] == "") {
                settings.reset(overlay_key);
            }
        }
    }

    public bool connect()
    {
        debug("1");
        if (!valid_file) return false;
        debug("2");
        debug("bind %s", key_shortcut);

        bool bind_key = false;
        bool return_val = false;

        Keybinder.unbind_all(key_shortcut);

        if (activate_path != null)
        {
            Settings settings = new Settings(activate_path);
            bind_key = settings.get_boolean(activate_key);

            if (overlay_path != null && !bind_key)
            {
                reset_overlay();
            }

            if (overlay_path != null && bind_key)
            {
                settings = new Settings(overlay_path);
                // we expect either an array or a string for the overlay key
                var val = settings.get_value(overlay_key);
                if (val.get_type_string() == "as") {
                    settings.set_strv(overlay_key, {""});
                }
                else
                {
                    settings.set_string(overlay_key, "");
                }
            }
        }
        else bind_key = true;

        if (bind_key)
        {
            debug("3 %s", key_shortcut);
            return_val = Keybinder.bind_full(key_shortcut, this.callback);
        }
        return return_val;
    }
}

/**
 * Main lifecycle management, handle all the various session and GTK+ bits
 */
public class KeybinderManager : GLib.Object
{
    private HashTable<string, BDEFile> shortcuts = null;
    BudgieExtras.DbusManager? dbus;

    /**
     * Get the shortcut string for a bde file with the key_name
     */
    public bool get_shortcut(string key_name, out string shortcut)
    {
        shortcut = "";
        if (key_name == null || key_name == "") {
            return false;
        }
        HashTableIter<string, BDEFile> iter = HashTableIter<string, BDEFile> (shortcuts);
        BDEFile bdefile;
        string compare = key_name.down().strip();

        while (iter.next(out shortcut, out bdefile))
        {
            string found = bdefile.get_name();

            if (found != "" && found == compare)
            {
                shortcut = bdefile.get_shortcut();
                return true;
            }
        }

        return false;
    }

    /**
     * Construct a new KeybinderManager and initialiase appropriately
     */
    public KeybinderManager(bool replace)
    {
        dbus = new BudgieExtras.DbusManager(this);
        dbus.setup_dbus(replace);

        // Global key bindings
        Keybinder.init ();
        Keybinder.set_use_cooked_accelerators(false);
        debug("syspath %s", BudgieExtras.SYSCONFDIR);
        debug("datapath %s", BudgieExtras.DATADIR);
        debug("userpath %s/%s", Environment.get_user_data_dir(), BudgieExtras.DAEMONNAME);
        reload();
    }

    /**
     * Reload keyboard shortcuts
     */
    public bool reload()
    {
        string datapath = BudgieExtras.DATADIR;
        string syspath = BudgieExtras.SYSCONFDIR;
        string localpath = Environment.get_user_data_dir() + "/" + BudgieExtras.DAEMONNAME;
        string paths[] = {datapath, syspath, localpath};
        string shortcut;
        BDEFile bdefile;

        if (shortcuts == null) {
            shortcuts = new HashTable<string, BDEFile>(str_hash, str_equal);
        }

        if (shortcuts.size() != 0) {
            HashTableIter<string, BDEFile> iter = HashTableIter<string, BDEFile> (shortcuts);
            while (iter.next(out shortcut, out bdefile))
            {
                bdefile.reset_overlay();
                Keybinder.unbind_all(shortcut);
            }

            shortcuts.remove_all();
        }

        foreach (var path in paths)
        {
            File file = File.new_for_path(path);

            if (!file.query_exists()) continue;
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
                        debug ("%s\n", info.get_name ());

                        BDEFile bfile = new BDEFile(path + "/" + info.get_name());

                        if (bfile.is_valid())
                        {
                            debug("valid %s", bfile.get_shortcut());
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
        while (iter.next(out shortcut, out bdefile))
        {
            bdefile.connect();
        }
        return true;
    }


} /* End KeybinderManager */

} /* End namespace BudgieExtras */
