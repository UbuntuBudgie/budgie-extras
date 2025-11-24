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

public abstract class Network.Widgets.NMVisualizer : Gtk.Grid {
    protected NM.Client nm_client;
    protected NM.VpnConnection? active_vpn_connection = null;

    protected GLib.List<WidgetNMInterface>? network_interface;

    public bool secure { private set; get; default = false; }
    public string? extra_info { protected set; get; default = null; }
    public Network.State state { private set; get; default = Network.State.CONNECTING_WIRED; }

    construct {
        network_interface = new GLib.List<WidgetNMInterface> ();

        build_ui ();

        /* Monitor network manager */
        try {
            nm_client = new NM.Client ();
        } catch (Error e) {
            critical (e.message);
        }

        nm_client.notify["active-connections"].connect (update_vpn_connection);

        nm_client.device_added.connect (device_added_cb);
        nm_client.device_removed.connect (device_removed_cb);

        nm_client.notify["networking-enabled"].connect (update_state);

        var devices = nm_client.get_devices ();
        for (var i = 0; i < devices.length; i++)
            device_added_cb (devices.get (i));

        // Vpn interface
        create_vpn_interface ();

        show_all ();
        update_vpn_connection ();
    }

    protected abstract void build_ui ();
    protected abstract void add_interface (WidgetNMInterface widget_interface);
    protected abstract void remove_interface (WidgetNMInterface widget_interface);

    void device_removed_cb (NM.Device device) {
        foreach (var widget_interface in network_interface) {
            if (widget_interface.is_device (device)) {
                network_interface.remove (widget_interface);

                // Implementation call
                remove_interface (widget_interface);
                break;
            }
        }

        update_interfaces_names ();
        update_state ();
    }

    void update_interfaces_names () {
        var count_type = new Gee.HashMap<string, int?> ();
        foreach (var iface in network_interface) {
            var type = iface.get_type ().name ();
            if (count_type.has_key (type)) {
                count_type[type] = count_type[type] + 1;
            } else {
                count_type[type] = 1;
            }
        }

        foreach (var iface in network_interface) {
            var type = iface.get_type ().name ();
            iface.update_name (count_type [type]);
        }
    }

    private void device_added_cb (NM.Device device) {
        if (device.get_iface ().has_prefix ("vmnet") ||
            device.get_iface ().has_prefix ("lo") ||
            device.get_iface ().has_prefix ("veth") ||
            device.get_iface ().has_prefix ("vboxnet")) {
            return;
        }

        WidgetNMInterface? widget_interface = null;

        if (device is NM.DeviceWifi) {
            widget_interface = new WifiInterface (nm_client, device);
            debug ("Wifi interface added");
        } else if (device is NM.DeviceEthernet) {
            widget_interface = new EtherInterface (nm_client, device);
            debug ("Wired interface added");
        } else if (device is NM.DeviceModem) {
            widget_interface = new ModemInterface (nm_client, device);
            debug ("Modem interface added");
        } else if (device is NM.DeviceBt) {
            widget_interface = new BluetoothInterface (nm_client, device);
            debug ("Bluetooth interface added");
        } else {
            debug ("Unknown device: %s\n", device.get_device_type ().to_string ());
        }

        if (widget_interface != null) {
            // Implementation call
            network_interface.append (widget_interface);
            add_interface (widget_interface);
            widget_interface.notify["state"].connect (update_state);
            widget_interface.notify["extra-info"].connect (update_state);

        }

        update_interfaces_names ();
        update_all ();
        update_state ();
        show_all ();
    }

    private void create_vpn_interface () {
        WidgetNMInterface widget_interface = new VpnInterface (nm_client);
        network_interface.append (widget_interface);
        add_interface (widget_interface);
        widget_interface.notify["state"].connect (update_state);
    }

    void update_all () {
        foreach (var inter in network_interface) {
            inter.update ();
        }
    }

    void update_state () {
        if (!nm_client.networking_get_enabled ()) {
            state = Network.State.DISCONNECTED_AIRPLANE_MODE;
        } else {
            var next_state = Network.State.DISCONNECTED;
            var best_score = int.MAX;

            foreach (var inter in network_interface) {
                var score = inter.state.get_priority ();

                if (score < best_score) {
                    next_state = inter.state;
                    best_score = score;
                    extra_info = inter.extra_info;
                }
            }

            state = next_state;
        }
    }

    void update_vpn_connection () {
        active_vpn_connection = null;

        nm_client.get_active_connections ().foreach ((ac) => {
            if (active_vpn_connection == null && ac.get_vpn ()) {
                active_vpn_connection = (NM.VpnConnection)ac;
                update_vpn_state (active_vpn_connection.get_vpn_state ());
                active_vpn_connection.vpn_state_changed.connect (() => {
                    update_vpn_state (active_vpn_connection.get_vpn_state ());
                });
            }
        });
    }

    void update_vpn_state (NM.VpnConnectionState state) {
        switch (state) {
            case NM.VpnConnectionState.DISCONNECTED:
            case NM.VpnConnectionState.PREPARE:
            case NM.VpnConnectionState.IP_CONFIG_GET:
            case NM.VpnConnectionState.CONNECT:
            case NM.VpnConnectionState.FAILED:
                secure = false;
                break;
            case NM.VpnConnectionState.ACTIVATED:
                secure = true;
                break;
        }
    }
}
