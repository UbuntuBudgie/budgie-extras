#! /usr/bin/python3
import os
import gi
gi.require_version('Budgie', '1.0')
gi.require_version('Wnck', '3.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Budgie, GObject, Gtk, Wnck, GLib
import time
import ast


"""
Budgie Workspace Timer
Author: Jacob Vlijm
Copyright © 2017-2020 Ubuntu Budgie Developers
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


class BudgieWorkspaceStopwatch(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieWorkspaceStopwatch"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieWorkspaceStopwatchApplet(uuid)


class BudgieWorkspaceStopwatchApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)

        # setup css
        timer_css = """
        .label {
          padding-bottom: 7px;
          padding-top: 0px;
          font-weight: bold;
        }
        .button {
          margin-top: 10px;
          margin-left: 30px;
        }
        """
        self.provider = Gtk.CssProvider.new()
        self.provider.load_from_data(timer_css.encode())
        # setup general stuff
        self.scr = Wnck.Screen.get_default()
        # self.scr.force_update()
        self.scr.connect("active-workspace-changed", self.act_on_change)
        self.logfile = os.path.join(os.environ["HOME"], ".workspace_log")
        self.load_data()
        currws = self.scr.get_active_workspace()
        self.starttime = time.time()
        self.last_logged = self.starttime
        self.act_on_change(self.scr, currws)
        GLib.timeout_add_seconds(30, self.update_log)
        self.maingrid = Gtk.Grid()
        # panel
        self.seticon = Gtk.Image.new_from_icon_name(
            "budgie-wstopwatch-symbolic", Gtk.IconSize.MENU
        )
        self.box = Gtk.EventBox()
        self.box.add(self.seticon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        self.popover.add(self.maingrid)
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)

    def update_log(self):
        self.newlogged = time.time()
        if self.newlogged - self.last_logged > 35:
            currws = self.scr.get_active_workspace()
            self.starttime = time.time()
            self.act_on_change(self.scr, currws)
        open(self.logfile, "wt").write(str(self.workspace_data))
        self.last_logged = self.newlogged
        return True

    def load_data(self):
        try:
            self.workspace_data = ast.literal_eval(open(self.logfile).read())
        except (FileNotFoundError, SyntaxError):
            self.workspace_data = {}

    def time_format(self, s):
        # convert time format from seconds to h:m:s
        m, s = divmod(s, 60)
        h, m = divmod(m, 60)
        return "%02d:%02d:%02d" % (h, m, s)

    def act_on_change(self, screen, workspace):
        self.workspaces = screen.get_workspaces()
        key = self.workspaces.index(workspace)
        currtime = time.time()
        span = currtime - self.starttime
        # try get current time for key, add key if needed
        try:
            curr_spent = self.workspace_data[key]["time"]
        except KeyError:
            curr_spent = 0
            self.workspace_data[key] = {
                "time": curr_spent,
                "custom_name": "workspace: " + str(key + 1)
            }
        self.workspace_data[key]["time"] = curr_spent + span
        self.starttime = currtime
        open(self.logfile, "wt").write(str(self.workspace_data))

    def on_press(self, box, arg):
        self.show_result()
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)

    def set_widgetstyle(self, widget, style):
        widget_cont = widget.get_style_context()
        widget_cont.add_class(style)
        Gtk.StyleContext.add_provider(
            widget_cont,
            self.provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def show_result(self, *args):
        self.maingrid.destroy()
        self.maingrid = Gtk.Grid()
        self.popover.add(self.maingrid)
        # update to latest
        currws = self.scr.get_active_workspace()
        self.act_on_change(self.scr, currws)
        topleft = Gtk.Label()
        topleft.set_text("\t")
        self.maingrid.attach(topleft, 0, 0, 1, 1)
        bottomright = Gtk.Label()
        bottomright.set_text("\t")
        self.maingrid.attach(bottomright, 100, 100, 1, 1)
        workspace_header = Gtk.Label()
        workspace_header.set_text("Workspace")
        self.maingrid.attach(workspace_header, 2, 1, 1, 1)
        workspace_header.set_xalign(0)
        time_header = Gtk.Label()
        time_header.set_text("Time")
        self.maingrid.attach(time_header, 4, 1, 1, 1)
        time_header.set_xalign(0)
        for label in [workspace_header, time_header]:
            self.set_widgetstyle(label, "label")
        n = 2
        for k in sorted(self.workspace_data.keys()):
            if n - 2 == self.workspaces.index(currws):
                bullet = Gtk.Label()
                bullet.set_text("⮕ ")
                self.maingrid.attach(bullet, 1, n, 1, 1)
            entry = Gtk.Entry()
            entry.set_text(self.workspace_data[k]["custom_name"])
            entry.connect("changed", self.update_customname, k)
            self.maingrid.attach(entry, 2, n, 1, 1)
            spacer = Gtk.Label()
            spacer.set_text("\t")
            self.maingrid.attach(spacer, 3, n, 1, 1)
            timelabel = Gtk.Label()
            timelabel.set_text(
                str(self.time_format(int(self.workspace_data[k]["time"])))
            )
            timelabel.set_xalign(0)
            self.maingrid.attach(timelabel, 4, n, 1, 1)
            n = n + 1
        resetbutton = Gtk.Button.new_with_label("Reset")
        resetbutton.grab_focus()
        resetbutton.connect("clicked", self.reset_data)
        self.set_widgetstyle(resetbutton, "button")
        self.maingrid.attach(
            resetbutton, 4, 99, 1, 1
        )
        resetbutton.grab_focus()
        self.maingrid.show_all()
        self.popover.show_all()

    def reset_data(self, button):
        self.workspaces = self.scr.get_workspaces()
        todeletekeys = []
        for k in self.workspace_data.keys():
            if k >= len(self.workspaces):
                todeletekeys.append(k)
            else:
                self.workspace_data[k]["time"] = 0
        for k in todeletekeys:
            del self.workspace_data[k]
        self.show_result()

    def update_customname(self, entry, key):
        newname = entry.get_text()
        self.workspace_data[key]["custom_name"] = newname
        self.update_log()
