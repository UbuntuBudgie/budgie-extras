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

public abstract class Network.AbstractWifiInterface : Network.WidgetNMInterface {
	protected RFKillManager rfkill;
	public NM.DeviceWifi? wifi_device;
	protected NM.AccessPoint? active_ap;
	
	protected Gtk.ListBox wifi_list;

	protected NM.Client nm_client;
	
	protected WifiMenuItem? active_wifi_item { get; set; }
	protected WifiMenuItem? blank_item = null;
	protected Gtk.Stack placeholder;

	protected bool locked;
	protected bool software_locked;
	protected bool hardware_locked;
	
	uint timeout_scan = 0;

	public void init_wifi_interface (NM.Client nm_client, NM.Device? _device) {
		this.nm_client = nm_client;
		device = _device;
		wifi_device = (NM.DeviceWifi)device;
		blank_item = new WifiMenuItem.blank ();
		active_wifi_item = null;
		
		var no_aps_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		no_aps_box.visible = true;
		no_aps_box.valign = Gtk.Align.CENTER; 

		var no_aps = construct_placeholder_label (_("No Access Points Available"), true);

		no_aps_box.add (no_aps);

		var wireless_off_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		wireless_off_box.visible = true;
		wireless_off_box.valign = Gtk.Align.CENTER;		

		var spinner = new Gtk.Spinner ();
		spinner.visible = true;
		spinner.halign = spinner.valign = Gtk.Align.CENTER;
		spinner.start ();
		
		var scanning_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
		var scanning = construct_placeholder_label (_("Scanning for Access Points…"), true);
		
		scanning_box.add (scanning);
		scanning_box.add (spinner);
		scanning_box.visible = true;
		scanning_box.valign = Gtk.Align.CENTER;		
		
		placeholder.add_named (no_aps_box, "no-aps");
		placeholder.add_named (wireless_off_box, "wireless-off");
		placeholder.add_named (scanning_box, "scanning");
		placeholder.visible_child_name = "no-aps";

		/* Monitor killswitch status */
		rfkill = new RFKillManager ();
		rfkill.open ();
		rfkill.device_added.connect (update);
		rfkill.device_changed.connect (update);
		rfkill.device_deleted.connect (update);
		
		wifi_device.notify["active-access-point"].connect (update);
		wifi_device.access_point_added.connect (access_point_added_cb);
		wifi_device.access_point_removed.connect (access_point_removed_cb);
		wifi_device.state_changed.connect (update);
		
		var aps = wifi_device.get_access_points ();
		if (aps != null && aps.length > 0) {
			aps.foreach(access_point_added_cb);
		}

		update();
	}

	construct {
		placeholder = new Gtk.Stack ();
		placeholder.visible = true;

		wifi_list = new Gtk.ListBox ();
		wifi_list.set_sort_func (sort_func);
		wifi_list.set_placeholder (placeholder);

		map.connect (() => wifi_list.invalidate_sort ());
	}

	public override void update_name (int count) {
		if (count <= 1) {
			display_title = _("Wireless");
		}
		else {
			display_title = device.get_description ();
		}
	}

	protected Gtk.Label construct_placeholder_label (string text, bool title) {
		var label = new Gtk.Label (text);
		label.visible = true;
		label.use_markup = true;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;
		label.max_width_chars = 30;
		label.justify = Gtk.Justification.CENTER;

		return label;
	}

	void access_point_added_cb (Object ap_) {
		NM.AccessPoint ap = (NM.AccessPoint)ap_;
		WifiMenuItem? previous_wifi_item = blank_item;

		if (ap.ssid == null) {
			debug ("NULL AP SSID");
			return;
		}

		bool found = false;
		foreach (weak Gtk.Widget w in wifi_list.get_children ()) {
			var menu_item = (WifiMenuItem) w;

			var menu_ssid = menu_item.ssid;
			if (menu_ssid != null && ap.ssid.compare (menu_ssid) == 0) {
				found = true;
				menu_item.add_ap (ap);
				break;
			}

			previous_wifi_item = menu_item;
		}

		/* Sometimes network manager sends a (fake?) AP without a valid ssid. */
		if (!found && ap.ssid != null) {
			var item = new WifiMenuItem (ap, previous_wifi_item);
			item.user_action.connect (wifi_activate_cb);

			previous_wifi_item = item;
			wifi_list.add (item);

			update ();
		}

	}

