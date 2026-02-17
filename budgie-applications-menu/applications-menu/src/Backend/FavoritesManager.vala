/*
 * Copyright 2026 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

namespace Slingshot.Backend {
    public class FavoritesManager : Object {
        private static FavoritesManager? instance = null;
        private GLib.Settings settings;
        private Gee.ArrayList<string> favorites_list;

        public signal void favorites_changed ();

        public static FavoritesManager get_default () {
            if (instance == null) {
                instance = new FavoritesManager ();
            }
            return instance;
        }

        construct {
            settings = new GLib.Settings ("org.ubuntubudgie.plugins.budgie-appmenu");
            favorites_list = new Gee.ArrayList<string> ();
            load_favorites ();

            settings.changed["favorites"].connect (() => {
                load_favorites ();
                favorites_changed ();
            });
        }

        private void load_favorites () {
            favorites_list.clear ();
            string[] favs = settings.get_strv ("favorites");
            foreach (unowned string fav in favs) {
                favorites_list.add (fav);
            }
        }

        private void save_favorites () {
            // Create a proper string array to avoid segfault
            string[] favs = new string[favorites_list.size];
            int i = 0;
            foreach (string desktop_id in favorites_list) {
                favs[i++] = desktop_id;
            }
            settings.set_strv ("favorites", favs);
        }

        public void add_favorite (string desktop_id) {
            if (!favorites_list.contains (desktop_id)) {
                favorites_list.add (desktop_id);
                save_favorites ();
                favorites_changed ();
            }
        }

        public void remove_favorite (string desktop_id) {
            if (favorites_list.remove (desktop_id)) {
                save_favorites ();
                favorites_changed ();
            }
        }

        public bool is_favorite (string desktop_id) {
            return favorites_list.contains (desktop_id);
        }

        public void move_favorite (int old_index, int new_index) {
            if (old_index < 0 || old_index >= favorites_list.size ||
                new_index < 0 || new_index >= favorites_list.size) {
                return;
            }

            string item = favorites_list[old_index];
            favorites_list.remove_at (old_index);
            favorites_list.insert (new_index, item);
            save_favorites ();
            favorites_changed ();
        }

        public Gee.List<string> get_favorites () {
            return favorites_list.read_only_view;
        }

        public void validate_favorites () {
            var to_remove = new Gee.ArrayList<string> ();
            var dfs = Synapse.DesktopFileService.get_default ();

            foreach (string desktop_id in favorites_list) {
                var info = dfs.get_desktop_file_for_id (desktop_id);
                if (info == null || info.is_hidden || !info.is_valid) {
                    to_remove.add (desktop_id);
                }
            }

            bool changed = false;
            foreach (string desktop_id in to_remove) {
                favorites_list.remove (desktop_id);
                changed = true;
            }

            if (changed) {
                save_favorites ();
                favorites_changed ();
            }
        }
    }
}
