import gi.repository
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk, Gdk
import subprocess
import os
import wmovertools as wmt
from set_keys import change_keys

"""
Budgie WindowMover
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

panelrunner = os.path.join(wmt.appletpath, "wmover_panelrunner")
backgrounder = os.path.join(wmt.appletpath, "wmover_run")
wmover_path = wmt.settings_path
wmover_ismuted = wmt.wmover_ismuted

try:
    os.makedirs(wmover_path)
except FileExistsError:
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
        self.box = Gtk.EventBox()
        icon = Gtk.Image.new_from_icon_name("wmover-panel", Gtk.IconSize.MENU)
        self.box.add(icon)        
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        ismuted = os.path.exists(wmover_ismuted)
        label = "Window Mover is inactive" if ismuted \
                else "Window Mover is active"
        self.toggle = Gtk.ToggleButton.new_with_label(label)
        self.toggle.set_size_request(210, 20)
        self.toggle.set_active(not ismuted)
        self.toggle.connect("clicked", self.switch)      
        self.popover.add(self.toggle)        
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)
        if not ismuted:
            self.initiate()

    def switch(self, button, *args):
        pids = self.show_procs()
        if pids:
            self.toggle.set_label("Window Mover is inactive.")
            open(wmover_ismuted, "wt").write("")
        else:
            subprocess.Popen(panelrunner)    
            self.toggle.set_label("Window Mover is active")
            try:
                os.remove(wmover_ismuted)
            except FileNotFoundError:
                pass

    def show_procs(self):
        pids = [
            self.check_runs(pname) for pname in [backgrounder]
            ]
        return [p for p in pids if p]

    def check_runs(self, pname):
        try:
            pid = subprocess.check_output([
            "pgrep", "-f", pname,
            ]).decode("utf-8")
        except subprocess.CalledProcessError:
            return None
        else:
            return pid.strip()

    def initiate(self):
        pass
        pids = self.show_procs()
        if not pids:
            subprocess.Popen(panelrunner)
        
    def	on_press(self, box, arg):
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
    	self.manager = manager
    	self.manager.register_popover(self.box, self.popover)

