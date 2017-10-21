import gi.repository

gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk
import subprocess
import os
import ast
from bhctools import get, dr, settings

"""
Budgie Hot Corners
Author: Jacob Vlijm
Copyright=Copyright © 2017 Ubuntu Budgie Developers
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

app = os.path.dirname(os.path.realpath(__file__)) + "/bhcorners"

try:
    os.makedirs(dr)
except FileExistsError:
    pass

# try read settings file, if it exists
try:
    state_data = ast.literal_eval(open(settings).read().strip())
except (FileNotFoundError, SyntaxError):
    # if not, drop to defaults (buttons, entries)
    states = [False, False, False, False]
    entry_data = None
else:
    states = [d[0] for d in state_data]
    entry_data = [d[1] for d in state_data]


class BudgieHotCorners(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieHotCorners"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieHotCornersApplet(uuid)


class BudgieHotCornersApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """

    # manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.maingrid = Gtk.Grid()
        self.maingrid.set_row_spacing(5)
        self.maingrid.set_column_spacing(5)
        self.buttons = []
        self.entries = []
        corners = ["Top-left", "Top-right", "Bottom-left", "Bottom-right"]
        # create button & entry rows
        for n in range(len(corners)):
            self.entry = Gtk.Entry()
            self.maingrid.attach(self.entry, 1, n, 1, 1)
            self.entries.append(self.entry)
            self.button = Gtk.ToggleButton.new_with_label(corners[n])
            self.maingrid.attach(self.button, 0, n, 1, 1)
            self.buttons.append(self.button)
            self.button.connect("clicked", self.switch_entry, n)
        n_items = len(states)
        # set values
        for n in range(n_items):
            val = states[n]
            self.buttons[n].set_active(val)
            curr_entry = self.entries[n]
            curr_entry.set_sensitive(val)
            if entry_data:
                curr_entry.set_text(entry_data[n])
        self.box = Gtk.EventBox()
        icon = Gtk.Image.new_from_icon_name("bhcpanel", Gtk.IconSize.MENU)
        self.box.add(icon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        self.popover.add(self.maingrid)
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)
        for button in self.buttons:
            button.connect("clicked", self.update_settings)
        for entry in self.entries:
            entry.connect("key-release-event", self.update_settings)
        self.close_running()
        subprocess.Popen(app)

    def switch_entry(self, button, n):
        # toggle entry active/inactive
        subj = self.entries[n]
        state = subj.get_sensitive()
        val = False if state is True else True
        subj.set_sensitive(val)

    def close_running(self):
        try:
            pid = get(["pgrep", "-f", app]).splitlines()
        except AttributeError:
            pass
        else:
            for p in pid:
                subprocess.call(["kill", p])    

    def update_settings(self, widget, *args):
        b_states = [b.get_active() for b in self.buttons]
        cmds = [c.get_text() for c in self.entries]
        saved_state = list(zip(b_states, cmds))
        open(settings, "wt").write(str(saved_state))
        self.close_running()
        subprocess.Popen(app)

    def on_press(self, box, arg):
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)
