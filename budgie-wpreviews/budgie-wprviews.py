import gi.repository

gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk, Gio
import subprocess
import os
import wprviews_tools as pv
import set_keys

"""
Budgie WindowPreviews
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

message = """
The following shortcuts are
automatically set:

- Alt + Tab
  (show all windows)
- Alt + Above_Tab (grave)
  (show windows of the
  active application)

Applet runs without
a panel icon
"""

# user
user = pv.user
# plugin path
plugin_path = pv.plugin_path
# panelrunner (wrapper to take care of toggle applet and manage shortcuts)
panelrunner = os.path.join(plugin_path, "wprviews_panelrunner")
# backgrounder, maintaining the set of window prevews
backgrounder = os.path.join(plugin_path, "wprviews_backgrounder")
# settings path
settings_dir = os.path.join(
    os.environ["HOME"], ".config", "budgie-extras", "previews"
)
# file to trigger enabled/disabled from the panelrunner
previews_ismuted = pv.previews_ismuted

# make sure the settings dir exist
try:
    os.makedirs(settings_dir)
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


class WPrviews(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "WPrviews"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return WPrviewsApplet(uuid)


class WPrviewsSettings(Gtk.Grid):
    keybind = GObject.property(type=bool, default=False)

    def __init__(self, setting):

        super().__init__()

        self.setting = setting
        ismuted = os.path.exists(previews_ismuted)
        # grid & layout
        self.toggle = Gtk.CheckButton.new_with_label("Run WindowPreviews")
        self.toggle.set_active(not ismuted)
        self.toggle.connect("toggled", self.switch)

        self.attach(self.toggle, 0, 0, 1, 1)
        keybinding = Gtk.CheckButton.new_with_label(
            "Disable keyboard shortcuts"
        )
        self.attach(keybinding, 0, 1, 1, 1)
        self.settings = pv.shortc_settings
        self.settings.bind(
            "keybind", self, 'keybind', Gio.SettingsBindFlags.DEFAULT
        )
        keybinding.set_active(self.keybind)
        keybinding.connect("toggled", self.keybind_toggled)

        self.explanation = None
        if not self.keybind:
            self.explanation = Gtk.Label(message)
            self.attach(self.explanation, 0, 2, 1, 1)

        self.show_all()

    def switch(self, button, *args):
        # toggle ui & manage trigger file (noticed by panelrunner)
        pids = check_runs(backgrounder)
        if pids:
            open(previews_ismuted, "wt").write("")
        else:
            subprocess.Popen(panelrunner)
            try:
                os.remove(previews_ismuted)
            except FileNotFoundError:
                pass

    def keybind_toggled(self, button, *args):
        # keybinding ui (noticed by panelrunner)
        self.keybind = not self.keybind
        if self.keybind:
            set_keys.change_keys('restore')
        else:
            set_keys.change_keys('set_custom')

        if not self.explanation:
            self.explanation = Gtk.Label(message)
            self.explanation.show()
            self.attach(self.explanation, 0, 2, 1, 1)

        self.explanation.set_visible(not self.keybind)


class WPrviewsApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        ismuted = os.path.exists(previews_ismuted)
        if not ismuted:
            self.initiate()

    def initiate(self):
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
