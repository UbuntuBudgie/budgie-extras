#!/usr/bin/env python3

"""
Workspace Overview
Author: Jacob Vlijm
Copyright © 2017-2019 Ubuntu Budgie Developers
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

import gi

gi.require_version('Budgie', '1.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Budgie, GObject, Gtk, Gio
from threading import Thread
import time
import wsotools as wtls
import subprocess

modes = ["Simple", "Dotted", "Elipsed dotted", "Menu"]


class WsOverviewWin(GObject.Object):
    mode_index = GObject.property(type=int, default=2)

    def __init__(self):

        GObject.Object.__init__(self)
        settings = Gio.Settings.new(
            "org.ubuntubudgie.plugins.budgie-wsoverview"
        )
        settings.bind("ws-overview-index", self,
                      'mode_index',
                      Gio.SettingsBindFlags.DEFAULT)
        # general
        self.mode = modes[self.mode_index]

        self.appbutton = Gtk.Button.new()
        self.appbutton.set_relief(Gtk.ReliefStyle.NONE)

        icon = Gtk.Image.new_from_icon_name("ws1-symbolic", Gtk.IconSize.MENU)
        self.appbutton.set_image(icon)

        self.menu = Gtk.Menu()
        self.create_menu()
        self.update = Thread(target=self.show_seconds)
        # daemonize the thread to make the indicator stopable
        self.update.setDaemon(True)
        self.update.start()

    def create_menu(self):
        message = Gtk.MenuItem('Starting up...')
        self.menu.append(message)
        self.menu.show_all()
        self.popup = self.menu
        self.appbutton.connect('clicked', self.popup_menu)

    def edit_menu(self):
        for i in self.menu.get_children():
            self.menu.remove(i)
        for m in self.newmenu:
            add = Gtk.MenuItem(m)
            add.connect('activate', self.get_choice)
            self.menu.append(add)
        # fake separator
        self.menu.append(Gtk.MenuItem(''))
        newspace = Gtk.MenuItem('+')
        newspace.connect('activate', self.add_space)
        self.menu.append(newspace)
        self.change_onthefly()
        self.menu.show_all()

    def edit_menu2(self):
        for i in self.menu.get_children():
            self.menu.remove(i)
        for m in self.newmenu:
            ws = str(m[0] + 1)
            space = Gtk.MenuItem(ws)
            self.menu.append(space)
            if m[1]:
                # flattened submenu
                self.submenu = Gtk.Menu()
                for l in [d for d in m[1]]:
                    app = l[0]
                    wins = [[it[0], it[1]] for it in l[1]]
                    for w in wins:
                        name = self.shortname(w[0]) + "  -  " + app
                        winmention = Gtk.MenuItem(name)
                        self.submenu.append(winmention)
                        winmention.connect('activate', self.move_to, w[1])
                space.set_submenu(self.submenu)
            else:
                space.connect('activate', self.get_choice)
        # fake separator
        self.menu.append(Gtk.MenuItem(''))
        newspace = Gtk.MenuItem('+')
        newspace.connect('activate', self.add_space)
        self.menu.append(newspace)
        self.change_onthefly()
        self.menu.show_all()

    def change_onthefly(self):
        modesep = Gtk.SeparatorMenuItem()
        self.menu.add(modesep)
        mode_mention = Gtk.MenuItem("Mode")
        applet_modes = Gtk.Menu()
        active = modes.index(self.mode)
        self.mode_index = active
        self.menulist = ["\t" + m for m in modes]
        self.menulist[active] = "⁕\t" + str(modes[active]) + ""
        for item in self.menulist:
            md = Gtk.MenuItem(item)
            md.connect('activate', self.set_mode, item)
            applet_modes.append(md)
        mode_mention.set_submenu(applet_modes)
        self.menu.add(mode_mention)

    def set_mode(self, widget, arg):
        self.mode = modes[self.menulist.index(arg)]

    def shortname(self, name):
        """shorten too long names for the menu"""
        limit = 35
        return name[:limit - 3] + "..." if len(name) >= limit else name

    def get_choice(self, mention, *args):
        # move to selected workspace
        index = self.menu.get_children().index(self.menu.get_active())
        subprocess.Popen(["wmctrl", "-s", str(index)])

    def move_to(self, button, wid):
        subprocess.Popen(["wmctrl", "-ia", wid])

    def add_space(self, *args):
        # add one workspace
        settings = Gio.Settings.new("org.gnome.desktop.wm.preferences")
        wkspace = settings["num-workspaces"]
        new_n = wkspace + 1
        settings.set_int("num-workspaces", new_n)

    def show_seconds(self):
        wsdata1, n_ws, curr_ws, curr_windata = None, None, None, None
        update_menu, update_menuset, set_icon = False, False, False
        menuset = []
        # cycle time (sec) for update windowlist
        c2 = 3
        t2 = 0
        self.mode1 = self.mode

        while True:
            # master cycle = 1 sec
            time.sleep(1)
            # test_1: windowlist (cycle2 = 3 sec)
            if all([self.mode in modes[0:3], t2 == 0]):
                # see if mode has changed, act if needed
                self.mode2 = self.mode
                if self.mode2 != self.mode1:
                    update_menu = True
                    update_menuset = True
                    self.mode1 = self.mode2
                """see if data on windowslist changed, if not,
                don't rebuild menudata
                """
                new_windata = wtls.get(["wmctrl", "-l"])
                if all([new_windata, new_windata != curr_windata]):
                    update_menu, update_menuset = True, True
                    curr_windata = new_windata
            elif t2 == 0:
                new_windata = wtls.update_winmenu(curr_windata)
                if new_windata != curr_windata:
                    update_menu, update_menuset = True, True
                    curr_windata = new_windata
            t2 = 0 if t2 == c2 - 1 else t2 + 1
            # test_2: workspace- changes (master_cycle)
            wsdata2 = wtls.get(["wmctrl", "-d"])
            if wsdata2 != wsdata1:
                sp = wtls.getspaces(wsdata2)
                sp0 = sp[0]
                sp1 = sp[1]
                if sp0 != n_ws:
                    update_menu = True
                    n_ws = sp0
                if sp1 != curr_ws:
                    set_icon = True
                    curr_ws = sp1
                wsdata1 = wsdata2
            # apply possible results
            if set_icon:
                newic = wtls.new_icon(curr_ws)
                icon = Gtk.Image.new_from_icon_name(newic, Gtk.IconSize.MENU)
                GObject.idle_add(
                    self.appbutton.set_image, icon,
                    priority=GObject.PRIORITY_DEFAULT
                )
            if self.mode == "Menu":
                if update_menuset:
                    # update window-contents for menu
                    menuset = new_windata[1]
                if update_menu:
                    self.newmenu = []
                    for n in range(n_ws):
                        try:
                            appdata = [
                                applist[1:] for applist in menuset
                                if applist[0] == n
                            ][0]
                            self.newmenu.append([n, appdata])
                        except IndexError:
                            self.newmenu.append([n, None])
                    GObject.idle_add(
                        self.edit_menu2,
                        priority=GObject.PRIORITY_DEFAULT
                    )
            else:
                if update_menuset:
                    # update window-contents for menu
                    menuset = wtls.get_menuset(curr_windata)
                if update_menu:
                    if self.mode == "Dotted":
                        self.newmenu = [" ".join([
                            str(n + 1), menuset.count(str(n)) * "•"
                        ]) for n in range(n_ws)]
                    # limit dots to 3
                    elif self.mode == "Elipsed dotted":
                        self.newmenu = []
                        for n in range(n_ws):
                            n_dots = menuset.count(str(n))
                            n_dots = n_dots if n_dots <= 3 else 3
                            self.newmenu.append(" ".join([
                                str(n + 1), n_dots * "•"
                            ]))
                    if self.mode == "Simple":
                        self.newmenu = [str(n + 1) for n in range(n_ws)]
                        pass
                    GObject.idle_add(
                        self.edit_menu,
                        priority=GObject.PRIORITY_DEFAULT
                    )
                    # reset all
            set_icon, update_menuset, update_menu = False, False, False

    def popup_menu(self, *args):
        self.popup.popup(None, None, None, None, 0,
                         Gtk.get_current_event_time())


class WsOverview(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "WsOverview"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return WsOverviewApplet(uuid)


class WsOverviewApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """

    # manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.app = WsOverviewWin()
        GObject.threads_init()
        self.button = self.app.appbutton
        self.add(self.button)
        self.show_all()
