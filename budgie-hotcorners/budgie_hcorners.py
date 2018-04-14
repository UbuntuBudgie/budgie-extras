#!/usr/bin/env python3
import subprocess
import os
import ast
import gi
import gi.repository
gi.require_version('Budgie', '1.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Budgie, GObject, Gtk, Gdk
import bhctools as bhc


"""
Hot Corners
Author: Jacob Vlijm
Copyright © 2017-2018 Ubuntu Budgie Developers
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


message = """One of the set options requires the Window Previews applet to run.
Please activate Window Previews from Budgie Settings > Add applet.
"""


css_data = """
.label {
  padding-bottom: 3px;
  padding-top: 3px;
  font-weight: bold;
}
"""


currpath = os.path.dirname(os.path.abspath(__file__))
app = os.path.join(currpath, "bhcorners")
showdesktop = os.path.join(currpath, "showdesktop")


defaults = [
    ["Exposé all windows",
     "/usr/lib/budgie-desktop/plugins/budgie-wprviews/wprv_hc nokeys"],
    ["Exposé current application",
     "/usr/lib/budgie-desktop/plugins/budgie-wprviews/wprv_hc" +
     " current nokeys"],
    ["Budgie Desktop Settings", "budgie-desktop-settings"],
    ["Show Raven notifications", "xdotool key super+n"],
    ["Toggle Raven", "xdotool key super+a"],
    ["Lock screen", "gnome-screensaver-command -l"],
    ["Show Desktop", showdesktop],
]


optionals = [
    ["Window Shuffler", "budgie-window-shuffler-toggle"]
]


for opt in optionals:
    if bhc.executable_exists(opt[1]):
        defaults.append(opt)


currpath = os.path.dirname(os.path.abspath(__file__))
app = os.path.join(currpath, "bhcorners")
showdesktop = os.path.join(currpath, "showdesktop")


try:
    os.makedirs(bhc.dr)
except FileExistsError:
    pass


# try read settings file, if it exists
try:
    state_data = ast.literal_eval(open(bhc.settings).read().strip())
except (FileNotFoundError, SyntaxError):
    # if not, drop to defaults (buttons, entries)
    states = [False, False, False, False]
    entry_data = None
    default_types = [True, True, True, True]
else:
    states = [d[0] for d in state_data]
    entry_data = [d[1] for d in state_data]
    check_types = [cmd[1] for cmd in defaults]
    default_types = [
        any([cmd in check_types, cmd == ""]) for cmd in entry_data
    ]


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


class BudgieHotCornersSettings(Gtk.Grid):

    def __init__(self, setting):

        super().__init__()

        self.setting = setting
        # grid & layout
        self.toggle = Gtk.CheckButton.new_with_label("Use pressure")
        pressuredata = bhc.get_pressure()
        pressure = pressuredata[0]
        pressure_val = pressuredata[1]
        self.toggle.set_active(pressure)
        self.toggle.connect("toggled", self.switch)
        self.attach(self.toggle, 0, 0, 1, 1)
        self.pressure_slider = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 10, 100, 10
        )
        if not pressure:
            self.pressure_slider.set_sensitive(False)
            self.pressure_slider.set_value(40)
        elif pressure_val:
            self.pressure_slider.set_value(pressuredata[1] / 5)
        self.pressure_slider.connect("value_changed", self.get_slider)
        self.attach(self.pressure_slider, 0, 1, 1, 1)
        self.show_all()

    def get_slider(self, slider):
        val = int(self.pressure_slider.get_value()) * 5
        bhc.set_pressure(str(val))

    def switch(self, button, *args):
        pressure = bhc.get_pressure()[0]
        if pressure:
            try:
                os.remove(bhc.pressure_trig)
            except FileNotFoundError:
                pass
            self.pressure_slider.set_sensitive(False)
        else:
            open(bhc.pressure_trig, "wt").write("200")
            self.pressure_slider.set_value(40)
            self.pressure_slider.set_sensitive(True)


class BudgieHotCornersApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """

    # manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        self.maingrid = Gtk.Grid()
        self.maingrid.set_row_spacing(5)
        self.maingrid.set_column_spacing(5)
        self.provider = Gtk.CssProvider.new()
        self.provider.load_from_data(css_data.encode())
        self.buttons = []
        self.entries = []
        self.checks = []
        self.custom_entries = []
        corners = ["Top-left", "Top-right", "Bottom-left", "Bottom-right"]
        self.default_commands = [cmdata[1] for cmdata in defaults]
        # create headers
        corner_label = Gtk.Label(" Corner", xalign=0)
        command_label = Gtk.Label(" Action", xalign=0)
        custom_label = Gtk.Label(" Custom ", xalign=0)
        self.maingrid.attach(corner_label, 0, 0, 1, 1)
        self.maingrid.attach(command_label, 1, 0, 1, 1)
        self.maingrid.attach(custom_label, 2, 0, 2, 1)
        for label in [custom_label, command_label, corner_label]:
            label_cont = label.get_style_context()
            label_cont.add_class("label")
            Gtk.StyleContext.add_provider(
                label_cont,
                self.provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
            )
        # create rows
        for n in range(len(corners)):
            # active / inactive toggle button
            self.button = Gtk.ToggleButton.new_with_label(corners[n])
            self.maingrid.attach(self.button, 0, n + 1, 1, 1)
            self.buttons.append(self.button)
            self.button.connect("clicked", self.switch_entry, n)
            # new: checkbox
            spacer = Gtk.Label(" ")
            self.maingrid.attach(spacer, 2, n + 1, 1, 1)
            self.custom_checkbox = Gtk.CheckButton()
            self.maingrid.attach(self.custom_checkbox, 3, n + 1, 1, 1)
            self.checks.append(self.custom_checkbox)
            self.custom_checkbox.connect("toggled", self.swap_widgets)
            # custom
            self.custom_entry = Gtk.Entry()
            self.custom_entry.set_size_request(218, 20)
            self.custom_entries.append([self.custom_entry, 1, n + 1])
            # dropdown (default)
            self.entry = self.create_combo(n)
            self.entries.append([self.entry, 1, n + 1])
            # attach the corresponding object
            subject = self.entry if default_types[n] else self.custom_entry
            self.maingrid.attach(subject, 1, n + 1, 1, 1)
            # populate entries
            try:
                cmd = entry_data[n]
            except TypeError:
                pass
            else:
                if cmd != "":
                    try:
                        subject.set_text(cmd)
                        self.checks[n].set_active(True)
                    except AttributeError:
                        subject.set_active(self.default_commands.index(cmd))
                        self.checks[n].set_active(False)
        # set initial values, states, sensitive
        n_items = len(states)
        for n in range(n_items):
            val = states[n]
            self.buttons[n].set_active(val)
            self.entries[n][0].set_sensitive(val)
            self.custom_entries[n][0].set_sensitive(val)
            self.checks[n].set_sensitive(val)
        # get resolution
        res = bhc.getres()
        scr = Gdk.Screen.get_default()
        scr.connect("size-changed", self.update_settings)
        # popover stuff
        self.box = Gtk.EventBox()
        icon = Gtk.Image.new_from_icon_name(
            "budgie-hotcorners-symbolic", Gtk.IconSize.MENU
        )
        self.box.add(icon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        self.popover.add(self.maingrid)
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        # connect widgets
        self.box.connect("button-press-event", self.on_press)
        for button in self.buttons:
            button.connect("clicked", self.update_settings)
        for entry in [entry[0] for entry in self.entries]:
            entry.connect("changed", self.update_settings)
        for c_entry in [entry[0] for entry in self.custom_entries]:
            c_entry.connect("key-release-event", self.update_settings)
        for check in self.checks:
            check.connect("toggled", self.update_settings)
        self.close_running()
        subprocess.Popen([app, str(res[0]), str(res[1])])

    def swap_widgets(self, checkbutton):
        custom_type = checkbutton.get_active()
        i = self.checks.index(checkbutton)
        exch = [entr[i] for entr in [self.entries, self.custom_entries]]
        if custom_type:
            oldwidget_data = exch[0]
            newdata = exch[1]
        else:
            oldwidget_data = exch[1]
            newdata = exch[0]
        self.maingrid.remove(oldwidget_data[0])
        self.maingrid.attach(
            newdata[0], newdata[1], newdata[2], 1, 1,
        )
        self.maingrid.show_all()

    def create_combo(self, n):
        command_combo = Gtk.ComboBoxText()
        command_combo.set_entry_text_column(0)
        command_combo.set_size_request(200, 20)
        for cmd in defaults:
            command_combo.append_text(cmd[0])
        return command_combo

    def switch_entry(self, button, n):
        # set (custom or not-) entry active / inactive
        subjects = [
            self.entries[n][0], self.custom_entries[n][0], self.checks[n],
        ]
        state = button.get_active()
        val = True if state is True else False
        for sj in subjects:
            sj.set_sensitive(val)

    def close_running(self):
        try:
            pid = bhc.get(["pgrep", "-f", "-u", bhc.user, app]).splitlines()
        except AttributeError:
            pass
        else:
            for p in pid:
                subprocess.call(["kill", p])

    def update_settings(self, widget, *args):
        res = bhc.getres()
        b_states = [b.get_active() for b in self.buttons]
        cmds = []
        msg = False
        for n in range(len(self.custom_entries)):
            custom = self.checks[n].get_active()
            if custom:
                cmds.append(self.custom_entries[n][0].get_text())
            else:
                cmd_title = self.entries[n][0].get_active_text()
                try:
                    cmds.append(
                        [item[1] for item in defaults
                         if item[0] == cmd_title][0]
                    )
                except IndexError:
                    cmds.append("")
                else:
                    # send a message if user pick inactive wpreviews
                    if all([
                        "Exposé" in cmd_title,
                        not bhc.getkey("Window Previews"),
                        not msg,
                        b_states[n] is True,
                    ]):
                        img = "budgie-hotcorners-symbolic"
                        subprocess.Popen([
                            "notify-send", "-i", img,
                            "Activate Window Previews",
                            message,
                        ])
                        msg = True
        saved_state = list(zip(b_states, cmds))
        open(bhc.settings, "wt").write(str(saved_state))
        self.close_running()
        subprocess.Popen([app, str(res[0]), str(res[1])])

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return BudgieHotCornersSettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True

    def on_press(self, box, arg):
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)
