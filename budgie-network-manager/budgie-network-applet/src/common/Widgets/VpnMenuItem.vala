/*
 * Copyright (c) 2017-2018 elementary LLC (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Network.VpnMenuItem : Gtk.ListBoxRow {
    private static unowned Gtk.RadioButton? blank_button = null;

    private bool checking_vpn_connectivity = false;

    public signal void user_action ();
    public NM.RemoteConnection? connection { get; private set; }
    public string id {
        get {
            return connection.get_id ();
        }
    }
    public Network.State vpn_state { get; set; default = Network.State.DISCONNECTED; }

    public Gtk.RadioButton radio_button { get; private set; }
    Gtk.Spinner spinner;
    Gtk.Image error_img;

    public VpnMenuItem (NM.RemoteConnection? _connection) {
        connection = _connection;
        connection.changed.connect (update);

        var main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        main_box.margin_start = main_box.margin_end = 6;

        radio_button = new Gtk.RadioButton (null);
        if (blank_button != null) {
            radio_button.join_group (blank_button);
        }

        radio_button.button_release_event.connect ((b, ev) => {
            user_action ();
            return false;
        });

        error_img = new Gtk.Image.from_icon_name ("process-error-symbolic", Gtk.IconSize.MENU);
        error_img.margin_start = 6;
        error_img.set_tooltip_text (_("This Virtual Private Network could not be connected to."));

        spinner = new Gtk.Spinner ();
        spinner.start ();
        spinner.visible = false;
        spinner.no_show_all = !spinner.visible;

        main_box.pack_start (radio_button, true, true);
        main_box.pack_start (spinner, false, false);
        main_box.pack_start (error_img, false, false);

        notify["vpn_state"].connect (update);
        radio_button.notify["active"].connect (update);

        add (main_box);
        get_style_context ().add_class ("menuitem");

        update ();
    }

    /**
    * Only used for an item which is not displayed: hacky way to have no radio button selected.
    **/
    public VpnMenuItem.blank () {
        radio_button = new Gtk.RadioButton (null);
        blank_button = radio_button;
    }

    private void update () {
        radio_button.label = connection.get_id ();
        hide_item (error_img);
        hide_item (spinner);

        switch (vpn_state) {
            case State.FAILED_VPN:
                show_item (error_img);
                break;
            case State.CONNECTING_VPN:
                show_item (spinner);
                if (!radio_button.active) {
                    critical ("An VPN is being connected but not active.");
                }
                check_vpn_connectivity ();
                break;
        }
    }

    public void set_active (bool active) {
        radio_button.set_active (active);
    }

    void show_item (Gtk.Widget w) {
        w.visible = true;
        w.no_show_all = w.visible;
    }

    void hide_item (Gtk.Widget w) {
        w.visible = false;
        w.no_show_all = !w.visible;
        w.hide ();
    }

    private async void nap (uint interval, int priority = GLib.Priority.DEFAULT) {
      GLib.Timeout.add (interval, () => {
          nap.callback ();
          return false;
        }, priority);
        yield;
    }

    /**
    * Uses a timeout to check VPN connectivity
    **/
    private async void check_vpn_connectivity () {
        if (!checking_vpn_connectivity) {

            checking_vpn_connectivity = true;

            for (int i = 0; i < 20; i++) {
                if (vpn_state == State.CONNECTED_VPN) {
                    hide_item (spinner);
                    checking_vpn_connectivity = false;
                    return;
                }
                yield nap (500);
            }
        }
    }
}
