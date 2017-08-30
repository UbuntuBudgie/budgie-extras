#!/usr/bin/env python3

"""
Budgie Hot Corners
Author: Jacob Vlijm
Copyright © 2017 Ubuntu Budgie Developers
Website: https://ubuntubudgie.org
This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or any later version. This
program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details. You
should have received a copy of the GNU General Public License along with this
program.  If not, see <http://www.gnu.org/licenses/>.
"""

import gi.repository
gi.require_version('Budgie', '1.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Budgie, GObject, Gtk, Gdk
import subprocess
import sys
bhcpath = "/opt/budgie-hotcorners/budgie-hotcorners/"
sys.path.insert(0, bhcpath)
import os
import bhctools as bhc

callset = os.path.join(bhcpath, "bhcsettings")
panelrunner = os.path.join(bhcpath, "bhc-panelrunner")
class BHCornersWin():

    def __init__(self):

        self.appbutton = Gtk.Button.new()
        self.appbutton.set_relief(Gtk.ReliefStyle.NONE)
        icon = Gtk.Image.new_from_file(
            "/opt/budgie-hotcorners/misc/bhcorners22.png"
            )
        self.appbutton.set_image(icon)
        self.menu = Gtk.Menu()
        self.create_menu()
        subprocess.Popen(panelrunner)

    def create_menu(self):
        callsettings = Gtk.MenuItem("Set hot corners")
        callsettings.connect("activate", self.call_settings) 
        self.menu.append(callsettings)
        self.menu.show_all()
        self.popup = self.menu
        self.appbutton.connect('clicked', self.popup_menu)

    def popup_menu(self, *args):
        self.popup.popup(None, None, None, None, 0, Gtk.get_current_event_time())

    def call_settings(self, button):
        if not bhc.get(["pgrep", "-f", callset]):
            subprocess.Popen(callset)

                             
class BHCorners(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BHCorners"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)
        
    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BHCornersApplet(uuid)


class BHCornersApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    # manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.app = BHCornersWin()
        self.button = self.app.appbutton
        self.add(self.button)
        self.show_all()


