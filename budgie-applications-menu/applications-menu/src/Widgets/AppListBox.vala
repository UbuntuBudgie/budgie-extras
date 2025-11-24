/*
 * Copyright 2011-2019 elementary, Inc. (https://elementary.io)
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
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Giulio Collura
 */

public class Slingshot.AppListBox : Gtk.ListBox {
    public signal void close_request ();

    public bool dragging { get; private set; default = false; }

    private string? drag_uri = null;

    construct {
        selection_mode = Gtk.SelectionMode.BROWSE;

        const Gtk.TargetEntry DND = {"text/uri-list", 0, 0};
        Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {DND}, Gdk.DragAction.COPY);

        motion_notify_event.connect ((event) => {
            if (!dragging) {
                select_row (get_row_at_y ((int) event.y));
            }

            return Gdk.EVENT_PROPAGATE;
        });

        drag_begin.connect ((ctx) => {
            var selected_row = get_selected_row ();
            if (selected_row != null) {
                dragging = true;

                var drag_item = (Slingshot.Widgets.SearchItem) selected_row;
                drag_uri = drag_item.app_uri;
                if (drag_uri != null) {
                    Gtk.drag_set_icon_gicon (ctx, drag_item.icon.gicon, 16, 16);
                }

                //close_request ();
            }
        });

        drag_end.connect (() => {
            if (drag_uri != null) {
                close_request ();
            }

            dragging = false;
            drag_uri = null;
        });

        drag_data_get.connect ((ctx, sel, info, time) => {
            if (drag_uri != null) {
                sel.set_uris ({drag_uri});
            }
        });
    }

    public override void move_cursor (Gtk.MovementStep step, int count) {
        unowned Gtk.ListBoxRow selected = get_selected_row ();

        if (step != Gtk.MovementStep.DISPLAY_LINES || selected == null) {
            base.move_cursor (step, count);
            return;
        }

        uint n_children = get_children ().length ();

        int current = selected.get_index ();
        int target = current + count;

        if (target < 0) {
            target = (int) n_children + count;
        } else if (target >= n_children) {
            target = count - 1;
        }

        unowned Gtk.ListBoxRow? target_row = get_row_at_index (target);
        if (target_row != null) {
            select_row (target_row);
            target_row.grab_focus ();
        }
    }
}
