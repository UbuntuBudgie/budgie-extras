/*
* Copyright (c) 2015-2016 elementary LLC (http://launchpad.net/wingpanel-indicator-network)
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

public class Network.Widgets.PopoverWidget : Network.Widgets.NMVisualizer {
    private Gtk.Box other_box;
    private Gtk.Box wifi_box;
    private Gtk.Box vpn_box;
    private Gtk.ModelButton show_settings_button;
    private Gtk.ModelButton hidden_item;

    public signal void settings_shown ();

    construct {
        show_settings_button.clicked.connect (show_settings);
        hidden_item.clicked.connect(show_hidden_network_settings);
    }

    protected override void build_ui () {
        orientation = Gtk.Orientation.VERTICAL;

        other_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        wifi_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vpn_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        add (other_box);
        add (wifi_box);
        add (vpn_box);

        hidden_item = new Gtk.ModelButton ();
        hidden_item.text = _("Connect to Hidden Network…");
        hidden_item.no_show_all = true;

        show_settings_button = new Gtk.ModelButton ();
        show_settings_button.text = _("Network Settings…");

        add (hidden_item);
        add (show_settings_button);
    }

    protected override void remove_interface (WidgetNMInterface widget_interface) {
        widget_interface.sep.destroy ();
        widget_interface.destroy ();
    }

    protected override void add_interface (WidgetNMInterface widget_interface) {
        Gtk.Box container_box = other_box;

        if (widget_interface is Network.WifiInterface) {
            container_box = wifi_box;
            hidden_item.no_show_all = false;
            hidden_item.show_all ();

            ((Network.WifiInterface) widget_interface).notify["hidden-sensitivity"].connect (() => {
                bool hidden_sensitivity = false;

                wifi_box.get_children ().foreach ((child) => {
                    if (child is Network.WifiInterface) {
                        hidden_sensitivity = hidden_sensitivity || ((Network.WifiInterface) child).hidden_sensitivity;
                    }

                    hidden_item.sensitive = hidden_sensitivity;
                });
            });
        }

        if (widget_interface is Network.VpnInterface) {
            container_box = vpn_box;
        }

        if (get_children ().length () > 0) {
            container_box.pack_end (widget_interface.sep);
        }

        container_box.pack_end (widget_interface);

        widget_interface.need_settings.connect (show_settings);
    }

    public void opened () {
        foreach (var widget in wifi_box.get_children ()) {
            if (widget is WifiInterface) {
                ((WifiInterface)widget).start_scanning ();
            }
        }
    }

    public void closed () {
        foreach (var widget in wifi_box.get_children ()) {
            if (widget is WifiInterface) {
                ((WifiInterface)widget).cancel_scanning ();
            }
        }
    }

    void show_settings () {
        string paneldesktop = "gnome-wifi-panel.desktop";
        if (Environment.find_program_in_path("budgie-control-center") != null) {
            paneldesktop = "budgie-wifi-panel.desktop";
        }

        var app_info = new DesktopAppInfo(paneldesktop);

        if (app_info == null) {
            return;
        }

        try {
            app_info.launch(null, null);
        } catch (Error e) {
            message("Unable to launch gnome-wifi-panel.desktop: %s", e.message);
        }

        settings_shown ();
    }

    void show_hidden_network_settings() {
        string control_center = "gnome-control-center";
        if (Environment.find_program_in_path("budgie-control-center") != null) {
            control_center = "budgie-control-center";
        }
        string commandline = string.join(" ", control_center, "wifi", "connect-hidden-wifi");

        try {
            var appinfo = AppInfo.create_from_commandline(commandline, null,
                                                              AppInfoCreateFlags.NONE);
            appinfo.launch(null, null);
        } catch (Error e) {
            message("Unable to launch %s: %s", control_center, e.message);
        }

        settings_shown();
    }
}
