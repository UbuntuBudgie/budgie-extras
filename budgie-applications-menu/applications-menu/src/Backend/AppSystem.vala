/*
 * Copyright 2011-2021 elementary, Inc. (https://elementary.io)
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

public class Slingshot.Backend.AppSystem : Object {
    public signal void changed ();

    public Gee.HashMap<string, Gee.ArrayList<App>> apps { get; private set; default = null; }

    private const int MENU_REFRESH_TIMEOUT_SECONDS = 3;
    private uint refresh_timeout_id = 0;

    private Gee.ArrayList<Category> categories_cache = null;

    private GLib.AppInfoMonitor app_monitor;

#if HAVE_ZEITGEIST
    private RelevancyService rl_service;
#endif

    construct {
#if HAVE_ZEITGEIST
        rl_service = new RelevancyService ();
        rl_service.update_complete.connect (update_popularity);
#endif

        app_monitor = GLib.AppInfoMonitor.@get ();
        app_monitor.changed.connect (queue_update_app_system);

        apps = new Gee.HashMap<string, Gee.ArrayList<App>> ();
        categories_cache = new Gee.ArrayList<Category> ();

        update_app_system ();
    }

    private void queue_update_app_system () {
        if (refresh_timeout_id != 0) {
            GLib.Source.remove (refresh_timeout_id);
            refresh_timeout_id = 0;
        }

        refresh_timeout_id = GLib.Timeout.add_seconds (MENU_REFRESH_TIMEOUT_SECONDS, () => {
            update_app_system ();
            refresh_timeout_id = 0;

            return GLib.Source.REMOVE;
        });
    }

    private void update_app_system () {
        debug ("Updating Applications menu tree…");
#if HAVE_ZEITGEIST
        rl_service.refresh_popularity ();
#endif

        update_categories_index ();
        changed ();
    }

    private void update_categories_index () {
        categories_cache.clear ();

        categories_cache.add (
            new Category (_("Accessories")) {
                included_categories = { "Utility" },
                // Accessibility spec must have either the Utility or Settings category, and we display an accessibility
                // submenu already for the ones that do not have Settings, so don't display accessibility applications here
                excluded_categories = { "Accessibility", "System" },
                excluded_applications = { "plank.desktop" }
            }
        );

        categories_cache.add (
            new Category (_("Universal Access")) {
                included_categories = { "Accessibility" }
                //excluded_categories = { "Settings" },
                // Do not display OnBoard; it belongs to a11y plug
                //excluded_applications = { "onboard.desktop" }
            }
        );

        categories_cache.add (
            new Category (_("Programming")) {
                included_categories = { "Development" }
            }
        );

        categories_cache.add (
            new Category (_("Education")) {
                included_categories = { "Education" },
                excluded_categories = { "Science" }
            }
        );

        categories_cache.add (
            new Category (_("Science")) {
                included_categories = { "Science", "Education" },
                excluded_applications = { "libreoffice-math.desktop" }
            }
        );

        categories_cache.add (
            new Category (_("Games")) {
                included_categories = { "Game" }
            }
        );

        categories_cache.add (
            new Category (_("Graphics")) {
                included_categories = { "Graphics" }
            }
        );

        categories_cache.add (
            new Category (_("Internet")) {
                included_categories = { "Network" }
            }
        );

        categories_cache.add (
            new Category (_("Sound & Video")) {
                included_categories = { "AudioVideo" }
            }
        );

        categories_cache.add (
            new Category (_("Office")) {
                included_categories = { "Office" }
            }
        );

        categories_cache.add (
            new Category (_("System Tools")) {
                included_categories = { "System", "Administration", "Settings" },
                excluded_categories = { "Game" },
                excluded_applications = { "onboard-settings.desktop" }
            }
        );

        var other_category =
            new Category (_("Other"), true) {
                excluded_categories = { "Core", "Screensaver", "Settings" },
            };

        foreach (var app in GLib.AppInfo.get_all ()) {
            unowned var desktop_app = app as DesktopAppInfo;
            if (desktop_app == null) {
                continue;
            }

            if (!(desktop_app.should_show ())) {
                continue;
            }

            string control_center = "gnome-control-center";

            if (Environment.find_program_in_path("budgie-control-center") != null) {
                control_center = "budgie-control-center";
            }
            if (control_center in app.get_commandline() && app.get_commandline().length != control_center.length) {
                continue; // lets ignore all control-center items
            }

            if (app.get_commandline() == "plank") {
                continue; // lets ignore plank since you wouldnt normally run it manually
            }

            bool found_category = false;
            foreach (var category in categories_cache) {
                if (category.add_app_if_matches (desktop_app)) {
                    found_category = true;
                }
            }

            if (!found_category) {
                other_category.add_app_if_matches (desktop_app);
            }
        }

        if (other_category.apps.size > 0) {
            categories_cache.add (other_category);
        }

        apps.clear ();
        foreach (var cat in categories_cache) {
            if (cat.apps.size > 0) {
                apps.set (cat.name, cat.apps);
            }
        }
    }

#if HAVE_ZEITGEIST
    private void update_popularity () {
        foreach (Gee.ArrayList<App> category in apps.values)
            foreach (App app in category)
                app.popularity = rl_service.get_app_popularity (app.desktop_id);
    }
#endif

    public SList<App> get_apps_by_name () {
        var sorted_apps = new SList<App> ();
        string[] sorted_apps_execs = {};

        foreach (Gee.ArrayList<App> category in apps.values) {
            foreach (App app in category) {
                if (!(app.exec in sorted_apps_execs)) {
                    sorted_apps.insert_sorted_with_data (app, sort_apps_by_name);
                    sorted_apps_execs += app.exec;
                }
            }
        }

        return sorted_apps;
    }

    private static int sort_apps_by_name (Backend.App a, Backend.App b) {
        return a.name.collate (b.name);
    }
}
