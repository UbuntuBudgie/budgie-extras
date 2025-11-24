/*
* Copyright (c) 2015-2016 elementary LLC (http://launchpad.net/wingpanel-indicator-network)
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
*
*/

public class Network.Widgets.DisplayWidget : Gtk.Box {
    private OverlayIcon icon;
    private Gtk.Label extra_info_label;
    private Gtk.Revealer extra_info_revealer;

    uint wifi_animation_timeout;
    int wifi_animation_state = 0;
    uint cellular_animation_timeout;
    int cellular_animation_state = 0;

    public DisplayWidget () {
        Object (orientation: Gtk.Orientation.HORIZONTAL,
            halign: Gtk.Align.CENTER,
            valign: Gtk.Align.CENTER);
    }

    construct {
        icon = new OverlayIcon ("network-wired-symbolic");

        extra_info_label = new Gtk.Label (null);
        extra_info_label.margin_start = 4;
        extra_info_label.valign = Gtk.Align.CENTER;
        extra_info_label.vexpand = false;

        extra_info_revealer = new Gtk.Revealer ();
        extra_info_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        extra_info_revealer.add (extra_info_label);

        pack_start (icon);
        pack_start (extra_info_revealer);
    }

    public void update_state (Network.State state, bool secure, string? extra_info = null) {
        extra_info_revealer.reveal_child = extra_info != null;
        extra_info_label.label = extra_info;

        if (wifi_animation_timeout > 0) {
            Source.remove (wifi_animation_timeout);
            wifi_animation_timeout = 0;
        }

        if (cellular_animation_timeout > 0) {
            Source.remove (cellular_animation_timeout);
            cellular_animation_timeout = 0;
        }

        switch (state) {
        case Network.State.DISCONNECTED_AIRPLANE_MODE:
            icon.set_name("airplane-mode-symbolic");
            break;
        case Network.State.CONNECTING_WIRED:
            icon.set_name("network-wired-acquiring-symbolic");
            break;
        case Network.State.CONNECTED_WIRED:
            icon.set_name("network-wired-symbolic", secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTED_WIFI:
            icon.set_name ("network-wireless-connected-symbolic");
            break;
        case Network.State.CONNECTED_WIFI_WEAK:
            icon.set_name ("network-wireless-signal-weak-symbolic", secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTED_WIFI_OK:
            icon.set_name ("network-wireless-signal-ok-symbolic", secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTED_WIFI_GOOD:
            icon.set_name("network-wireless-signal-good-symbolic",secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTED_WIFI_EXCELLENT:
            icon.set_name("network-wireless-signal-excellent-symbolic", secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTING_WIFI:
            wifi_animation_timeout = Timeout.add (300, () => {
                wifi_animation_state = (wifi_animation_state + 1) % 4;
                string strength = "";
                switch (wifi_animation_state) {
                case 0:
                    strength = "weak";
                    break;
                case 1:
                    strength = "ok";
                    break;
                case 2:
                    strength = "good";
                    break;
                case 3:
                    strength = "excellent";
                    break;
                }
                icon.set_name("network-wireless-signal-" + strength + "-symbolic",secure ? "nm-vpn-lock" : "");
                return true;
            });
            break;
        case Network.State.CONNECTED_MOBILE_WEAK:
            icon.set_name ("network-cellular-signal-weak-symbolic",secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTED_MOBILE_OK:
            icon.set_name ("network-cellular-signal-ok-symbolic",secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTED_MOBILE_GOOD:
            icon.set_name ("network-cellular-signal-good-symbolic",secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTED_MOBILE_EXCELLENT:
            icon.set_name ("network-cellular-signal-excellent-symbolic",secure ? "nm-vpn-lock" : "");
            break;
        case Network.State.CONNECTING_MOBILE:
            cellular_animation_timeout = Timeout.add (300, () => {
                cellular_animation_state = (cellular_animation_state + 1) % 4;
                string strength = "";
                switch (cellular_animation_state) {
                case 0:
                    strength = "weak";
                    break;
                case 1:
                    strength = "ok";
                    break;
                case 2:
                    strength = "good";
                    break;
                case 3:
                    strength = "excellent";
                    break;
                }

                icon.set_name ("network-cellular-signal-" + strength + "-symbolic", secure ? "nm-vpn-lock" : "");
                return true;
            });
            break;
        case Network.State.FAILED_MOBILE:
            icon.set_name ("network-cellular-offline-symbolic");
            break;
        case Network.State.FAILED_WIFI:
        case Network.State.DISCONNECTED:
            icon.set_name ("network-wireless-offline-symbolic");
            break;
        case Network.State.WIRED_UNPLUGGED:
            icon.set_name ("network-wired-offline-symbolic");
            break;
        default:
            icon.set_name ("network-offline-symbolic");
            critical ("Unknown network state, cannot show the good icon: %s", state.to_string ());
            break;
        }
    }
}
