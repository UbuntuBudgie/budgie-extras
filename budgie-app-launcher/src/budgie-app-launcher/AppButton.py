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
from gi.repository import Gdk
from Log import Log
from Error import Error


class AppButton(Gtk.Button):

    def __init__(self, app, iconSize, popover):
        Gtk.Button.__init__(self)
        self.popover = popover
        self.TAG = "budgie-app-launcher.AppButton"
        self.log = Log("budgie-app-launcher")
        self.app = app
        self.info = self.app.getInfo()  # DesktopAppInfo
        self.get_style_context().add_class("flat")
        self.isActionsAvailable = False
        icon = self.info.get_icon()
        if icon:
            img = Gtk.Image.new_from_gicon(icon,
                                           Gtk.IconSize.INVALID)
            img.set_pixel_size(iconSize)
        else:
            img = None
        lab = Gtk.Label(self.info.get_display_name(), xalign=0)
        lab.set_margin_left(7)
        lab.halign = Gtk.Align.START
        lab.valign = Gtk.Align.CENTER

        layout = Gtk.Box(Gtk.Orientation.HORIZONTAL, 0)
        if img:
            layout.pack_start(img, False, False, 0)
        layout.pack_start(lab, True, True, 0)
        self.add(layout)

        # self.set_size_request(0, 36)

        # self.set_tooltip_text(self.info.get_description())
        # self.set_tooltip_text(self.info.get_display_name())
        self.connect("button-press-event", self.onPress)
        self.buildMenu()

    def getApp(self):
        return self.app

    def getInfo(self):
        return self.info

    def showMenu(self, button, event):
        if self.isActionsAvailable:
            self.menu.popup_at_pointer(event)

    def buildMenu(self):
        self.menu = Gtk.Menu()
        actions = self.info.list_actions()

        if len(actions) != 0:
            self.isActionsAvailable = True
            for action in actions:
                displayName = self.info.get_action_name(action)
                item = Gtk.MenuItem.new_with_label(displayName)
                item.connect("activate", self.itemActivate, action)
                item.show_all()
                self.menu.append(item)

    def itemActivate(self, item, *data):
        action = data[0]
        if action is None:
            return
        self.hidePopover()
        self.info.launch_action(action, None)

    def hidePopover(self):
        if (self.popover is not None):
            if self.popover.get_visible():
                self.popover.hide()

    def onPress(self, button, event):
        if event.button != 1:
            self.showMenu(button, event)
            return Gdk.EVENT_PROPAGATE
        else:
            self.hidePopover()
            self.launchApp()
        return Gdk.EVENT_STOP

    def launchApp(self):
        try:
            self.info.launch(None, None)
        except Exception as e:
            self.log.e(self.TAG, Error.ERROR_8010, e)
