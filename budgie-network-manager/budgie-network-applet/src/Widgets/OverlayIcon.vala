
/*
* Copyright (c) 2018-2020 Daniel Pinto (https://github.com/danielpinto8zz6/budgie-network-applet)
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

public class Network.Widgets.OverlayIcon : Gtk.Overlay {
    private Gtk.Image main_image;
    private Gtk.Image overlay_image;

    public OverlayIcon (string icon_name) {
        main_image.icon_name = icon_name;
    }

    construct {
        main_image = new Gtk.Image ();
        main_image.icon_size = Gtk.IconSize.MENU;

        overlay_image = new Gtk.Image ();
        overlay_image.icon_size = Gtk.IconSize.MENU;

        add (main_image);
        add_overlay (overlay_image);
    }

    public void set_name (string main_image_icon_name, string? overlay_image_icon_name = null) {
        main_image.icon_name = main_image_icon_name;
        overlay_image.icon_name = overlay_image_icon_name;
    }
} 