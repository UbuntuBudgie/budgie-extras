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
*
*/

public enum Network.State {
    DISCONNECTED,
    WIRED_UNPLUGGED,
    DISCONNECTED_WIRED, //Deprecated
    DISCONNECTED_AIRPLANE_MODE,
    CONNECTED_WIRED,
    CONNECTED_VPN,
    CONNECTED_WIFI,
    CONNECTED_WIFI_WEAK,
    CONNECTED_WIFI_OK,
    CONNECTED_WIFI_GOOD,
    CONNECTED_WIFI_EXCELLENT,
    CONNECTED_MOBILE_WEAK,
    CONNECTED_MOBILE_OK,
    CONNECTED_MOBILE_GOOD,
    CONNECTED_MOBILE_EXCELLENT,
    CONNECTING_WIFI,
    CONNECTING_MOBILE,
    CONNECTING_WIRED,
    CONNECTING_VPN,
    FAILED_WIRED,
    FAILED_WIFI,
    FAILED_MOBILE,
    FAILED_VPN;

    public int get_priority () {
        switch (this) {
            case Network.State.CONNECTING_WIRED:
                return 0;
            case Network.State.CONNECTING_WIFI:
                return 1;
            case Network.State.CONNECTING_MOBILE:
                return 2;
            case Network.State.CONNECTED_WIRED:
                return 3;
            case Network.State.CONNECTED_WIFI:
            case Network.State.CONNECTED_WIFI_WEAK:
            case Network.State.CONNECTED_WIFI_OK:
            case Network.State.CONNECTED_WIFI_GOOD:
            case Network.State.CONNECTED_WIFI_EXCELLENT:
                return 4;
            case Network.State.CONNECTED_MOBILE_WEAK:
            case Network.State.CONNECTED_MOBILE_OK:
            case Network.State.CONNECTED_MOBILE_GOOD:
            case Network.State.CONNECTED_MOBILE_EXCELLENT:
                return 5;
            case Network.State.FAILED_WIRED:
            case Network.State.FAILED_WIFI:
            case Network.State.FAILED_VPN:
            case Network.State.FAILED_MOBILE:
                return 6;
            case Network.State.DISCONNECTED_WIRED:
            case Network.State.DISCONNECTED_AIRPLANE_MODE:
                return 7;
            default:
                return 8;
        }
    }
}
