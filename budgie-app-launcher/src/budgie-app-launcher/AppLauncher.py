#!/usr/bin/python3

# This file is part of App Launcher

# Copyright © 2018-2019 Ubuntu Budgie Developers

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.


import gi.repository

gi.require_version('Budgie', '1.0')
from gi.repository import Budgie
from gi.repository import GObject
from AppLauncherApplet import AppLauncherApplet


class AppLauncher(GObject.GObject, Budgie.Plugin):
    # This is simply an entry point into your Budgie Applet implementation.
    # Note you must always override Object, and implement Plugin.

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "io_serdarsen_github_budgie_app_launcher"

    def __init__(self):
        # Initialisation is important.
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        # This is where the real fun happens. Return a
        # new Budgie.Applet instance with the given UUID.
        # The UUID is determined by the BudgiePanelManager, and is used for
        # lifetime tracking.
        return AppLauncherApplet(uuid)
