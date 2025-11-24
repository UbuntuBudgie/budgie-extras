/*
* Copyright (c) 2010 Michal Hruby <michal.mhr@gmail.com>
*               2017-2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Michal Hruby <michal.mhr@gmail.com>
*/

namespace Synapse {
    errordomain DesktopFileError {
        UNINTERESTING_ENTRY
    }

    public class DesktopFileInfo: Object {
        // registered environments from http://standards.freedesktop.org/menu-spec/latest
        [Flags]
        public enum EnvironmentType {
            GNOME,
            KDE,
            LXDE,
            LXQT,
            MATE,
            RAZOR,
            ROX,
            TDE,
            UNITY,
            XFCE,
            PANTHEON,
            OLD,

            // Keep up to date with list above
            ALL = GNOME | KDE | LXDE | LXQT | MATE | RAZOR | ROX | TDE | UNITY | XFCE | PANTHEON | OLD
        }

        public string desktop_id { get; construct set; }
        public string name { get; construct set; }
        public string generic_name { get; construct set; }
        public string comment { get; set; default = ""; }
        public string icon_name { get; construct set; default = ""; }
        public string gettext_domain { get; construct set; }

        public bool needs_terminal { get; set; default = false; }
        public string filename { get; construct set; }

        public string exec { get; set; }

        public bool is_hidden { get; private set; default = false; }
        public bool is_valid { get; private set; default = true; }
        public bool is_control_panel { get; private set; default = false; }

        private string? name_folded = null;
        public unowned string get_name_folded () {
            if (name_folded == null) {
                name_folded = name.casefold ();
            }

            return name_folded;
        }

        public EnvironmentType show_in { get; set; default = EnvironmentType.ALL; }

        private const string[] SUPPORTED_GETTEXT_DOMAINS_KEYS = {"X-Ubuntu-Gettext-Domain", "X-GNOME-Gettext-Domain"};

        public DesktopFileInfo.for_desktop_app_info (GLib.DesktopAppInfo app_info) {
            Object (desktop_id: app_info.get_id (), filename: app_info.filename );

            init_from_desktop_app_info (app_info);
        }

        private EnvironmentType parse_environments (string[] environments) {
            EnvironmentType result = 0;
            foreach (unowned string env in environments) {
                string env_up = env.up ();
                switch (env_up) {
                    case "BUDGIE":
                    case "GNOME":
                    case "X-CINNAMON":
                    case "UBUNTU":
                        result |= EnvironmentType.GNOME;
                        break;
                    case "PANTHEON":
                        result |= EnvironmentType.PANTHEON;
                        break;
                    case "KDE":
                        result |= EnvironmentType.KDE;
                        break;
                    case "LXDE":
                        result |= EnvironmentType.LXDE;
                        break;
                    case "LXQT":
                        result |= EnvironmentType.LXQT;
                        break;
                    case "MATE":
                        result |= EnvironmentType.MATE;
                        break;
                    case "RAZOR":
                        result |= EnvironmentType.RAZOR;
                        break;
                    case "ROX": result |= EnvironmentType.ROX; break;
                    case "TDE": result |= EnvironmentType.TDE; break;
                    case "UNITY":
                    case "UNITY7":
                        result |= EnvironmentType.UNITY;
                        break;
                    case "XFCE": result |= EnvironmentType.XFCE; break;
                    case "OLD": result |= EnvironmentType.OLD; break;
                    //default: warning ("%s is not understood", env); break;
                    default: break;
                }
            }
            return result;
        }

        private void init_from_desktop_app_info (GLib.DesktopAppInfo app_info) {
            try {
                if (app_info.get_string (KeyFileDesktop.KEY_TYPE) != KeyFileDesktop.TYPE_APPLICATION) {
                    throw new DesktopFileError.UNINTERESTING_ENTRY ("Not Application-type desktop entry");
                }

                if (app_info.has_key (KeyFileDesktop.KEY_CATEGORIES)) {
                    string[] categories = app_info.get_string_list (KeyFileDesktop.KEY_CATEGORIES);
                    if ("Screensaver" in categories) {
                        throw new DesktopFileError.UNINTERESTING_ENTRY ("Screensaver desktop entry");
                    }
                }

                foreach (unowned string domain_key in SUPPORTED_GETTEXT_DOMAINS_KEYS) {
                    if (app_info.has_key (domain_key)) {
                        gettext_domain = app_info.get_string (domain_key);
                        break;
                    }
                }

                name = app_info.get_name ();
                generic_name = app_info.get_generic_name () ?? "";
                exec = app_info.get_commandline ();

                if (exec == null) {
                    throw new DesktopFileError.UNINTERESTING_ENTRY ("Unable to get exec for %s".printf (name));
                }

                is_hidden = !app_info.should_show ();

                string control_center = "gnome-control-center";
                if (Environment.find_program_in_path("budgie-control-center") != null) {
                    control_center = "budgie-control-center";
                }
                if (control_center in exec) {
                    is_hidden = true; // hide all control-center items
                    is_control_panel=true;
                }
                comment = app_info.get_description () ?? "";

                var icon = app_info.get_icon () ??
                new ThemedIcon ("application-default-icon");
                icon_name = icon.to_string ();

                if (app_info.has_key (KeyFileDesktop.KEY_TERMINAL)) {
                    needs_terminal = app_info.get_boolean (KeyFileDesktop.KEY_TERMINAL);
                }
                if (app_info.has_key (KeyFileDesktop.KEY_ONLY_SHOW_IN)) {
                    show_in = parse_environments (app_info.get_string_list (KeyFileDesktop.KEY_ONLY_SHOW_IN));
                } else if (app_info.has_key (KeyFileDesktop.KEY_NOT_SHOW_IN)) {
                    var not_show = parse_environments (app_info.get_string_list (KeyFileDesktop.KEY_NOT_SHOW_IN));
                    show_in = EnvironmentType.ALL ^ not_show;
                }
            } catch (Error err) {
                string name = "Unidentified";

                if (app_info.has_key (KeyFileDesktop.KEY_NAME)) {
                    name = app_info.get_string (KeyFileDesktop.KEY_NAME);
                }

                if (err is DesktopFileError.UNINTERESTING_ENTRY) {
                    debug ("Ignoring DesktopFileInfo %s - %s", name, err.message);
                } else {
                    warning (
                        "Error initializing DesktopFileInfo from DesktopAppInfo - %s",
                        err.message
                    );
                }

                is_valid = false;
            }
        }
    }

