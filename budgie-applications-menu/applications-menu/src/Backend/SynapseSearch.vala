// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Slingshot.Backend {

    public class SynapseSearch : Object {

        private static Type[] plugins = {
            typeof (Synapse.CalculatorPlugin),
            typeof (Synapse.CommandPlugin),
            typeof (Synapse.DesktopFilePlugin),
            typeof (Synapse.LinkPlugin),
            typeof (Synapse.ControlPanelPlugin),
            typeof (Synapse.SystemManagementPlugin),
            typeof (Synapse.FileBookmarkPlugin)
        };

        private static Synapse.DataSink? sink = null;
        private static Gee.HashMap<string,Gdk.Pixbuf> favicon_cache;

        Cancellable? current_search = null;

        public SynapseSearch () {

            if (sink == null) {
                sink = new Synapse.DataSink ();
                foreach (var plugin in plugins) {
                    sink.register_static_plugin (plugin);
                }

                favicon_cache = new Gee.HashMap<string,Gdk.Pixbuf> ();
            }
        }

        public async Gee.List<Synapse.Match>? search (string text, Synapse.SearchProvider? provider = null) {

            if (current_search != null)
                current_search.cancel ();

            if (provider == null)
                provider = sink;

            var results = new Synapse.ResultSet ();

            try {
                return yield provider.search (text, Synapse.QueryFlags.ALL, results, current_search);
            } catch (Error e) { warning (e.message); }

            return null;
        }

        public static Gee.List<Synapse.Match> find_actions_for_match (Synapse.Match match) {
            return sink.find_actions_for_match (match, null, Synapse.QueryFlags.ALL);
        }

        public static Gdk.Pixbuf? get_pathicon_for_match (Synapse.Match match, int size) {
            Gdk.Pixbuf? pixbuf = null;
            try {
                var file = File.new_for_path (match.icon_name);
                if (file.query_exists ()) {
                    pixbuf = new Gdk.Pixbuf.from_file_at_scale (match.icon_name, size, size, true);
                }
            } catch (Error e) {
                warning (e.message);
            }

            return pixbuf;
        }
    }
}
