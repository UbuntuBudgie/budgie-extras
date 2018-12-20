import gi.repository

gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk, Gio
import os

"""
RotationLock
Author: David Mohammed
Copyright © 2017-2019 Ubuntu Budgie Developers
Website=https://ubuntubudgie.org
This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or any later version. This
program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details. You
should have received a copy of the GNU General Public License along with this
program.  If not, see <https://www.gnu.org/licenses/>.

screenlock icons
Icons made by Google from https://www.flaticon.com is licensed by
http://creativecommons.org/licenses/by/3.0/
"""


class BudgieRotationLock(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieRotationLock"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieRotationLockApplet(uuid)


class BudgieRotationLockApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.box = Gtk.EventBox()
        self.lockicon = Gtk.Image.new_from_icon_name(
            "budgie-rotation-lock-button-symbolic",
            Gtk.IconSize.MENU,
        )

        self.unlockicon = Gtk.Image.new_from_icon_name(
            "budgie-rotation-button-symbolic",
            Gtk.IconSize.MENU,
        )

        if Gtk.get_major_version() == 3 and \
                Gtk.get_minor_version() == 18:
            # GTK+3.18
            schema = "org.gnome.settings-daemon.plugins.orientation"
            self.key = "active"
        else:
            # > GTK+3.18
            schema = "org.gnome.settings-daemon.peripherals.touchscreen"
            self.key = "orientation-lock"

        self.settings = Gio.Settings.new(schema)

        if self.settings.get_boolean(self.key):
            if self.key == "active":
                self.displayicon = self.unlockicon
            else:
                self.displayicon = self.lockicon
        else:
            if self.key == "active":
                self.displayicon = self.lockicon
            else:
                self.displayicon = self.unlockicon

        self.box.add(self.displayicon)
        self.add(self.box)
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)

    def on_press(self, box, arg):
        self.box.remove(self.displayicon)

        if self.settings.get_boolean(self.key):
            if self.key == "active":
                self.displayicon = self.lockicon
            else:
                self.displayicon = self.unlockicon
            self.settings.set_boolean(self.key, False)
        else:
            if self.key == "active":
                self.displayicon = self.unlockicon
            else:
                self.displayicon = self.lockicon

            self.settings.set_boolean(self.key, True)

        self.box.add(self.displayicon)
        self.box.show_all()
