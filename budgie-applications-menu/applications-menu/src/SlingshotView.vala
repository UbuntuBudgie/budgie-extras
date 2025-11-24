/*
 * Copyright 2019–2021 elementary, Inc. (https://elementary.io)
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

#if HAS_PLANK
public class Slingshot.SlingshotView : Gtk.Grid, Plank.UnityClient {
#else
public class Slingshot.SlingshotView : Gtk.Grid {
#endif
    public signal void close_indicator ();

    public Backend.AppSystem app_system;
    public Gtk.SearchEntry search_entry;
    private AppMenu.PowerStrip powerstrip;
    public Gtk.Stack stack;
    public Granite.Widgets.ModeButton view_selector;

    private enum Modality {
        NORMAL_VIEW = 0,
        CATEGORY_VIEW = 1,
        SEARCH_VIEW
    }

    public const int DEFAULT_ROWS = 3;

    private Backend.SynapseSearch synapse;
    private Gdk.Screen screen;
    private Gtk.Revealer view_selector_revealer;
    private Modality modality;
    private Widgets.Grid grid_view;
    private Gtk.Grid container;
    private Gtk.Grid top;
    private Widgets.SearchView search_view;
    private Widgets.CategoryView category_view;

    private static GLib.Settings settings { get; private set; default = null; }

    static construct {
        settings = new GLib.Settings ("org.ubuntubudgie.plugins.budgie-appmenu");
    }

    construct {
        app_system = new Backend.AppSystem ();
        synapse = new Backend.SynapseSearch ();

        screen = get_screen ();

        var grid_image = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.MENU);
#if GRANITE5
        grid_image.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>1"}, _("View as Grid"));
#endif
        var category_image = new Gtk.Image.from_icon_name ("view-filter-symbolic", Gtk.IconSize.MENU);
#if GRANITE5
        category_image.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>2"}, _("View by Category"));
#endif

        view_selector = new Granite.Widgets.ModeButton ();
        view_selector.margin_end = 12;
        view_selector.append (grid_image);
        view_selector.append (category_image);

        view_selector_revealer = new Gtk.Revealer ();
        view_selector_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        view_selector_revealer.add (view_selector);

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Apps");
        search_entry.hexpand = true;
#if GRANITE5
        search_entry.secondary_icon_tooltip_markup = Granite.markup_accel_tooltip (
            {"<Ctrl>BackSpace"}, _("Clear all")
        );
#endif

        powerstrip = new AppMenu.PowerStrip();

        top = new Gtk.Grid ();
        top.margin_start = 12;
        top.margin_end = 12;
        top.add (view_selector_revealer);
        top.add (search_entry);
        top.add (powerstrip);

        grid_view = new Widgets.Grid ();

        category_view = new Widgets.CategoryView (this);

        search_view = new Widgets.SearchView ();

        stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        stack.add_named (grid_view, "normal");
        stack.add_named (category_view, "category");
        stack.add_named (search_view, "search");

        container = new Gtk.Grid ();
        container.row_spacing = 12;
        container.margin_bottom = 12;
        container.attach (top, 0, 1);
        container.attach (stack, 0, 0);

        // This function must be after creating the page switcher
        grid_view.populate (app_system);

        var event_box = new Gtk.EventBox ();
        event_box.add (container);

        // Add the container to the dialog's content area
        this.add (event_box);

        if (settings.get_boolean ("use-category")) {
            view_selector.selected = 1;
            set_modality (Modality.CATEGORY_VIEW);
        } else {
            view_selector.selected = 0;
            set_modality (Modality.NORMAL_VIEW);
        }

        /*search_view.start_search.connect ((match, target) => {
            search.begin (search_entry.text, match, target);
        }); UB apparently unneccessary*/

        focus_in_event.connect (() => {
            search_entry.grab_focus ();
            return Gdk.EVENT_PROPAGATE;
        });

        event_box.key_press_event.connect (on_event_box_key_press);
        search_entry.key_press_event.connect (on_search_view_key_press);

        // Showing a menu reverts the effect of the grab_device function.
        search_entry.search_changed.connect (() => {
            if (modality != Modality.SEARCH_VIEW) {
                set_modality (Modality.SEARCH_VIEW);
            }
            search.begin (search_entry.text);
        });

        search_entry.grab_focus ();
        search_entry.activate.connect (search_entry_activated);

        category_view.search_focus_request.connect (() => {
            search_entry.grab_focus ();
        });

        grid_view.app_launched.connect (() => {
            close_indicator ();
        });

        search_view.app_launched.connect (() => {
            close_indicator ();
        });

        view_selector.mode_changed.connect (() => {
            set_modality ((Modality) view_selector.selected);
        });

        // Auto-update applications grid
        app_system.changed.connect (() => {
            grid_view.populate (app_system);

            category_view.setup_sidebar ();
        });

        settings.changed["rows"].connect_after(() => {
            grid_view.populate (app_system);
        });

        settings.changed["columns"].connect_after(() => {
            grid_view.populate (app_system);
        });

        settings.changed["show-terminal-apps"].connect_after(() => {
            grid_view.populate (app_system);
            category_view.setup_sidebar ();
        });

        powerstrip.invoke_action.connect(() => {
            close_indicator ();
        });
        powerstrip.set_visible(settings.get_boolean("enable-powerstrip"));
    }

    public void panel_position_changed(Budgie.PanelPosition position) {
        if (position == Budgie.PanelPosition.BOTTOM) {
            container.margin_bottom = 12;
            container.margin_top = 0;

            container.remove_row(1);
            container.remove_row(0);

            container.attach (top, 0, 1);
            container.attach (stack, 0, 0);
        }
        else {
            container.margin_bottom = 0;
            container.margin_top = 12;

            container.remove_row(1);
            container.remove_row(0);

            container.attach (top, 0, 0);
            container.attach (stack, 0, 1);
        }
        container.show_all();
    }

