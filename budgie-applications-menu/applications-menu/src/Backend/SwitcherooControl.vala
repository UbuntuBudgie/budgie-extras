/*
 * Copyright 2020 Bastien Nocera
 * Copyright 2020-2021 Justin Haygood
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

[DBus (name = "net.hadess.SwitcherooControl")]
public interface SwitcherooControlDBus : Object {
    [DBus (name = "HasDualGpu")]
    public abstract bool has_dual_gpu { owned get; }

    [DBus (name = "GPUs")]
    public abstract HashTable<string,Variant>[] gpus { owned get; }
}

public class Slingshot.Backend.SwitcherooControl : Object {

    private static SwitcherooControlDBus dbus { private set; private get; }

    static construct {
        try {
            dbus = Bus.get_proxy_sync (BusType.SYSTEM,
                "net.hadess.SwitcherooControl", "/net/hadess/SwitcherooControl");
        } catch (IOError e) {
            critical (e.message);
        }
    }

    public bool has_dual_gpu {
        get {
            return dbus.has_dual_gpu;
        }
    }

    public void apply_gpu_environment (AppLaunchContext context, bool use_default_gpu) {
        if (dbus == null) {
            warning ("Could not apply discrete GPU environment, switcheroo-control not available");
            return;
        }
        if (!has_dual_gpu) {
            return;
        }

        foreach (HashTable<string,Variant> gpu in dbus.gpus) {
            bool is_default = gpu.get ("Default").get_boolean ();

            if (is_default == use_default_gpu) {

                debug ("Using GPU: %s", gpu.get ("Name").get_string ());

                var environment = gpu.get ("Environment");

                var environment_set = environment.get_strv ();

                for (int i = 0; environment_set[i] != null; i = i + 2) {
                    context.setenv (environment_set[i], environment_set[i + 1] );
                }

                return;
            }
        }

        warning ("Could not apply discrete GPU environment, no GPUs in list");
    }

    public string get_gpu_name (bool default_gpu) {
        if (dbus == null) {
            warning ("Could not fetch GPU name, switcheroo-control not available");
            return _("Default");
        }

        foreach (HashTable<string,Variant> gpu in dbus.gpus) {
            bool is_default = gpu.get ("Default").get_boolean ();

            if (is_default == default_gpu) {

                string gpu_name = gpu.get ("Name").get_string ();

                debug ("Using GPU: %s", gpu_name);

                if (gpu_name.contains ("NVIDIA")) {
                    return "NVIDIA";
                }

                if (gpu_name.contains ("Intel")) {
                    return "Intel";
                }

                if (gpu_name.contains ("AMD")) {
                    return "AMD";
                }

                return gpu_name;
            }
        }

        return _("Default");
    }
}
