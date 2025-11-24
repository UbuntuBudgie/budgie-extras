// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2022 Ubuntu Budgie Developers
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
 * Authored by: David Mohammed <fossfreedom@ubuntu.com>
 */

public class Network.BluetoothInterface : Network.AbstractBluetoothInterface {
    private Network.Widgets.Switch bluetooth_item;

    enum BluetoothType {
        NONE = 0,
        DUN = 1 << 0,
        NAP = 1 << 1,
    }

    public BluetoothInterface (NM.Client nm_client, NM.Device? _device) {
        device = _device;
        bluetooth_item = new Network.Widgets.Switch (display_title);

        notify["display-title"].connect (() => {
            bluetooth_item.caption = display_title;
        });

        bluetooth_item.get_style_context ().add_class ("h4");
        bluetooth_item.notify["active"].connect (() => {
            if (bluetooth_item.active && device.state == NM.DeviceState.DISCONNECTED) {
                nm_client.activate_connection_async.begin (null, device, null, null, null);
            } else if (!bluetooth_item.active && device.state == NM.DeviceState.ACTIVATED) {
                device.disconnect_async.begin (null, () => { debug ("Successfully disconnected."); });
            }
        });

        add (bluetooth_item);

        device.state_changed.connect (() => { update (); });
    }

    public override void update () {
        switch (device.state) {
            case NM.DeviceState.UNKNOWN:
            case NM.DeviceState.UNMANAGED:
            case NM.DeviceState.UNAVAILABLE:
            case NM.DeviceState.FAILED:
                bluetooth_item.sensitive = false;
                bluetooth_item.active = false;
                state = State.WIRED_UNPLUGGED;
                break;
            case NM.DeviceState.DISCONNECTED:
            case NM.DeviceState.DEACTIVATING:
                bluetooth_item.sensitive = true;
                bluetooth_item.active = false;
                state = State.FAILED_MOBILE;
                break;
            case NM.DeviceState.PREPARE:
            case NM.DeviceState.CONFIG:
            case NM.DeviceState.NEED_AUTH:
            case NM.DeviceState.IP_CONFIG:
            case NM.DeviceState.IP_CHECK:
            case NM.DeviceState.SECONDARIES:
                bluetooth_item.sensitive = true;
                bluetooth_item.active = true;
                state = State.CONNECTING_MOBILE;
                break;
            case NM.DeviceState.ACTIVATED:
                bluetooth_item.sensitive = true;
                bluetooth_item.active = true;
                state = State.CONNECTED_WIFI_EXCELLENT;
                break;
        }
    }
}
