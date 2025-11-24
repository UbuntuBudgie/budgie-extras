/*
 * Copyright (c) 2015-2018 elementary LLC (https://elementary.io)
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

public class Network.WifiMenuItem : Gtk.ListBoxRow {
    public signal void user_action ();
    public Network.State state { get; set; default = Network.State.DISCONNECTED; }
    public GLib.Bytes ssid { get; construct; }
    public uint8 strength { get; private set; default = 0; }

    private Gee.LinkedList<NM.AccessPoint> all_aps;

    Gtk.RadioButton radio_button;
    Gtk.Image img_strength;
    Gtk.Image lock_img;
    Gtk.Image error_img;
    Gtk.Spinner spinner;
    uint refresh_source = 0;

    construct {
        all_aps = new Gee.LinkedList<NM.AccessPoint> ();
        get_style_context ().add_class ("menuitem");

        radio_button = new Gtk.RadioButton (null);
        radio_button.hexpand = true;
        radio_button.margin_start = 6;

        img_strength = new Gtk.Image ();
        img_strength.icon_size = Gtk.IconSize.MENU;
        img_strength.margin_end = 6;

        lock_img = new Gtk.Image.from_icon_name ("channel-insecure-symbolic", Gtk.IconSize.MENU);

        /* TODO: investigate this, it has not been tested yet. */
        error_img = new Gtk.Image.from_icon_name ("process-error-symbolic", Gtk.IconSize.MENU);
        error_img.tooltip_text = _("This wireless network could not be connected to.");

        spinner = new Gtk.Spinner();
        spinner.start ();
        spinner.visible = false;
        spinner.no_show_all = true;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 6;
        grid.add (radio_button);
        grid.add (spinner);
        grid.add (error_img);
        grid.add (lock_img);
        grid.add (img_strength);

        add (grid);

        notify["state"].connect (update);
        radio_button.notify["active"].connect (update);
        button_release_event.connect (() => { activate (); });
        activate.connect (() => {
            user_action ();
        });

        map.connect (() => start_refresh ());
        unmap.connect (() => stop_refresh ());
    }

    public WifiMenuItem (NM.AccessPoint ap, WifiMenuItem? previous = null) {
        Object (ssid: ap.ssid, margin_top: 3);
        add_ap (ap);

        if (previous != null) {
            radio_button.set_group (previous.radio_button.get_group ());
        }
        
        show_all ();
    }

    /**
     * Only used for an item which is not displayed: hacky way to have no radio button selected.
     **/
    public WifiMenuItem.blank () {
        get_child ().destroy ();
    }

    public void set_active (bool active) {
        radio_button.active = active;
    }

    public void add_ap (NM.AccessPoint ap) {
        lock (all_aps) {
            all_aps.add (ap);
        }

        update ();
    }

    public bool remove_ap (NM.AccessPoint ap) {
        lock (all_aps) {
            all_aps.remove (ap);
            return !all_aps.is_empty;
        }
    }

    public NM.AccessPoint get_nearest_ap () {
        lock (all_aps) {
            NM.AccessPoint ap = all_aps.first ();
            foreach (var iter_ap in all_aps) {
                if (ap.strength < iter_ap.strength) {
                    ap = iter_ap;
                }
            }

            return ap;
        }
    }

    private void start_refresh () {
        lock (refresh_source) {
            if (refresh_source > 0) {
                GLib.Source.remove (refresh_source);
            }

            refresh_source = GLib.Timeout.add_seconds (5, () => {
                update ();
                return GLib.Source.CONTINUE;
            });
        }
    }

    private void stop_refresh () {
        lock (refresh_source) {
            GLib.Source.remove (refresh_source);
            refresh_source = 0;
        }
    }

    private void update () {
        radio_button.label = NM.Utils.ssid_to_utf8 (ssid.get_data ());

        NM.AccessPoint ap = null;
        lock (all_aps) {
            ap = all_aps.first ();
        }

        NM.@80211ApSecurityFlags flags = ap.wpa_flags;
        var is_secured = false;

        if (NM.@80211ApSecurityFlags.GROUP_WEP40 in flags) {
            is_secured = true;
            tooltip_text = _("This network uses 40/64-bit WEP encryption");
        } else if (NM.@80211ApSecurityFlags.GROUP_WEP104 in flags) {
            is_secured = true;
            tooltip_text = _("This network uses 104/128-bit WEP encryption");
        } else if (NM.@80211ApSecurityFlags.KEY_MGMT_PSK in flags)  {
            is_secured = true;
            tooltip_text = _("This network uses WPA encryption");
        } else if (flags != NM.@80211ApSecurityFlags.NONE || ap.rsn_flags != NM.@80211ApSecurityFlags.NONE) {
            is_secured = true;
            tooltip_text = _("This network uses encryption");
        } else {
            tooltip_text = _("This network is unsecured");
        }

        lock_img.visible = !is_secured;
        lock_img.no_show_all = !lock_img.visible;

        hide_item (error_img);
        hide_item (spinner);

        switch (state) {
            case State.FAILED_WIFI:
                show_item (error_img);
                break;
            case State.CONNECTING_WIFI:
                show_item (spinner);
                if (!radio_button.active) {
                    critical ("An access point is being connected but not active.");
                }
                break;
        }

        // Recalculate global strength
        uint8 next_strength = 0;
        lock (all_aps) {
            foreach (var iter_ap in all_aps) {
                next_strength = uint8.max (next_strength, iter_ap.strength);
            }
        }

        strength = next_strength;
        img_strength.icon_name = get_strength_symbolic_icon ();
    }

    private void show_item (Gtk.Widget w) {
        w.visible = true;
        w.no_show_all = !w.visible;
    }

    private void hide_item (Gtk.Widget w) {
        w.visible = false;
        w.no_show_all = !w.visible;
        w.hide ();
    }

    const string BASE_ICON_NAME = "network-wireless-signal-";
    const string SYMBOLIC = "-symbolic";
    private unowned string get_strength_symbolic_icon () {
        if (strength < 30) {
            return BASE_ICON_NAME + "weak" + SYMBOLIC;
        } else if (strength < 55) {
            return BASE_ICON_NAME + "ok" + SYMBOLIC;
        } else if (strength < 80) {
            return BASE_ICON_NAME + "good" + SYMBOLIC;
        } else {
            return BASE_ICON_NAME + "excellent" + SYMBOLIC;
        }
    }
}
