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

public class Network.EtherInterface : Network.AbstractEtherInterface {
    private Network.Widgets.Switch ethernet_item;

    public EtherInterface (NM.Client nm_client, NM.Device? _device) {
        device = _device;
        ethernet_item = new Network.Widgets.Switch (display_title);

        notify["display-title"].connect (() => {
            ethernet_item.caption = display_title;
        });

        ethernet_item.get_style_context ().add_class ("h4");
        ethernet_item.notify["active"].connect (() => {
            debug ("update");
            if (ethernet_item.active && device.get_state () == NM.DeviceState.DISCONNECTED) {
                var connection = NM.SimpleConnection.new ();
                var remote_array = device.get_available_connections ();
                if (remote_array == null) {
                    critical ("Unable to find an ethernet connection to activate");
                } else {
                    connection.set_path (remote_array.get (0).get_path ());
                    nm_client.activate_connection_async.begin (connection, device, null, null, null);
                }
            } else if (!ethernet_item.active && device.get_state () == NM.DeviceState.ACTIVATED) {
                device.disconnect_async.begin (null, () => { debug ("Successfully disconnected."); });
            }
        });

        add (ethernet_item);

        device.state_changed.connect (() => { update (); });
    }

    public override void update () {
        switch (device.get_state ()) {
        case NM.DeviceState.UNKNOWN:
        case NM.DeviceState.UNMANAGED:
        case NM.DeviceState.DEACTIVATING:
        case NM.DeviceState.FAILED:
            ethernet_item.sensitive = false;
            ethernet_item.active = false;
            state = State.FAILED_WIRED;
            break;

        case NM.DeviceState.UNAVAILABLE:
            ethernet_item.sensitive = false;
            ethernet_item.active = false;
            state = State.WIRED_UNPLUGGED;
            break;
        case NM.DeviceState.DISCONNECTED:
            ethernet_item.sensitive = true;
            ethernet_item.active = false;
            state = State.WIRED_UNPLUGGED;
            break;

        case NM.DeviceState.PREPARE:
        case NM.DeviceState.CONFIG:
        case NM.DeviceState.NEED_AUTH:
        case NM.DeviceState.IP_CONFIG:
        case NM.DeviceState.IP_CHECK:
        case NM.DeviceState.SECONDARIES:
            ethernet_item.sensitive = true;
            ethernet_item.active = true;
            state = State.CONNECTING_WIRED;
            break;

        case NM.DeviceState.ACTIVATED:
            ethernet_item.sensitive = true;
            ethernet_item.active = true;
            state = State.CONNECTED_WIRED;
            break;
        }
    }
}
