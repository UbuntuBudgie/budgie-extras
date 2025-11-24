/*
 * Copyright 2019-2020 elementary, Inc. (https://elementary.io)
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

public class Slingshot.Widgets.CategoryView : Gtk.EventBox {
    public signal void search_focus_request ();

    public SlingshotView view { get; construct; }

    private bool dragging = false;
    private string? drag_uri = null;
    private NavListBox category_switcher;
    private NavListBox listbox;
    private bool rollover_menus=false;

    private static GLib.Settings settings = null;

    static construct {
        settings = new GLib.Settings ("org.ubuntubudgie.plugins.budgie-appmenu");
    }

    private const Gtk.TargetEntry DND = { "text/uri-list", 0, 0 };

    public CategoryView (SlingshotView view) {
        Object (view: view);
    }

    construct {
        set_visible_window (false);
        hexpand = true;

        define_css_styles();

        category_switcher = new NavListBox ();
        category_switcher.selection_mode = Gtk.SelectionMode.BROWSE;
        category_switcher.set_sort_func ((Gtk.ListBoxSortFunc) category_sort_func);
        category_switcher.width_request = 120;

        var scrolled_category = new Gtk.ScrolledWindow (null, null);
        scrolled_category.get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        scrolled_category.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolled_category.add (category_switcher);

        var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);

        listbox = new NavListBox ();
        listbox.expand = true;
        listbox.selection_mode = Gtk.SelectionMode.BROWSE;
        listbox.set_filter_func ((Gtk.ListBoxFilterFunc) filter_function);

        var listbox_scrolled = new Gtk.ScrolledWindow (null, null);
        listbox_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        listbox_scrolled.add (listbox);

        var container = new Gtk.Grid ();
        container.hexpand = true;
        container.add (scrolled_category);
        container.add (separator);
        container.add (listbox_scrolled);

        add (container);

        category_switcher.row_selected.connect (() => {
            listbox.invalidate_filter ();
        });

        category_switcher.search_focus_request.connect (() => {
            search_focus_request ();
        });

        listbox.row_activated.connect ((row) => {
            Idle.add (() => {
                if (!dragging) {
                    ((AppListRow) row).launch ();
                    view.close_indicator ();
                }

                return false;
            });
        });

        listbox.button_press_event.connect ((event) => {
            if (event.button == Gdk.BUTTON_SECONDARY) {
                return create_context_menu (event);
            }

            return Gdk.EVENT_PROPAGATE;
        });

        listbox.key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Menu) {
                return create_context_menu (event);
            }

            return Gdk.EVENT_PROPAGATE;
        });

        listbox.key_press_event.connect (on_key_press);
        category_switcher.key_press_event.connect (on_key_press);

        Gtk.drag_source_set (listbox, Gdk.ModifierType.BUTTON1_MASK, {DND}, Gdk.DragAction.COPY);

        listbox.motion_notify_event.connect ((event) => {
            if (!dragging) {
                listbox.select_row (listbox.get_row_at_y ((int) event.y));
            }

            return Gdk.EVENT_PROPAGATE;
        });

        listbox.drag_begin.connect ((ctx) => {
            unowned Gtk.ListBoxRow? selected_row = listbox.get_selected_row ();
            if (selected_row != null) {
                dragging = true;

                var drag_item = (AppListRow) selected_row;
                drag_uri = "file://" + drag_item.desktop_path;
                if (drag_uri != null) {
                    Gtk.drag_set_icon_gicon (ctx, drag_item.app_info.get_icon (), 16, 16);
                }

                //view.close_indicator ();
            }
        });

        listbox.drag_end.connect (() => {
            if (drag_uri != null) {
                view.close_indicator ();
            }

            dragging = false;
            drag_uri = null;
        });

        listbox.drag_data_get.connect ((ctx, sel, info, time) => {
            if (drag_uri != null) {
                sel.set_uris ({drag_uri});
            }
        });

        listbox.search_focus_request.connect (() => {
            search_focus_request ();
        });

        setup_sidebar ();

        rollover_menus = settings.get_boolean("rollover-menu");
        settings.changed["rollover-menu"].connect_after(() => {
            rollover_menus = settings.get_boolean("rollover-menu");
        });

        settings.changed["category-spacing"].connect(() => {
            setup_sidebar ();
        });
    }

    private void define_css_styles() {
        var css_builder = new StringBuilder ();
        for (int spacing = -15; spacing <= 15; ++spacing) {
            int bottom = spacing / 2;
            int top = spacing - bottom;

            css_builder.append_printf ("""
                .budgie_application_menu_category_row_%d {
                    margin: %dpx 3px %dpx 3px;
                }
                """, spacing, top, bottom);
        }

        Gdk.Screen screen = this.get_screen ();
        Gtk.CssProvider css_provider = new Gtk.CssProvider ();
        try {
            css_provider.load_from_data (css_builder.str);
            Gtk.StyleContext.add_provider_for_screen (
                screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        }
        catch (Error e) {
            message("Could not load css %s", e.message);
        }
    }

    private static int category_sort_func (CategoryRow row1, CategoryRow row2) {
        return row1.translated_name.collate (row2.translated_name);
    }

    private bool create_context_menu (Gdk.Event event) {
        var selected_row = (AppListRow) listbox.get_selected_row ();

        var menu = new Slingshot.AppContextMenu (selected_row.app_id, selected_row.desktop_path);
        menu.app_launched.connect (() => {
            view.close_indicator ();
        });

        if (menu.get_children () != null) {
            if (event.type == Gdk.EventType.KEY_PRESS) {
                menu.popup_at_widget (selected_row, Gdk.Gravity.CENTER, Gdk.Gravity.CENTER, event);
                return Gdk.EVENT_STOP;
            } else if (event.type == Gdk.EventType.BUTTON_PRESS) {
                menu.popup_at_pointer (event);
                return Gdk.EVENT_STOP;
            }
        }

        return Gdk.EVENT_PROPAGATE;
    }

    public void page_down () {
        category_switcher.move_cursor (Gtk.MovementStep.DISPLAY_LINES, 1);
        focus_select_first_row ();
    }

    public void page_up () {
        category_switcher.move_cursor (Gtk.MovementStep.DISPLAY_LINES, -1);
        focus_select_first_row ();
    }

    private void focus_select_first_row () {
        unowned Gtk.ListBoxRow? first_row = listbox.get_row_at_index (0);
        if (first_row != null) {
            first_row.grab_focus ();
            listbox.select_row (first_row);
        }
    }

    /**
     * Permits "rolling" over categories
     */
    private bool on_mouse_enter(Gtk.Widget source_widget, Gdk.EventCrossing e)
    {
        if (!this.rollover_menus) {
            return Gdk.EVENT_PROPAGATE;
        }
        /* If it's not valid, don't use it. */
        Gtk.EventBox? b = source_widget as Gtk.EventBox;
        if (b==null) {
            return Gdk.EVENT_PROPAGATE;
        }

        /* Activate the source_widget category */
        category_switcher.select_row(b.get_parent() as CategoryRow);
        return Gdk.EVENT_PROPAGATE;
    }

    public void setup_sidebar () {
        CategoryRow? old_selected = (CategoryRow) category_switcher.get_selected_row ();
        foreach (unowned Gtk.Widget child in category_switcher.get_children ()) {
            child.destroy ();
            SignalHandler.disconnect_by_func(child, (void*)on_mouse_enter, this);
        }

        listbox.foreach ((app_list_row) => listbox.remove (app_list_row));

        foreach (unowned Backend.App app in view.app_system.get_apps_by_name ()) {
            listbox.add (new AppListRow (app.desktop_id, app.desktop_path));
        }
        listbox.show_all ();

        // Fill the sidebar
        int category_spacing = settings.get_int ("category-spacing");

        unowned Gtk.ListBoxRow? new_selected = null;
        foreach (string cat_name in view.app_system.apps.keys) {
            if (cat_name == "switchboard") {
                continue;
            }

            var row = new CategoryRow (cat_name, category_spacing);
            row.eventbox.enter_notify_event.connect(this.on_mouse_enter);
            category_switcher.add (row);
            if (old_selected != null && old_selected.cat_name == cat_name) {
                new_selected = row;
            }
        }

        category_switcher.show_all ();
        category_switcher.select_row (new_selected ?? category_switcher.get_row_at_index (0));
    }

    [CCode (instance_pos = -1)]
    private bool filter_function (AppListRow row) {
        unowned CategoryRow category_row = (CategoryRow) category_switcher.get_selected_row ();
        if (category_row != null) {
            foreach (Backend.App app in view.app_system.apps[category_row.cat_name]) {
                if (row.app_id == app.desktop_id && !(app.terminal && !settings.get_boolean("show-terminal-apps"))) {
                    return true;
                }
            }
        }

        return false;
    }

    private bool on_key_press (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.Page_Up:
            case Gdk.Key.KP_Page_Up:
                page_up ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.Page_Down:
            case Gdk.Key.KP_Page_Down:
                page_down ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.Home:
                category_switcher.move_cursor (Gtk.MovementStep.PAGES, -1);
                focus_select_first_row ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.End:
                category_switcher.move_cursor (Gtk.MovementStep.PAGES, 1);
                focus_select_first_row ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.KP_Up:
            case Gdk.Key.Up:
                if (event.state == Gdk.ModifierType.SHIFT_MASK) {
                    page_up ();
                    return Gdk.EVENT_STOP;
                }

                break;
            case Gdk.Key.KP_Down:
            case Gdk.Key.Down:
                if (event.state == Gdk.ModifierType.SHIFT_MASK) {
                    page_down ();
                    return Gdk.EVENT_STOP;
                }
                break;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private class CategoryRow : Gtk.ListBoxRow {
        public string cat_name { get; construct; }
        public int cat_margin { get; construct; }
        public Gtk.EventBox eventbox;
        public string translated_name {
            get {
                return GLib.dgettext ("gnome-menus-3.0", cat_name);
            }
        }

        public CategoryRow (string cat_name, int cat_margin) {
            Object (cat_name: cat_name, cat_margin: cat_margin);
        }

        construct {
            var label = new Gtk.Label (translated_name);
            label.halign = Gtk.Align.START;
            label.margin = 0;
            label.get_style_context().add_class("budgie_application_menu_category_row_%d".printf(this.cat_margin));

            eventbox = new Gtk.EventBox();
            eventbox.add(label);
            eventbox.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);

            this.add (eventbox);
        }
    }

    private class NavListBox : Gtk.ListBox {
        public signal void search_focus_request ();

        public override void move_cursor (Gtk.MovementStep step, int count) {
            unowned Gtk.ListBoxRow selected = get_selected_row ();
            if (
                selected != null &&
                selected == get_row_at_index (0) &&
                step == DISPLAY_LINES &&
                count == -1
            ) {
                search_focus_request ();
            } else {
                base.move_cursor (step, count);
            }
        }
    }
}
