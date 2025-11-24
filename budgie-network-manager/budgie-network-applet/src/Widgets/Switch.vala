
/*
 * Copyright (c) 2018-2020 Daniel Pinto (https://github.com/danielpinto8zz6/budgie-network-applet)
 * Copyright (c) 2011-2018 elementary, Inc. (https://elementary.io)
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
 */

 public class Network.Widgets.Switch : Gtk.Box {
    public bool active { get; set; }
    public string caption { owned get; set; }

    private Gtk.Label button_label;
    private Gtk.Switch button_switch;

    public Switch (string caption) {
        Object (caption: caption,
                orientation: Gtk.Orientation.HORIZONTAL,
                hexpand: true);

        button_label = new Gtk.Label (null);
        button_label.halign = Gtk.Align.START;
        button_label.margin_start = 6;
        button_label.margin_end = 10;

        button_switch = new Gtk.Switch ();
        button_switch.active = active;
        button_switch.halign = Gtk.Align.END;
        button_switch.hexpand = true;

        add (button_label);
        add (button_switch);

        bind_property ("active", button_switch, "active", GLib.BindingFlags.SYNC_CREATE|GLib.BindingFlags.BIDIRECTIONAL);
        bind_property ("caption", button_label, "label", GLib.BindingFlags.SYNC_CREATE|GLib.BindingFlags.BIDIRECTIONAL);
    }
}