#if HAS_PLANK
    public void update_launcher_entry (string sender_name, GLib.Variant parameters, bool is_retry = false) {
        if (!is_retry) {
            // Wait to let further update requests come in to catch the case where one application
            // sends out multiple LauncherEntry-updates with different application-uris, e.g. Nautilus
            Idle.add (() => {
                update_launcher_entry (sender_name, parameters, true);
                return false;
            });

            return;
        }

        string app_uri;
        VariantIter prop_iter;
        parameters.get ("(sa{sv})", out app_uri, out prop_iter);

        foreach (var app in app_system.get_apps_by_name ()) {
            if (app_uri == "application://" + app.desktop_id) {
                app.perform_unity_update (sender_name, prop_iter);
            }
        }
    }

    public void remove_launcher_entry (string sender_name) {
        foreach (var app in app_system.get_apps_by_name ()) {
            app.remove_launcher_entry (sender_name);
        }
    }
#endif

    private void search_entry_activated () {
        if (modality == Modality.SEARCH_VIEW) {
            search_view.activate_selection ();
        }
    }

    /* These keys do not work if connect_after used; the rest of the key events
     * are dealt with after the default handler in order that CJK input methods
     * work properly */
    public bool on_search_view_key_press (Gdk.EventKey event) {
        var key = Gdk.keyval_name (event.keyval).replace ("KP_", "");

        switch (key) {
            case "Down":
                search_entry.move_focus (Gtk.DirectionType.TAB_FORWARD);
                return Gdk.EVENT_STOP;

            case "Escape":
                if (search_entry.text.length > 0) {
                    search_entry.text = "";
                } else {
                    close_indicator ();
                }

                return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    public bool on_event_box_key_press (Gdk.EventKey event) {
        var key = Gdk.keyval_name (event.keyval).replace ("KP_", "");
        if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            switch (key) {
                case "1":
                    view_selector.selected = 0;
                    return Gdk.EVENT_STOP;
                case "2":
                    view_selector.selected = 1;
                    return Gdk.EVENT_STOP;
            }
        }

        // Alt accelerators
        if ((event.state & Gdk.ModifierType.MOD1_MASK) != 0) {
            switch (key) {
                case "F4":
                    close_indicator ();
                    return Gdk.EVENT_STOP;

                case "0":
                case "1":
                case "2":
                case "3":
                case "4":
                case "5":
                case "6":
                case "7":
                case "8":
                case "9":
                    if (modality == Modality.NORMAL_VIEW) {
                        int page = int.parse (key);
                        if (page < 0 || page == 9) {
                            grid_view.go_to_last ();
                        } else {
                            grid_view.go_to_number (page);
                        }
                    }

                    // FIXME: Workaround to avoid losing focus completely
                    search_entry.grab_focus ();
                    return Gdk.EVENT_STOP;
            }
        }

        switch (key) {
            case "Down":
            case "Enter": // "KP_Enter"
            case "Home":
            case "KP_Enter":
            case "Left":
            case "Return":
            case "Right":
            case "Tab":
            case "Up":
                return Gdk.EVENT_PROPAGATE;

            case "Page_Up":
                if (modality == Modality.NORMAL_VIEW) {
                    grid_view.go_to_previous ();
                } else if (modality == Modality.CATEGORY_VIEW) {
                    category_view.page_up ();
                }
                break;

            case "Page_Down":
                if (modality == Modality.NORMAL_VIEW) {
                    grid_view.go_to_next ();
                } else if (modality == Modality.CATEGORY_VIEW) {
                    category_view.page_down ();
                }
                break;

            case "BackSpace":
                if (!search_entry.has_focus) {
                    search_entry.grab_focus ();
                    search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                }
                return Gdk.EVENT_PROPAGATE;
            case "End":
                if (modality == Modality.NORMAL_VIEW) {
                    grid_view.go_to_last ();
                }

                return Gdk.EVENT_PROPAGATE;
            default:
                if (!search_entry.has_focus && event.is_modifier != 1) {
                    search_entry.grab_focus ();
                    search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                    //search_entry.key_press_event (event); causes double letter entry into the entry field under wayland
                }
                return Gdk.EVENT_PROPAGATE;

        }

        return Gdk.EVENT_STOP;
    }

    public void show_slingshot () {
        search_entry.text = "";

    /* TODO
        set_focus (null);
    */

        search_entry.grab_focus ();
        // This is needed in order to not animate if the previous view was the search view.
        view_selector_revealer.transition_type = Gtk.RevealerTransitionType.NONE;
        stack.transition_type = Gtk.StackTransitionType.NONE;
        set_modality ((Modality) view_selector.selected);
        view_selector_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        powerstrip.set_visible(settings.get_boolean("enable-powerstrip"));
        stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
    }

    private void set_modality (Modality new_modality) {
        modality = new_modality;

        switch (modality) {
            case Modality.NORMAL_VIEW:
                if (settings.get_boolean ("use-category")) {
                    settings.set_boolean ("use-category", false);
                }

                view_selector_revealer.set_reveal_child (true);
                stack.set_visible_child_name ("normal");

                search_entry.grab_focus ();
                break;

            case Modality.CATEGORY_VIEW:
                if (!settings.get_boolean ("use-category")) {
                    settings.set_boolean ("use-category", true);
                }

                view_selector_revealer.set_reveal_child (true);
                stack.set_visible_child_name ("category");

                search_entry.grab_focus ();
                break;

            case Modality.SEARCH_VIEW:
                view_selector_revealer.set_reveal_child (false);
                stack.set_visible_child_name ("search");
                break;

        }
    }

    private async void search (string text, Synapse.SearchMatch? search_match = null,
        Synapse.Match? target = null) {

        var stripped = text.strip ();

        if (stripped == "") {
            // this code was making problems when selecting the currently searched text
            // and immediately replacing it. In that case two async searches would be
            // started and both requested switching from and to search view, which would
            // result in a Gtk error and the first letter of the new search not being
            // picked up. If we add an idle and recheck that the entry is indeed still
            // empty before switching, this problem is gone.
            Idle.add (() => {
                if (search_entry.text.strip () == "")
                    set_modality ((Modality) view_selector.selected);
                return false;
            });
            return;
        }

        if (modality != Modality.SEARCH_VIEW)
            set_modality (Modality.SEARCH_VIEW);

        Gee.List<Synapse.Match> matches;

        if (search_match != null) {
            search_match.search_source = target;
            matches = yield synapse.search (text, search_match);
        } else {
            matches = yield synapse.search (text);
        }

        Idle.add (() => {
            search_view.set_results (matches, text);
            return false;
        });
    }
}
