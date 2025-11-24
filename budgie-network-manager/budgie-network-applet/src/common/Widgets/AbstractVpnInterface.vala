/*
 * Copyright 2017-2020 elementary, Inc (https://elementary.io)
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

public abstract class Network.AbstractVpnInterface : Network.WidgetNMInterface {
    protected NM.VpnConnection? active_vpn_connection = null;

    protected Gtk.ListBox vpn_list;

    protected NM.Client nm_client;

    protected VpnMenuItem? active_vpn_item { get; set; }
    protected VpnMenuItem? blank_item = null;

    /**
     * If we want to add a visual feedback on DisplayWidget later,
     * we just need to remove vpn_state and swap it to state on the code
    **/
    public Network.State vpn_state { get; protected set; default = Network.State.DISCONNECTED; }

    public void init_vpn_interface (NM.Client _nm_client) {
        nm_client = _nm_client;
        display_title = _("VPN");

        blank_item = new VpnMenuItem.blank ();
        vpn_list.add (blank_item);
        active_vpn_item = null;

        nm_client.notify["active-connections"].connect (update);
        nm_client.connection_added.connect (vpn_added_cb);
        nm_client.connection_removed.connect (vpn_removed_cb);

        nm_client.get_connections ().foreach ((connection) => vpn_added_cb (connection));

        update ();
    }

    construct {
        // Single click is disabled because it's being handled by VpnMenuItem
        vpn_list = new Gtk.ListBox () {
            activate_on_single_click = false,
            visible = true
        };
    }

    public override void update_name (int count) {
        display_title = _("VPN");
    }

    public override void update () {
        update_active_connection ();

        VpnMenuItem? item = null;

        if (active_vpn_connection != null) {
            switch (active_vpn_connection.vpn_state) {
                case NM.VpnConnectionState.UNKNOWN:
                case NM.VpnConnectionState.DISCONNECTED:
                    vpn_state = State.DISCONNECTED;
                    active_vpn_item = null;
                    break;
                case NM.VpnConnectionState.PREPARE:
                case NM.VpnConnectionState.IP_CONFIG_GET:
                case NM.VpnConnectionState.CONNECT:
                    vpn_state = State.CONNECTING_VPN;
                    item = get_item_by_uuid (active_vpn_connection.get_uuid ());
                    break;
                case NM.VpnConnectionState.FAILED:
                    vpn_state = State.FAILED_VPN;
                    active_vpn_item = null;
                    break;
                case NM.VpnConnectionState.ACTIVATED:
                    vpn_state = State.CONNECTED_VPN;
                    item = get_item_by_uuid (active_vpn_connection.get_uuid ());
                    sensitive = true;
                    break;
                }
        } else {
            vpn_state = State.DISCONNECTED;
        }

        if (item == null) {
            blank_item.set_active (true);

            if (active_vpn_item != null) {
                active_vpn_item.no_show_all = false;
                active_vpn_item.visible = true;
                active_vpn_item.vpn_state = vpn_state;
            }
        }

        base.update ();
    }

    /**
      * The vpn_added_cb is called on new_connection signal,
      * (we get the vpn connections from there)
      * then we filter the connection that make sense for us.
    */
    void vpn_added_cb (Object obj) {
        var vpn = (NM.RemoteConnection)obj;
        switch (vpn.get_connection_type ()) {
            case NM.SettingVpn.SETTING_NAME:
                // Add the item to vpn_list
                var item = new VpnMenuItem (vpn);
                item.set_visible (true);
                item.user_action.connect (vpn_activate_cb);

                vpn_list.add (item);
                update ();
                break;
            default:
                break;
        }
    }

    // Removed vpn, from removed signal attached to connection when it get added.
    void vpn_removed_cb (NM.RemoteConnection vpn_) {
        var item = get_item_by_uuid (vpn_.get_uuid ());
        item.destroy ();
    }

    private VpnMenuItem? get_item_by_uuid (string uuid) {
        VpnMenuItem? item = null;
        foreach (var child in vpn_list.get_children ()) {
            var _item = (VpnMenuItem)child;
            if (_item.connection != null && _item.connection.get_uuid () == uuid && item == null) {
                item = (VpnMenuItem)child;
            }
        }

        return item;
    }

    /**
     * Loop through each active connection to find out the vpn.
    */
    protected void update_active_connection () {
        active_vpn_connection = null;

        nm_client.get_active_connections ().foreach ((ac) => {
            if (ac.get_vpn () && active_vpn_connection == null) {
                active_vpn_connection = (NM.VpnConnection)ac;
                active_vpn_connection.vpn_state_changed.connect (update);

                foreach (var v in vpn_list.get_children ()) {
                    var menu_item = (VpnMenuItem) v;

                    if (menu_item.connection == null)
                        continue;

                    if (menu_item.connection.get_uuid () == active_vpn_connection.uuid) {
                        menu_item.set_active (true);
                        active_vpn_item = menu_item;
                        active_vpn_item.vpn_state = vpn_state;
                    }
                }
            }
        });
    }

    protected abstract void vpn_activate_cb (VpnMenuItem i);
    protected abstract void vpn_deactivate_cb ();
}
