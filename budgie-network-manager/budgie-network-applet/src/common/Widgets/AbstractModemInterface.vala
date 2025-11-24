// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright 2017-2020 elementary, Inc. (https://elementary.io)
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

public abstract class Network.AbstractModemInterface : Network.WidgetNMInterface {
    public override void update_name (int count) {
        var name = device.get_description ();
        if (count > 1) {
            display_title = _("Mobile Broadband: %s").printf (name);
        } else {
            display_title = _("Mobile Broadband");
        }

        if (device is NM.DeviceModem) {
            var device = (device as NM.DeviceModem);
            if (device != null) {
                var capabilities = device.get_current_capabilities ();
                if (NM.DeviceModemCapabilities.POTS in capabilities) {
                    display_title = _("Modem");
                }
            }
        }
    }
}
