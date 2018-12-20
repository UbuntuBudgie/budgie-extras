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


class DirectionalButton(Gtk.Button):

    def __init__(self, label_str, arrow_direction):

        Gtk.Button.__init__(self)

        box = Gtk.Box(Gtk.Orientation.HORIZONTAL, 0)
        box.halign = Gtk.Align.FILL
        label = Gtk.Label(label_str)
        image = Gtk.Image()

        if arrow_direction is Gtk.PositionType.RIGHT:
            image.set_from_icon_name("go-next-symbolic", Gtk.IconSize.MENU)
            box.pack_start(label, True, True, 0)
            box.pack_end(image, False, False, 1)
            image.margin_start = 6
            label.margin_start = 6
        else:
            image.set_from_icon_name("go-previous-symbolic",
                                     Gtk.IconSize.MENU)
            box.pack_start(image, False, False, 0)
            box.pack_start(label, True, True, 0)
            image.margin_end = 6

        label.halign = Gtk.Align.START
        label.margin = 0
        box.margin = 0
        box.border_width = 0
        self.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT)
        self.add(box)
