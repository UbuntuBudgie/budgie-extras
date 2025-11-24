/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
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

public class Slingshot.Backend.Category : Object {
    public string name { get; construct; }

    // Whether this category should catch applications that fall through the cracks
    public bool other_category { get; construct; }

    public string[] included_categories;
    public string[] excluded_categories;
    public string[] excluded_applications;

    public Gee.ArrayList<App> apps { get; private set; default = new Gee.ArrayList<App> (); }

    public Category (string name, bool other = false) {
        Object (
            name: name,
            other_category: other
        );
    }

    public bool add_app_if_matches (GLib.DesktopAppInfo app) {
        if (app.get_id () in excluded_applications) {
            debug ("Excluding %s from %s because it's in the excluded applications list", app.get_name (), name);
            return false;
        }

        var categories = app.get_categories ();
        if (categories == null) {
            // If this is the "Other" category, then we'll take on apps without categories
            if (other_category) {
                debug ("Including %s in Other because it has no categories", app.get_name ());
                apps.add (new App (app));
                return true;
            }

            debug ("Excluding %s from %s because it has no categories", app.get_name (), name);
            return false;
        }

        bool found_inclusion_category = false;
        foreach (unowned string category in categories.split (";")) {
            if (category in excluded_categories) {
                debug ("Excluding %s from %s because it has an excluded category (%s)", app.get_name (), name, category);
                return false;
            }

            if (category in included_categories) {
                found_inclusion_category = true;
            }
        }

        if (found_inclusion_category) {
            debug ("Including %s in %s because it has an included category", app.get_name (), name);
            apps.add (new App (app));
            return true;
        }

        if (other_category) {
            debug ("Including %s in %s because there wasn't a better match", app.get_name (), name);
            apps.add (new App (app));
            return true;
        }

        debug ("Excluded %s from %s because it didn't match any rules", app.get_name (), name);
        return false;
    }
}
