// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class Network.ModemInterface : Network.AbstractModemInterface {
    private Network.Widgets.Switch modem_item;
    private DBusObjectManagerClient? modem_manager;

    private uint32 _signal_quality;
    public uint32 signal_quality {
        get {
            return _signal_quality;
        }
        private set {
            _signal_quality = value;
            if (device.state == NM.DeviceState.ACTIVATED) {
                state = strength_to_state (value);
            }
        }
    }

    enum ModemAccessTechnology {
        UNKNOWN = 0,
        POTS = 1 << 0,
        GSM = 1 << 1,
        GSM_COMPACT = 1 << 2,
        GPRS = 1 << 3,
        EDGE = 1 << 4,
        UMTS = 1 << 5,
        HSDPA = 1 << 6,
        HSUPA = 1 << 7,
        HSPA = 1 << 8,
        HSPA_PLUS = 1 << 9,
        1XRTT = 1 << 10,
        EVDO0 = 1 << 11,
        EVDOA = 1 << 12,
        EVDOB = 1 << 13,
        LTE = 1 << 14,
        ANY = 0xFFFFFFFF
    }

    public ModemInterface (NM.Client nm_client, NM.Device? _device) {
        device = _device;
        modem_item = new Network.Widgets.Switch (display_title);

        notify["display-title"].connect (() => {
            modem_item.caption = display_title;
        });

        modem_item.get_style_context ().add_class ("h4");
        modem_item.notify["active"].connect (() => {
            if (modem_item.active && device.state == NM.DeviceState.DISCONNECTED) {
                nm_client.activate_connection_async.begin (null, device, null, null, null);
            } else if (!modem_item.active && device.state == NM.DeviceState.ACTIVATED) {
                device.disconnect_async.begin (null, () => { debug ("Successfully disconnected."); });
            }
        });

        add (modem_item);

        device.state_changed.connect (() => { update (); });
        prepare.begin ();
    }

    public override void update () {
        switch (device.state) {
            case NM.DeviceState.UNKNOWN:
            case NM.DeviceState.UNMANAGED:
            case NM.DeviceState.UNAVAILABLE:
            case NM.DeviceState.FAILED:
                modem_item.sensitive = false;
                modem_item.active = false;
                state = State.FAILED_MOBILE;
                break;
            case NM.DeviceState.DISCONNECTED:
            case NM.DeviceState.DEACTIVATING:
                modem_item.sensitive = true;
                modem_item.active = false;
                state = State.FAILED_MOBILE;
                break;
            case NM.DeviceState.PREPARE:
            case NM.DeviceState.CONFIG:
            case NM.DeviceState.NEED_AUTH:
            case NM.DeviceState.IP_CONFIG:
            case NM.DeviceState.IP_CHECK:
            case NM.DeviceState.SECONDARIES:
                modem_item.sensitive = true;
                modem_item.active = true;
                state = State.CONNECTING_MOBILE;
                break;
            case NM.DeviceState.ACTIVATED:
                modem_item.sensitive = true;
                modem_item.active = true;
                state = strength_to_state (signal_quality);
                break;
        }
    }

    private Network.State strength_to_state (uint32 strength) {
        if (strength < 30) {
            return Network.State.CONNECTED_MOBILE_WEAK;
        } else if (strength < 55) {
            return Network.State.CONNECTED_MOBILE_OK;
        } else if (strength < 80) {
            return Network.State.CONNECTED_MOBILE_GOOD;
        } else {
            return Network.State.CONNECTED_MOBILE_EXCELLENT;
        }
    }

    private string? access_technology_to_string (ModemAccessTechnology tech) {
        switch (tech) {
            case ModemAccessTechnology.UNKNOWN:
            case ModemAccessTechnology.POTS:
            case ModemAccessTechnology.ANY:
                return null;
            case ModemAccessTechnology.GSM:
            case ModemAccessTechnology.GSM_COMPACT:
            case ModemAccessTechnology.GPRS:
            case ModemAccessTechnology.1XRTT:
                return "G";
            case ModemAccessTechnology.EDGE:
                return "E";
            case ModemAccessTechnology.UMTS:
            case ModemAccessTechnology.EVDO0:
            case ModemAccessTechnology.EVDOA:
            case ModemAccessTechnology.EVDOB:
                return "3G";
            case ModemAccessTechnology.HSDPA:
            case ModemAccessTechnology.HSUPA:
            case ModemAccessTechnology.HSPA:
                return "H";
            case ModemAccessTechnology.HSPA_PLUS:
                return "H+";
            case ModemAccessTechnology.LTE:
                return "LTE";
            default:
                return null;
        }
    }

    private void device_properties_changed (Variant changed) {
        var signal_variant = changed.lookup_value ("SignalQuality", VariantType.TUPLE);
        if (signal_variant != null) {
            bool recent;
            uint32 quality;
            signal_variant.get ("(ub)", out quality, out recent);
            signal_quality = quality;
        }

        var access_technologies_variant = changed.lookup_value ("AccessTechnologies", VariantType.UINT32);
        if (access_technologies_variant != null) {
            uint32 access_type;
            access_technologies_variant.get ("u", out access_type);
            extra_info = access_technology_to_string ((ModemAccessTechnology)access_type);
        }
    }

    public async void prepare () {
        try {
            modem_manager = yield new DBusObjectManagerClient.for_bus (BusType.SYSTEM,
                DBusObjectManagerClientFlags.NONE, "org.freedesktop.ModemManager1", "/org/freedesktop/ModemManager1", null);
        } catch (Error e) {
            warning ("Unable to connect to ModemManager1 to check cellular internet signal quality: %s", e.message);
            return;
        }

        modem_manager.interface_proxy_properties_changed.connect ((obj_proxy, interface_proxy, changed, invalidated) => {
            if (interface_proxy.g_object_path == device.get_udi ()) {
                device_properties_changed (changed);
            }
        });
    }
}
