/*
* Copyright (c) 2017 David Hewitt <davidmhewitt@gmail.com>
*               2015-2020 elementary LLC. <https://elementary.io>
*               2021 Justin Haygood <jhaygood86@gmail.com>
*               1999, 2000 Eazel, Inc.
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
*/

namespace Synapse {
    public class FileBookmarkPlugin : Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }

        public void activate () { }

        public void deactivate () { }

        public class Result : Synapse.Match {
            public int default_relevancy { get; set; default = 0; }

            private GLib.File location;

            public Result (GLib.File file, string? custom_name) {
                location = file;

                string _name = "";
                string _icon_name = "";

                _icon_name = get_icon_user_special_dirs (location.get_path ());

                if (_icon_name == null && !location.is_native () && is_remote_uri_scheme ()) {
                    _icon_name = "folder-remote";
                }

                if (_icon_name == null && location.has_uri_scheme ("recent")) {
                    _icon_name = "document-open-recent";
                }

                if (_icon_name == null && location.has_uri_scheme ("trash")) {
                    _icon_name = "user-trash";
                }

                if (_icon_name == null) {
                    _icon_name = "folder";
                }

                if (custom_name != null && custom_name.length > 0) {
                    _name = custom_name;
                } else {
                    _name = location.get_basename ();
                }

                var appinfo = AppInfo.get_default_for_uri_scheme (file.get_uri_scheme ());
                if (appinfo == null) {
                    try {
                        var info = file.query_info (
                            FileAttribute.STANDARD_CONTENT_TYPE, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null
                        );

                        if (info.has_attribute (FileAttribute.STANDARD_CONTENT_TYPE)) {
                            appinfo = AppInfo.get_default_for_type (
                                info.get_attribute_string (FileAttribute.STANDARD_CONTENT_TYPE), true
                            );
                        }
                    } catch (Error e) {
                        appinfo = new DesktopAppInfo ("io.elementary.files.desktop");
                    }
                }

                string _title = _("Open %s in %s").printf (_name, appinfo.get_display_name ());

                this.title = _title;
                this.icon_name = _icon_name;
                this.description = _("Open the selected directory");
                this.has_thumbnail = false;
                this.match_type = MatchType.BOOKMARK;
            }

            public override void execute (Match? match) {
                try {
                    GLib.AppInfo.launch_default_for_uri (location.get_uri (), null);
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }
            }

            public bool is_remote_uri_scheme () {
                return (is_root_network_folder () || is_other_uri_scheme ());
            }

            public bool is_root_network_folder () {
                return (is_network_uri_scheme () || is_smb_server ());
            }

            public bool is_smb_server () {
                if (is_smb_uri_scheme () || is_network_uri_scheme ()) {
                    return get_number_of_uri_parts () == 2;
                }

                return false;
            }

            public bool is_network_uri_scheme () {
                if (!(location is GLib.File)) {
                    return true;
                }

                return location.has_uri_scheme ("network");
            }

            public bool is_smb_uri_scheme () {
                if (!(location is GLib.File)) {
                    return true;
                }

                return location.has_uri_scheme ("smb");
            }

            public bool is_other_uri_scheme () {
                if (!(location is GLib.File)) {
                    return true;
                }

                return location.has_uri_scheme ("ftp") ||
                       location.has_uri_scheme ("sftp") ||
                       location.has_uri_scheme ("afp") ||
                       location.has_uri_scheme ("dav") ||
                       location.has_uri_scheme ("davs");
            }

            private uint get_number_of_uri_parts () {
                unowned string target_uri = null;

                FileInfo? info = null;

                try {
                    info = location.query_info ("", FileQueryInfoFlags.NONE);
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }

                if (info != null) {
                    target_uri = info.get_attribute_string (GLib.FileAttribute.STANDARD_TARGET_URI);
                }

                if (target_uri == null) {
                    var uri = location.get_uri ();
                    target_uri = uri;
                }

                return target_uri.split ("/", 6).length;
            }

            private string? get_icon_user_special_dirs (string? path) {

                if (path == null) {
                    return null;
                }

                if (path == GLib.Environment.get_home_dir ()) {
                    return "user-home";
                } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.DESKTOP)) {
                    return "user-desktop";
                } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.DOCUMENTS)) {
                    return "folder-documents";
                } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD)) {
                    return "folder-download";
                } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.MUSIC)) {
                    return "folder-music";
                } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.PICTURES)) {
                    return"folder-pictures";
                } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.PUBLIC_SHARE)) {
                    return "folder-publicshare";
                } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.TEMPLATES)) {
                    return "folder-templates";
                } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS)) {
                    return "folder-videos";
                }

                return null;
            }
        }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (typeof (FileBookmarkPlugin),
                                            _("Folder Bookmarks"),
                                            _("Bookmarked Folders"),
                                            "help-about",
                                            register_plugin,
                                            true,
                                            "");
        }

        static construct {
            register_plugin ();
        }

        public async Synapse.ResultSet? search (Synapse.Query q) throws Synapse.SearchError {

            var matchers = Query.get_matchers_for_query (q.query_string_folded, 0);
            var results = new Synapse.ResultSet ();

            // Check for Special Directories

            if (yield check_for_match (results, matchers, File.new_for_path (Environment.get_home_dir ()), _("Home"))) {
                return results;
            }

            if (yield check_for_match (results, matchers, File.new_for_uri ("recent://"), _("Recent"))) {
                return results;
            }

            if (yield check_for_match (results, matchers, File.new_for_uri ("trash://"), _("Trash"))) {
                return results;
            }

            string filename = GLib.Path.build_filename (Environment.get_home_dir (),
                                                        ".config",
                                                        "gtk-3.0",
                                                        "bookmarks",
                                                        null);

            var file = GLib.File.new_for_path (filename);

            if (yield query_exists_async (file)) {
                uint8[] contents_bytes;

                q.check_cancellable ();

                try {
                    yield file.load_contents_async (null, out contents_bytes, null);
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }

                q.check_cancellable ();

                if (contents_bytes != null) {
                    string contents = (string)contents_bytes;

                    string [] lines = contents.split ("\n");

                    foreach (string line in lines) {

                        q.check_cancellable ();

                        if (line[0] == '\0' || line[0] == ' ') {
                            continue; /* ignore blank lines */
                        }

                        string [] parts = line.split (" ", 2);
                        string uri = parts[0];
                        string custom_name = parts.length == 2 ? parts[1] : "";

                        if (custom_name != "" &&
                            (custom_name.strip () == "" || // Custom name cannot be all whitespace
                            custom_name == Path.get_basename (uri))) { // Custom names cannot be the same as the default name

                            custom_name = "";
                        }

                        var location = GLib.File.new_for_uri (uri);

                        var matched = yield check_for_match (results, matchers, location, custom_name);

                        if (matched) {
                            break;
                        }
                    }
                }
            }

            return results;
        }

        private async bool check_for_match (Synapse.ResultSet results,
                                            Gee.List<Gee.Map.Entry<Regex, int>> matchers,
                                            GLib.File location,
                                            string custom_name) {

            MatchInfo info;
            bool is_hidden = false;

            try {
                var location_info = yield location.query_info_async ("", FileQueryInfoFlags.NONE);

                is_hidden = location_info.get_is_hidden () || location_info.get_is_backup ();
            } catch (GLib.Error err) {
                warning ("%s", err.message);
            }

            if (is_hidden) {
                return false;
            }

            var uri = location.get_uri ();

            var basename = location.get_basename ().down ();
            var custom_name_for_match = custom_name.down ();

            var matched = false;

            foreach (var matcher in matchers) {

                if (matcher.key.match (basename, RegexMatchFlags.PARTIAL, out info)) {
                    results.add (new Result (location, custom_name), compute_relevancy (uri, matcher.value));
                    matched = true;
                    break;
                } else if (matcher.key.match (custom_name_for_match, RegexMatchFlags.PARTIAL, out info)) {
                    results.add (new Result (location, custom_name), compute_relevancy (uri, matcher.value));
                    matched = true;
                    break;
                }
            }

            return matched;
        }

        private int compute_relevancy (string uri, int base_relevancy) {
            var rs = RelevancyService.get_default ();
            float popularity = rs.get_uri_popularity (uri);

            int r = RelevancyService.compute_relevancy (base_relevancy, popularity);
            debug ("relevancy for %s: %d", uri, r);

            return r;
        }

        private static async bool query_exists_async (File file) {

            try {
                var info = yield file.query_info_async (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                return info != null;
            } catch (Error e) {
                return false;
            }
        }
    }
}
