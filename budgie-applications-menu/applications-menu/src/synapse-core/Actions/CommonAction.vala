/*
* Copyright (c) 2010 Michal Hruby <michal.mhr@gmail.com>
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
* Authored by: Michal Hruby <michal.mhr@gmail.com>
*/

namespace Synapse {

    public class CommonActions: Object, Activatable, Synapse.ActionProvider {
        public bool enabled { get; set; default = true; }

        public void activate () { }

        public void deactivate () { }

        private Gee.List<BaseAction> actions;

        construct {
            actions = new Gee.ArrayList<BaseAction> ();

            actions.add (new RunnerAction ());
            actions.add (new TerminalRunnerAction ());
            actions.add (new ClipboardCopyAction ());
        }

        public ResultSet? find_for_match (ref Query query, Match match) {
            bool query_empty = query.query_string == "";
            var results = new ResultSet ();

            if (query_empty) {
                foreach (var action in actions) {
                    if (action.valid_for_match (match)) {
                        results.add (action, action.get_relevancy_for_match (match));
                    }
                }
            } else {
                var matchers = Query.get_matchers_for_query (
                    query.query_string,
                    0,
                    RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS
                );
                foreach (var action in actions) {
                    if (!action.valid_for_match (match)) {
                        continue;
                    }

                    foreach (var matcher in matchers) {
                        if (matcher.key.match (action.title)) {
                            results.add (action, matcher.value);
                            break;
                        }
                    }
                }
            }

            return results;
        }

        public static void open_uri (string uri) {
            var f = File.new_for_uri (uri);
            try {
                var app_info = f.query_default_handler (null);
                var files = new GLib.List<File> ();
                files.prepend (f);
                var display = Gdk.Display.get_default ();
                app_info.launch (files, display.get_app_launch_context ());
            } catch (Error err) {
                critical (err.message);
            }
        }
    }
}
