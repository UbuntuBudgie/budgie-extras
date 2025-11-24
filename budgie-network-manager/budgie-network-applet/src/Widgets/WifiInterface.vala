/*
* Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/wingpanel-indicator-network)
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

public class Network.WifiInterface : Network.AbstractWifiInterface {
    public bool hidden_sensitivity { get; set; default = true; }
    Network.Widgets.Switch wifi_item;
    Gtk.Revealer revealer;

    Cancellable wifi_scan_cancellable = new Cancellable ();

    public WifiInterface (NM.Client nm_client, NM.Device? _device) {
        init_wifi_interface (nm_client, _device);

        wifi_item.caption = display_title;
        notify["display-title"].connect ( () => {
            wifi_item.caption = display_title;
        });

        wifi_item.notify["active"].connect (() => {
            var active = wifi_item.active;
            if (active != !software_locked) {
                rfkill.set_software_lock (RFKillDeviceType.WLAN, !active);
                nm_client.wireless_set_enabled (active);
            }
        });
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        wifi_item = new Network.Widgets.Switch ("");
        wifi_item.get_style_context ().add_class ("h4");
        pack_start (wifi_item);

        var scrolled_box = new Gtk.ScrolledWindow (null, null);
        scrolled_box.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_box.max_content_height = 512;
        scrolled_box.propagate_natural_height = true;
        scrolled_box.add (wifi_list);

        revealer = new Gtk.Revealer ();
        revealer.add (scrolled_box);
        pack_start (revealer);
    }

    public override void update () {
        base.update ();

        wifi_item.sensitive = !hardware_locked;
        wifi_item.active = !locked;

        active_ap = wifi_device.get_active_access_point ();

        if (wifi_device.state == NM.DeviceState.UNAVAILABLE || state == Network.State.FAILED_WIFI) {
            revealer.reveal_child = false;
            hidden_sensitivity = false;
        } else {
            revealer.reveal_child = true;
            hidden_sensitivity = true;
        }
    }

    protected override void wifi_activate_cb (WifiMenuItem i) {
        var connections = nm_client.get_connections ();
        var device_connections = wifi_device.filter_connections (connections);
        var ap = i.get_nearest_ap ();
        var ap_connections = ap.filter_connections (device_connections);

        bool already_connected = ap_connections.length > 0;

        if (already_connected) {
            nm_client.activate_connection_async.begin (ap_connections.get (0),
                                                       wifi_device,
                                                       ap.get_path (),
                                                       null,
                                                       null);
        } else {
            debug ("Trying to connect to %s", NM.Utils.ssid_to_utf8 (ap.ssid.get_data ()));

            if (ap.wpa_flags == NM.@80211ApSecurityFlags.NONE) {
                debug ("Directly, as it is an insecure network.");
                nm_client.add_and_activate_connection_async.begin (NM.SimpleConnection.new (),
                                                                   device,
                                                                   ap.get_path (),
                                                                   null,
                                                                   null);
            } else {
                debug ("Needs a password or a certificate, let's open switchboard.");
                need_settings ();
            }
        }

        /* Do an update at the next iteration of the main loop, so as every
         * signal is flushed (for instance signals responsible for radio button
         * checked) */
        Idle.add (() => { update (); return false; });
    }

    public void start_scanning () {
        wifi_scan_cancellable.reset ();
        wifi_device.request_scan_async.begin (wifi_scan_cancellable, null);
    }

    public void cancel_scanning () {
        wifi_scan_cancellable.cancel ();
    }
}
