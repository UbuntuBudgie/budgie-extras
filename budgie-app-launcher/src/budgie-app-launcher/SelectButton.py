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


class SelectButton(Gtk.Button):

    def __init__(self, active):
        Gtk.Button.__init__(self)

        self.active = active
        self.SELECT_ALL = "Select all"
        self.DESELECT_ALL = "Deselect all"
        self.label = Gtk.Label()
        self.add(self.label)
        self.set_size_request(96, 0)
        self.setActive(self.active)
        self.get_style_context().add_class("flat")

    def setActive(self, active):
        self.active = active
        if active:
            markup = "<span size='small'>%s</span>" % \
                     self.SELECT_ALL.replace("&", "&amp;")
        else:
            markup = "<span size='small'>%s</span>" % \
                     self.DESELECT_ALL.replace("&", "&amp;")
        self.label.set_markup(markup)

    def isActive(self):
        return self.active

    def addOnClickMethod(self, method):
        self.connect("clicked", method)

    def setSensitive(self, isSensitive):
        self.set_sensitive(isSensitive)
