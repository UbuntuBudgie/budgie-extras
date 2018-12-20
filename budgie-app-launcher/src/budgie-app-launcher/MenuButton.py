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


class MenuButton(Gtk.HBox):

    def __init__(self, app, iconSize):
        Gtk.HBox.__init__(self)

        self.app = app
        info = self.app.getInfo()  # DesktopAppInfo
        icon = info.get_icon()
        if icon is not None:
            img = Gtk.Image.new_from_gicon(icon, Gtk.IconSize.INVALID)
            img.set_pixel_size(iconSize)
            img.margin_end = 7
        else:
            img = None
        lab = Gtk.Label(info.get_display_name(), xalign=0)
        lab.set_markup(
            "<span size='small'>%s</span>" % info.get_display_name().replace(
                "&", "&amp;"))
        lab.set_margin_left(7)
        lab.halign = Gtk.Align.START
        lab.valign = Gtk.Align.CENTER
        layout = Gtk.Box(Gtk.Orientation.HORIZONTAL, 0)
        if img:
            layout.pack_start(img, False, False, 0)
        layout.pack_start(lab, True, True, 0)
        self.toggleButton = Gtk.ToggleButton()
        self.pack_start(self.toggleButton, True, True, 0)
        self.toggleButton.get_style_context().add_class("flat")
        self.toggleButton.set_sensitive(False)
        self.toggleButton.add(layout)
        self.set_tooltip_text(info.get_description())
        self.checkButton = Gtk.CheckButton()
        self.pack_end(self.checkButton, False, False, 0)
        self.checkButton.set_margin_left(7)
        self.checkButton.set_size_request(24, 24)
        self.checkButton.show_all()

    def addOnToggleMethod(self, method):
        self.toggleButton.connect("toggled", method, self)

    def addOnCheckMethod(self, method):
        self.checkButton.connect("toggled", method, self)

    def setToggled(self, isActive):
        self.toggleButton.set_active(isActive)

    def setToggButtonSensitive(self, isActive):
        self.toggleButton.set_sensitive(isActive)

    def getToggled(self, isActive):
        return self.toggleButton.get_active()

    def setChecked(self, isActive):
        self.checkButton.set_active(isActive)

    def getChecked(self):
        return self.checkButton.get_active()

    def getApp(self):
        return self.app
