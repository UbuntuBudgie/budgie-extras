#!/usr/bin/python3

# This file is part of App Launcher

# Copyright © 2018-2019 Ubuntu Budgie Developers

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.


import gi.repository

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk


class ArrowButton(Gtk.Button):

    def __init__(self, arrow_direction):

        Gtk.Button.__init__(self)
        self.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT)

        image = Gtk.Image()

        if arrow_direction is Gtk.PositionType.TOP:
            image.set_from_icon_name("go-up-symbolic", Gtk.IconSize.MENU)
            self.add(image)
        elif arrow_direction is Gtk.PositionType.BOTTOM:
            image.set_from_icon_name("go-down-symbolic", Gtk.IconSize.MENU)
            self.add(image)
