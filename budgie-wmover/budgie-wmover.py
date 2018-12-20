import gi.repository
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk
import subprocess
import os
import wmovertools as wmt

"""
Budgie WindowMover
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
program.  If not, see <http://www.gnu.org/licenses/>.
"""

panelrunner = os.path.join(wmt.appletpath, "wmover_panelrunner")
backgrounder = os.path.join(wmt.appletpath, "wmover_run")
wmover_path = wmt.settings_path
wmover_ismuted = wmt.wmover_ismuted
user = wmt.user

try:
    os.makedirs(wmover_path)
except FileExistsError:
    pass


def check_runs(pname):
    # get the pid of a proc
    try:
        pid = subprocess.check_output([
            "pgrep", "-f", "-u", user, pname,
        ]).decode("utf-8")
    except subprocess.CalledProcessError:
        return None
    else:
        return pid.strip()


message = """
The following shortcuts are
automatically set:

- Ctrl + Alt + w
  (call the window mover)
  then press the number of
  the targeted workspace.

- Ctrl + Alt + s
  (call the desktop mover)
  then press the number of
  the targeted workspace.

Or: drag the window to the
bottom of your screen, and the
window mover appears

Applet runs without a panel
icon
"""


class WPrviewsSettings(Gtk.Grid):
    def __init__(self, setting):

        super().__init__()

        self.setting = setting
        ismuted = os.path.exists(wmt.wmover_ismuted)
        # grid & layout
        explanation = Gtk.Label(message)
        self.attach(explanation, 0, 1, 1, 1)
        self.toggle = Gtk.CheckButton.new_with_label(" Run Window Mover")
        self.toggle.set_active(not ismuted)
        self.toggle.connect("toggled", self.switch)
        self.attach(self.toggle, 0, 0, 1, 1)
        self.show_all()

    def switch(self, button, *args):
        # toggle ui & manage trigger file (noticed by panelrunner)
        pids = check_runs(backgrounder)
        if pids:
            open(wmover_ismuted, "wt").write("")
        else:
            subprocess.Popen(panelrunner)
            try:
                os.remove(wmover_ismuted)
            except FileNotFoundError:
                pass


class WMover(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "WMover"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return WMoverApplet(uuid)


class WMoverApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        ismuted = os.path.exists(wmt.wmover_ismuted)
        self.box = Gtk.EventBox()
        if not ismuted:
            self.initiate()

    def initiate(self):
        pass
        pids = check_runs(backgrounder)
        if not pids:
            subprocess.Popen(panelrunner)

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return WPrviewsSettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True
