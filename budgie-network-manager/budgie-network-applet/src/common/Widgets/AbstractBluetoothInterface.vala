// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright 2022 Ubuntu Budgie Developers
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

public abstract class Network.AbstractBluetoothInterface : Network.WidgetNMInterface {
    public override void update_name (int count) {
        var name = device.get_description ();
        //if (count > 1) {
            display_title = _("%s Network").printf (name);
        //} else {
        //    display_title = _("Bluetooth");
        //}

        /*if (device is NM.DeviceBt) {
            var device = (device as NM.DeviceBt);
            if (device != null) {
                var capabilities = device.get_current_capabilities ();
                if (NM.DeviceModemCapabilities.POTS in capabilities) {
                    display_title = _("Modem");
                }
            }
        }*/
    }
}
