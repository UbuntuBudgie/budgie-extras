/*
* Copyright (c) 2010 Magnus Kulke <mkulke@gmail.com>
*               2017 elementary LLC.
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
* Authored by: Magnus Kulke <mkulke@gmail.com>
*/

namespace Synapse {
    public class LinkPlugin: Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }

        public void activate () { }

        public void deactivate () { }

        public class Result : Synapse.Match {
            public int default_relevancy { get; set; default = 0; }

            private string uri;
            private AppInfo? appinfo;

            public Result (string link) {
                uri = link;
                string _title = _("Open %s in default web browser").printf (uri);
                string _icon_name = "web-browser";

                appinfo = AppInfo.get_default_for_type ("x-scheme-handler/http", false);
                if (appinfo != null) {
                    _title = _("Open %s in %s").printf (uri, appinfo.get_display_name ());
                    _icon_name = appinfo.get_icon ().to_string ();
                }

                this.title = _title;
                this.icon_name = _icon_name;
                this.description = _("Open this link in default browser");
                this.has_thumbnail = false;
                this.match_type = MatchType.ACTION;
            }

            public override void execute (Match? match) {
                if (appinfo == null) {
                    return;
                }

                var list = new List<string> ();
                list.append (uri);
                try {
                    appinfo.launch_uris (list, null);
                } catch (Error e) {
                    warning ("%s\n", e.message);
                }
            }
        }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (typeof (LinkPlugin),
                                                                    _("Link"),
                                                                    _("Open link in default browser"),
                                                                    "web-browser",
                                                                    register_plugin);
        }

        static construct {
            register_plugin ();
        }

        private Regex regex;

        construct {
            try {
                regex = new Regex ("[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{2,4}\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*)",
                RegexCompileFlags.OPTIMIZE);
            } catch (Error e) {
                critical ("Error creating regexp: %s", e.message);
            }
        }

        public bool handles_query (Query query) {
            return QueryFlags.TEXT in query.query_type;
        }

        public async ResultSet? search (Query query) throws SearchError {
            bool matched = regex.match (query.query_string);
            if (matched) {
                Result result = new Result (query.query_string);
                ResultSet results = new ResultSet ();
                results.add (result, Match.Score.AVERAGE);
                query.check_cancellable ();

                return results;
            }

            return null;
        }
    }
}
