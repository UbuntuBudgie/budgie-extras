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
    private Widgets.FavoritesSidebar? favorites_sidebar = null;
    private Gtk.Separator? favorites_separator = null;
    private Gtk.Overlay content_overlay;
    private Gtk.Grid content_grid;

    // The floating context menu shown over the main area when right-clicking a favourite
    private Gtk.Box? ctx_menu_widget = null;

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

        // Favourites sidebar
        favorites_sidebar = new Widgets.FavoritesSidebar ();
        favorites_sidebar.set_app_system (app_system);
        favorites_sidebar.app_launched.connect (() => { close_indicator (); });
        favorites_sidebar.no_show_all = true;

        favorites_separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
        favorites_separator.no_show_all = true;

        // content_grid holds sidebar | separator | stack (unchanged column layout)
        content_grid = new Gtk.Grid ();
        content_grid.attach (favorites_sidebar, 0, 0, 1, 1);
        content_grid.attach (favorites_separator, 1, 0, 1, 1);
        content_grid.attach (stack, 2, 0, 1, 1);

        // Overlay sits on top of content_grid; context menus are added here
        content_overlay = new Gtk.Overlay ();
        content_overlay.add (content_grid);
        content_overlay.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
        content_overlay.button_press_event.connect (on_overlay_background_click);

        container = new Gtk.Grid ();
        container.row_spacing = 12;
        container.margin_bottom = 12;
        container.attach (top, 0, 1);
        container.attach (content_overlay, 0, 0);

        grid_view.populate (app_system);

        var event_box = new Gtk.EventBox ();
        event_box.add (container);
        this.add (event_box);

        // ── Context menu overlay wiring ───────────────────────────────────
        favorites_sidebar.show_context_menu.connect ((menu_widget, y_center) => {
            dismiss_ctx_menu ();

            ctx_menu_widget = menu_widget as Gtk.Box;
            ctx_menu_widget.halign = Gtk.Align.START;
            ctx_menu_widget.valign = Gtk.Align.START;
            ctx_menu_widget.margin_start = 70;
            ctx_menu_widget.margin_top = int.max (0, y_center - 20);

            content_overlay.add_overlay (ctx_menu_widget);
            content_overlay.show_all ();
        });

        favorites_sidebar.hide_context_menu.connect (() => {
            dismiss_ctx_menu ();
        });

        event_box.key_press_event.connect (on_event_box_key_press);
        search_entry.key_press_event.connect (on_search_view_key_press);

        if (settings.get_boolean ("use-category")) {
            view_selector.selected = 1;
            set_modality (Modality.CATEGORY_VIEW);
        } else {
            view_selector.selected = 0;
            set_modality (Modality.NORMAL_VIEW);
        }

        focus_in_event.connect (() => {
            search_entry.grab_focus ();
            return Gdk.EVENT_PROPAGATE;
        });

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

        grid_view.app_launched.connect (() => { close_indicator (); });
        search_view.app_launched.connect (() => { close_indicator (); });

        view_selector.mode_changed.connect (() => {
            set_modality ((Modality) view_selector.selected);
        });

        app_system.changed.connect (() => {
            grid_view.populate (app_system);
            category_view.setup_sidebar ();
        });

        settings.changed["rows"].connect_after(() => { grid_view.populate (app_system); });
        settings.changed["columns"].connect_after(() => { grid_view.populate (app_system); });
        settings.changed["show-terminal-apps"].connect_after(() => {
            grid_view.populate (app_system);
            category_view.setup_sidebar ();
        });

        powerstrip.invoke_action.connect(() => { close_indicator (); });
        powerstrip.set_visible(settings.get_boolean("enable-powerstrip"));

        update_favorites_visibility ();
        settings.changed["enable-favorites"].connect (() => { update_favorites_visibility (); });

        content_grid.show_all();
    }

    private void dismiss_ctx_menu () {
        if (ctx_menu_widget != null) {
            content_overlay.remove (ctx_menu_widget);
            ctx_menu_widget = null;
        }
    }

    // Called when the user clicks anywhere outside the context menu
    private bool on_overlay_background_click (Gdk.EventButton ev) {
        if (ctx_menu_widget != null) {
            // Check if click was inside the menu widget bounds
            int mx, my, mw, mh;
            mx = ctx_menu_widget.margin_start;
            my = ctx_menu_widget.margin_top;
            mw = ctx_menu_widget.get_allocated_width ();
            mh = ctx_menu_widget.get_allocated_height ();
            if (ev.x < mx || ev.x > mx + mw || ev.y < my || ev.y > my + mh) {
                favorites_sidebar.close_context_menu ();
                dismiss_ctx_menu ();
                return Gdk.EVENT_STOP;
            }
        }
        return Gdk.EVENT_PROPAGATE;
    }

    public void panel_position_changed(Budgie.PanelPosition position) {
        if (position == Budgie.PanelPosition.BOTTOM) {
            container.margin_bottom = 12;
            container.margin_top = 0;

            container.remove_row(1);
            container.remove_row(0);

            container.attach (top, 0, 1);
            container.attach (content_overlay, 0, 0);
        }
        else {
            container.margin_bottom = 0;
            container.margin_top = 12;

            container.remove_row(1);
            container.remove_row(0);

            container.attach (top, 0, 0);
            container.attach (content_overlay, 0, 1);
        }
        content_grid.show_all();
    }

#if HAS_PLANK
    public void update_launcher_entry (string sender_name, GLib.Variant parameters, bool is_retry = false) {
        if (!is_retry) {
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

    private void update_favorites_visibility () {
        bool show_favorites = settings.get_boolean ("enable-favorites");

        if (favorites_sidebar != null) {
            favorites_sidebar.visible = show_favorites;
        }

        if (favorites_separator != null) {
            favorites_separator.visible = show_favorites;
        }
    }

    private void search_entry_activated () {
        if (modality == Modality.SEARCH_VIEW) {
            search_view.activate_selection ();
        }
    }

    public bool on_search_view_key_press (Gdk.EventKey event) {
        var key = Gdk.keyval_name (event.keyval).replace ("KP_", "");

        switch (key) {
            case "Down":
                search_entry.move_focus (Gtk.DirectionType.TAB_FORWARD);
                return Gdk.EVENT_STOP;

            case "Escape":
                // Context menu takes priority — close it first
                if (ctx_menu_widget != null) {
                    favorites_sidebar.close_context_menu ();
                    dismiss_ctx_menu ();
                    return Gdk.EVENT_STOP;
                }
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

        // Escape dismisses context menu first
        if (key == "Escape" && ctx_menu_widget != null) {
            favorites_sidebar.close_context_menu ();
            dismiss_ctx_menu ();
            return Gdk.EVENT_STOP;
        }

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
                    search_entry.grab_focus ();
                    return Gdk.EVENT_STOP;
            }
        }

        switch (key) {
            case "Down":
            case "Enter":
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
                }
                return Gdk.EVENT_PROPAGATE;
        }

        return Gdk.EVENT_STOP;
    }

    public void show_slingshot () {
        search_entry.text = "";
        search_entry.grab_focus ();
        view_selector_revealer.transition_type = Gtk.RevealerTransitionType.NONE;
        stack.transition_type = Gtk.StackTransitionType.NONE;
        set_modality ((Modality) view_selector.selected);
        view_selector_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        powerstrip.set_visible(settings.get_boolean("enable-powerstrip"));
        stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

        if (favorites_sidebar != null && settings.get_boolean ("enable-favorites")) {
            favorites_sidebar.validate_and_populate ();
        }
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