    public class DesktopFileService : Object {
        private static unowned DesktopFileService? instance;
        private Utils.AsyncOnce<bool> init_once;

        // singleton that can be easily destroyed
        public static DesktopFileService get_default () {
            return instance ?? new DesktopFileService ();
        }

        private const int DEFAULT_TIMEOUT_SECONDS = 3;

        private DesktopFileService () { }

        private GLib.AppInfoMonitor app_info_monitor;
        private Gee.List<DesktopFileInfo> non_hidden_desktop_files;
        private Gee.Map<string, Gee.List<DesktopFileInfo>> exec_map;
        private Gee.Map<string, DesktopFileInfo> desktop_id_map;

        public signal void reload_started ();
        public signal void reload_done ();

        private uint queued_update_id = 0;
        private Regex exec_regex;

        construct {
            instance = this;

            non_hidden_desktop_files = new Gee.ArrayList<DesktopFileInfo> ();
            exec_map = new Gee.HashMap<string, Gee.List<DesktopFileInfo>> ();
            desktop_id_map = new Gee.HashMap<string, DesktopFileInfo> ();

            init_once = new Utils.AsyncOnce<bool> ();

            try {
                exec_regex = new Regex ("%[fFuU]");
            } catch (Error err) {
                warning ("Unable to construct exec regex: %s", err.message);
            }

            initialize.begin ();
        }

        ~DesktopFileService () {
            instance = null;
        }

        public async void initialize () {
            if (init_once.is_initialized ()) {
                return;
            }
            var is_locked = yield init_once.enter ();
            if (!is_locked) {
                return;
            }

            load_all_desktop_files ();

            app_info_monitor = GLib.AppInfoMonitor.@get ();
            app_info_monitor.changed.connect (queue_cache_update);

            init_once.leave (true);
        }

        private void queue_cache_update () {
            reload_started ();

            if (queued_update_id != 0) {
                GLib.Source.remove (queued_update_id);
            }

            queued_update_id = GLib.Timeout.add_seconds (DEFAULT_TIMEOUT_SECONDS, () => {
                load_all_desktop_files ();
                reload_done ();

                queued_update_id = 0;

                return GLib.Source.REMOVE;
            });
        }


        private void load_all_desktop_files () {
            non_hidden_desktop_files.clear ();
            exec_map.clear ();
            desktop_id_map.clear ();

            var app_infos = GLib.AppInfo.get_all ();
            foreach (unowned GLib.AppInfo app in app_infos) {
                if (app.should_show ()) {
                    unowned GLib.DesktopAppInfo app_info = (GLib.DesktopAppInfo)app;
                    var dfi = new DesktopFileInfo.for_desktop_app_info (app_info);

                    non_hidden_desktop_files.add (dfi);
                    desktop_id_map.set (dfi.desktop_id, dfi);

                    string exec = dfi.exec;
                    if (exec_regex != null) {
                        try {
                            exec = exec_regex.replace_literal (dfi.exec, -1, 0, "");
                            exec = exec.strip ();
                        } catch (RegexError err) {
                            critical (err.message);
                        }
                    }

                    // update exec map
                    Gee.List<DesktopFileInfo>? exec_list = exec_map[exec];
                    if (exec_list == null) {
                        exec_list = new Gee.ArrayList<DesktopFileInfo> ();
                        exec_map[exec] = exec_list;
                    }
                    exec_list.add (dfi);
                }
            }
        }

        // retuns desktop files available on the system (without hidden ones)
        public Gee.List<DesktopFileInfo> get_desktop_files () {
            return non_hidden_desktop_files.read_only_view;
        }

        public Gee.List<DesktopFileInfo> get_desktop_files_for_exec (string exec) {
            return exec_map[exec] ?? new Gee.ArrayList<DesktopFileInfo> ();
        }

        public DesktopFileInfo? get_desktop_file_for_id (string desktop_id) {
            return desktop_id_map[desktop_id];
        }
    }
}