	void update_active_ap () {
		debug("Update active AP");
		
		active_ap = wifi_device.active_access_point;
		
		if (active_wifi_item != null) {
			if(active_wifi_item.state == Network.State.CONNECTING_WIFI) {
				active_wifi_item.state = Network.State.DISCONNECTED;
			}
			active_wifi_item = null;
		}

		if (active_ap == null) {
			debug("No active AP");
			blank_item.set_active (true);
			return;
		}

		var ssid = active_ap.ssid;
		if (ssid == null) {
			debug ("NULL active AP SSID");
			blank_item.set_active (true);
			return;
		}

		debug ("Active ap: %s", NM.Utils.ssid_to_utf8 (ssid.get_data ()));

		bool found = false;
		foreach (weak Gtk.Widget w in wifi_list.get_children ()) {
			var menu_item = (WifiMenuItem) w;
			if (menu_item.ssid == null)
				continue;

			if (ssid.compare (menu_item.ssid) == 0) {
				found = true;
				menu_item.set_active (true);
				active_wifi_item = menu_item;
				active_wifi_item.state = state;
			}
		}

		/* This can happen at start, when the access point list is populated. */
		if (!found) {
			debug ("Active AP not added");
		}
	}
	
	void access_point_removed_cb (Object ap_) {
		NM.AccessPoint ap = (NM.AccessPoint)ap_;

		WifiMenuItem found_item = null;

		foreach (weak Gtk.Widget w in wifi_list.get_children ()) {
			var menu_item = (WifiMenuItem) w;
			if (menu_item.ssid == null)
				continue;

			if (ap.ssid.compare (menu_item.ssid) == 0) {
				found_item = menu_item;
				break;
			}
		}

		if(found_item == null) {
			critical("Couldn't remove an access point which has not been added.");
			return;
		} else {
			if(!found_item.remove_ap(ap)) {
				found_item.destroy ();
			}
		}
		
		update ();
	}

	Network.State strength_to_state (uint8 strength) {
		if(strength < 30)
			return Network.State.CONNECTED_WIFI_WEAK;
		else if(strength < 55)
			return Network.State.CONNECTED_WIFI_OK;
		else if(strength < 80)
			return Network.State.CONNECTED_WIFI_GOOD;
		else
			return Network.State.CONNECTED_WIFI_EXCELLENT;
	}

	public override void update () {
		switch (wifi_device.state) {
		case NM.DeviceState.UNKNOWN:
		case NM.DeviceState.UNMANAGED:
		case NM.DeviceState.FAILED:
			state = State.FAILED_WIFI;
			if(active_wifi_item != null) {
				active_wifi_item.state = state;
			}
			cancel_scan ();
			break;

		case NM.DeviceState.DEACTIVATING:
		case NM.DeviceState.UNAVAILABLE:
			cancel_scan ();
			placeholder.visible_child_name = "wireless-off";
			state = State.DISCONNECTED;
			break;
		case NM.DeviceState.DISCONNECTED:
			set_scan_placeholder ();
			state = State.DISCONNECTED;
			break;

		case NM.DeviceState.PREPARE:
		case NM.DeviceState.CONFIG:
		case NM.DeviceState.NEED_AUTH:
		case NM.DeviceState.IP_CONFIG:
		case NM.DeviceState.IP_CHECK:
		case NM.DeviceState.SECONDARIES:
			set_scan_placeholder ();
			state = State.CONNECTING_WIFI;
			break;
		
		case NM.DeviceState.ACTIVATED:
			set_scan_placeholder ();
			
			/* That can happen if active_ap has not been added yet, at startup. */
			if (active_ap != null) {
				state = strength_to_state(active_ap.get_strength());
			} else {
				state = State.CONNECTED_WIFI_WEAK;
			}
			break;
		}

		debug("New network state: %s", state.to_string ());
		
		/* Wifi */
		software_locked = false;
		hardware_locked = false;
		foreach (var device in rfkill.get_devices ()) {
			if (device.device_type != RFKillDeviceType.WLAN)
				continue;

			if (device.software_lock)
				software_locked = true;
			if (device.hardware_lock)
				hardware_locked = true;
		}

		locked = hardware_locked || software_locked;

		update_active_ap ();

		base.update ();
	}

	void cancel_scan () {
		if (timeout_scan > 0) {
			Source.remove (timeout_scan);
			timeout_scan = 0;
		}
	}

	void set_scan_placeholder () {
		// this state is the previous state (because this method is called before putting the new state)
		if (state == State.DISCONNECTED) {
			placeholder.visible_child_name = "scanning";
			cancel_scan ();
			wifi_device.request_scan_async.begin (null, null);
			timeout_scan = Timeout.add(5000, () => {
				timeout_scan = 0;
				placeholder.visible_child_name = "no-aps";
				return false;
			});
		}
	}

	protected abstract void wifi_activate_cb (WifiMenuItem i);

	private int sort_func (Gtk.ListBoxRow r1, Gtk.ListBoxRow r2) {
		if (r1 == null || r2 == null) {
			return 0;
		}

		var w1 = (WifiMenuItem)r1;
		var w2 = (WifiMenuItem)r2;

		return w2.strength - w1.strength;
	}
}
