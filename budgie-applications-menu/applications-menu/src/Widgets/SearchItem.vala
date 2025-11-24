/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *           2011-2012 Giulio Collura
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

public class Slingshot.Widgets.SearchItem : Gtk.ListBoxRow {
    public enum ResultType {
        UNKNOWN = 0,
        TEXT,
        APPLICATION,
        BOOKMARK,
        APP_ACTIONS,
        ACTION,
        GENERIC_URI,
        SEARCH,
        CONTACT,
        INTERNET,
        SETTINGS,
        LINK;

        public unowned string to_string () {
            switch (this) {
                case TEXT:
                    return _("Text");
                case APPLICATION:
                    return _("Applications");
                case GENERIC_URI:
                    return _("Files");
                case LINK:
                case ACTION:
                    return _("Actions");
                case SEARCH:
                    return _("Search");
                case CONTACT:
                    return _("Contacts");
                case INTERNET:
                    return _("Internet");
                case SETTINGS:
                    return _("Settings");
                case APP_ACTIONS:
                    return _("Application Actions");
                case BOOKMARK:
                    return _("Bookmarks");
                default:
                    return _("Other");
            }
        }
    }

    private const int ICON_SIZE = 32;

    public signal bool launch_app ();

    public Backend.App app { get; construct; }
    public string search_term { get; construct; }
    public ResultType result_type { public get; construct; }

    public Gtk.Image icon { public get; private set; }
    public string? app_uri { get; private set; }

    private Slingshot.AppContextMenu menu;

    private Gtk.Label name_label;
    private Cancellable? cancellable = null;

    public SearchItem (Backend.App app, string search_term = "", ResultType result_type = ResultType.UNKNOWN) {
        Object (
            app: app,
            search_term: search_term,
            result_type: result_type
        );
    }

    construct {
        string markup;
        if (result_type == SearchItem.ResultType.TEXT) {
            markup = app.match.title;
        } else if (result_type == SearchItem.ResultType.APP_ACTIONS) {
            markup = markup_string_with_search (app.match.title, search_term);
        } else {
            markup = markup_string_with_search (app.name, search_term);
        }

        name_label = new Gtk.Label (markup);
        name_label.set_ellipsize (Pango.EllipsizeMode.END);
        name_label.use_markup = true;
        name_label.xalign = 0;

        icon = new Gtk.Image ();
        icon.gicon = app.icon;
        icon.pixel_size = ICON_SIZE;

        tooltip_markup = app.description;

        if (app.match != null && app.match.icon_name.has_prefix (Path.DIR_SEPARATOR_S)) {
            var pixbuf = Backend.SynapseSearch.get_pathicon_for_match (app.match, ICON_SIZE);
            if (pixbuf != null) {
                icon.set_from_pixbuf (pixbuf);
            }
        }

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.add (icon);
        grid.add (name_label);
        grid.margin = 6;
        grid.margin_start = 18;

        add (grid);

        if (result_type != SearchItem.ResultType.APP_ACTIONS) {
            launch_app.connect (app.launch);
        }

        app_uri = null;
        var app_match = app.match as Synapse.ApplicationMatch;
        if (app_match != null && app_match.filename != null) {
            app_uri = File.new_for_path (app_match.filename).get_uri ();
        }
    }

    private static string markup_string_with_search (string text, string pattern) {
        const string MARKUP = "%s";

        if (pattern == "") {
            return MARKUP.printf (Markup.escape_text (text));
        }

        // if no text found, use pattern
        if (text == "") {
            return MARKUP.printf (Markup.escape_text (pattern));
        }

        var matchers = Synapse.Query.get_matchers_for_query (
            pattern,
            0,
            RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS
        );

        string? highlighted = null;
        foreach (var matcher in matchers) {
            MatchInfo mi;
            if (matcher.key.match (text, 0, out mi)) {
                int start_pos;
                int end_pos;
                int last_pos = 0;
                int cnt = mi.get_match_count ();
                StringBuilder res = new StringBuilder ();
                for (int i = 1; i < cnt; i++) {
                    mi.fetch_pos (i, out start_pos, out end_pos);
                    warn_if_fail (start_pos >= 0 && end_pos >= 0);
                    res.append (Markup.escape_text (text.substring (last_pos, start_pos - last_pos)));
                    last_pos = end_pos;
                    res.append (Markup.printf_escaped ("<b>%s</b>", mi.fetch (i)));
                    if (i == cnt - 1) {
                        res.append (Markup.escape_text (text.substring (last_pos)));
                    }
                }
                highlighted = res.str;
                break;
            }
        }

        if (highlighted != null) {
            return MARKUP.printf (highlighted);
        } else {
            return MARKUP.printf (Markup.escape_text (text));
        }
    }

    public override void destroy () {
        base.destroy ();
        if (cancellable != null)
            cancellable.cancel ();
    }

    public bool create_context_menu (Gdk.Event e) {

        if (result_type != APPLICATION) {
            return Gdk.EVENT_PROPAGATE;
        }

        menu = new Slingshot.AppContextMenu (app.desktop_id, app.desktop_path);

        if (menu.get_children () != null) {
            if (e.type == Gdk.EventType.KEY_PRESS) {
                menu.popup_at_widget (this, Gdk.Gravity.EAST, Gdk.Gravity.CENTER, e);
                return Gdk.EVENT_STOP;
            } else if (e.type == Gdk.EventType.BUTTON_PRESS) {
                menu.popup_at_pointer (e);
                return Gdk.EVENT_STOP;
            }
        }

        return Gdk.EVENT_PROPAGATE;
    }
}
