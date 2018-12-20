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


class EditButton(Gtk.Button):

    def __init__(self, toolTipText):
        Gtk.Button.__init__(self)
        self.border_width = 0
        self.set_can_focus(False)
        # self.set_tooltip_text(toolTipText)
        self.get_style_context().add_class("flat")
        self.image = Gtk.Image.new_from_icon_name(
            "budgie-app-launcher-edit-symbolic", Gtk.IconSize.MENU)
        self.add(self.image)
