#!/usr/bin/env python3
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Wnck", "3.0")
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk, Gio, Wnck
import os
import dropby_tools as db
import subprocess


"""
DropBy
Author: Jacob Vlijm
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
"""


class BudgieDropBy(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieDropBy"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieDropByApplet(uuid)


class DropBySettings(Gtk.Grid):

    def __init__(self, setting):

        super().__init__()
        explanation = Gtk.Label()
        explanation.set_text(
            "The applet will show up when a usb device is connected."
        )
        explanation.set_xalign(0)
        explanation.set_line_wrap(True)
        self.attach(explanation, 0, 0, 1, 1)
        self.show_all()


class BudgieDropByApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        self.connect("destroy", Gtk.main_quit)
        app_path = os.path.dirname(os.path.abspath(__file__))
        self.winpath = os.path.join(app_path, "dropover")
        self.box = Gtk.EventBox()
        self.box.connect("button-press-event", self.create_trigger)
        self.icon = Gtk.Image.new_from_icon_name(
            "budgie-dropby-symbolic", Gtk.IconSize.MENU
        )
        self.idle_icon = Gtk.Image.new_from_icon_name(
            "budgie-dropby-idle", Gtk.IconSize.MENU
        )
        self.scr = Wnck.Screen.get_default()
        self.box.add(self.icon)
        self.add(self.box)
        self.box.show_all()
        self.show_all()
        self.setup_watching()
        self.start_dropover()
        self.refresh_from_idle()

    def create_trigger(self, *args):
        if not self.check_winexists():
            open("/tmp/call_dropby", "wt").write("")

    def start_dropover(self):
        try:
            pid = subprocess.check_output(
                ["pgrep", "-f", self.winpath]
            )
        except subprocess.CalledProcessError:
            subprocess.Popen(self.winpath)

    def check_winexists(self):
        wins = self.scr.get_windows()
        for w in wins:
            if w.get_name() == "dropby_popup":
                return True
        return False

    def setup_watching(self):
        self.watchdrives = Gio.VolumeMonitor.get()
        self.triggers = [
            "volume_added", "volume_removed", "mount_added", "mount_removed",
        ]
        for t in self.triggers:
            self.watchdrives.connect(t, self.refresh_from_idle)

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return DropBySettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True

    def refresh_from_idle(self, subject=None, newvol=None):
        GObject.idle_add(
            self.refresh, subject, newvol,
            priority=GObject.PRIORITY_DEFAULT,
        )

    def refresh(self, subject=None, newvol=None):
        allvols = self.watchdrives.get_volumes()
        get_relevant = db.get_volumes(allvols)
        # decide if we should show or not
        for c in self.box.get_children():
            c.destroy()
        if get_relevant:
            self.box.add(self.icon)
        else:
            self.box.add(self.idle_icon)
        self.box.show_all()
