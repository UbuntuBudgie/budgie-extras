import gi.repository
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk
import subprocess
import os

"""
Budgie WallpaperSwitcher
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

user = os.environ["USER"]
plugin_path = os.path.dirname(os.path.abspath(__file__))
panelrunner = os.path.join(plugin_path, "wswitcher_panelrunner")
backgrounder = os.path.join(plugin_path, "wswitcher_run")
wswitcher_path = os.path.join(
    os.environ["HOME"],
    ".config",
    "budgie-extras",
    "wswitcher",
)

try:
    os.makedirs(wswitcher_path)
except FileExistsError:
    pass

wswitcher_ismuted = os.path.join(wswitcher_path, "muted")


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


class BudgieWSwitcher(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """
    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieWSwitcher"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieWSwitcherApplet(uuid)


class BudgieWSwitcherSettings(Gtk.Grid):
    def __init__(self, setting):

        super().__init__()
        self.setting = setting
        ismuted = os.path.exists(wswitcher_ismuted)
        self.toggle = Gtk.CheckButton.new_with_label(" Run Wallpaper Switcher")
        self.toggle.set_active(not ismuted)
        self.toggle.connect("clicked", self.switch)
        self.attach(self.toggle, 0, 0, 1, 1)
        label = Gtk.Label("\nApplet runs without a panel icon")
        self.attach(label, 0, 1, 1, 1)
        self.show_all()

    def switch(self, button, *args):
        # toggle ui & manage trigger file (noticed by panelrunner)
        pids = check_runs(backgrounder)
        if pids:
            open(wswitcher_ismuted, "wt").write("")
        else:
            subprocess.Popen(panelrunner)
            try:
                os.remove(wswitcher_ismuted)
            except FileNotFoundError:
                pass


class BudgieWSwitcherApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        ismuted = os.path.exists(wswitcher_ismuted)
        if not ismuted:
            self.initiate()

    def initiate(self):
        pids = check_runs(backgrounder)
        if not pids:
            subprocess.Popen(panelrunner)

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return BudgieWSwitcherSettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True
