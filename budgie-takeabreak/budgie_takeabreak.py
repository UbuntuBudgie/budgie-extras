import gi.repository
import time
import subprocess
import os
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk, Gio
import os


"""
Budgie TakeaBreak
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
nextbreakfile = "/tmp/nextbreak_" + user
tab_settings = Gio.Settings.new("org.ubuntubudgie.plugins.takeabreak")


class BudgieTakeaBreak(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieTakeaBreak"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieTakeaBreakApplet(uuid)


class BudgieTakeaBreakSettings(Gtk.Grid):
    def __init__(self, setting):

        super().__init__()
        self.setting = setting
        # maingrid
        maingrid = Gtk.Grid()
        maingrid.set_column_homogeneous(False)
        maingrid.set_border_width(10)
        self.add(maingrid)
        # uptime section
        uptime_label = Gtk.Label("Work time (min):\t", xalign=0)
        maingrid.attach(uptime_label, 0, 0, 1, 1)
        uptime_set = tab_settings.get_int("awaketime")
        uptime = Gtk.SpinButton.new_with_range(1, 90, 1)
        uptime.set_value(uptime_set)
        uptime.connect("value-changed", self.update_setting, "awaketime")
        maingrid.attach(uptime, 1, 0, 1, 1)
        # breaktime section
        breaktime_label = Gtk.Label("Break time (min):\t", xalign=0)
        maingrid.attach(breaktime_label, 0, 1, 1, 1)
        breaktime_set = tab_settings.get_int("sleeptime")
        breaktime = Gtk.SpinButton.new_with_range(1, 90, 1)
        breaktime.set_value(breaktime_set)
        breaktime.connect("value-changed", self.update_setting, "sleeptime")
        maingrid.attach(breaktime, 1, 1, 1, 1)
        # sep below time section
        maingrid.attach(Gtk.Label("\n"), 0, 5, 1, 1)
        # show notifications checkbox
        shownotify = Gtk.CheckButton("Show notifications")
        notify_set = tab_settings.get_boolean("showmessage")
        shownotify.set_active(notify_set)
        shownotify.connect("toggled", self.update_setting, "showmessage")
        maingrid.attach(shownotify, 0, 6, 4, 1)
        # smart resume checkbox
        smartres = Gtk.CheckButton("Smart resume")
        smartres_set = tab_settings.get_boolean("smartresume")
        smartres.set_active(smartres_set)
        smartres.connect("toggled", self.update_setting, "smartresume")
        smartres.set_tooltip_text(
            "After a break, start count down when user is active"
        )
        maingrid.attach(smartres, 0, 7, 4, 1)
        # sep below  section
        maingrid.attach(Gtk.Label("\n"), 0, 8, 1, 1)
        # option label
        breaktime_label = Gtk.Label("Effect:\n", xalign=0)
        maingrid.attach(breaktime_label, 0, 9, 1, 1)
        # dropdown
        self.effect_options = [
            ["rotate", "Screen upside down"],
            ["dim", "Dim screen"],
            ["message", "Countdown message"],
            ["lock", "Lock screen"],
        ]
        effect_set = tab_settings.get_string("mode")
        effect_index = [s[0] for s in self.effect_options].index(effect_set)
        effect_box = Gtk.Box()
        command_combo = Gtk.ComboBoxText()
        command_combo.set_entry_text_column(0)
        for cmd in self.effect_options:
            command_combo.append_text(cmd[1])
        command_combo.set_active(effect_index)
        command_combo.connect("changed", self.update_setting, "mode")
        maingrid.attach(effect_box, 0, 10, 2, 1)
        effect_box.pack_start(command_combo, False, True, 0)
        self.show_all()

    def update_setting(self, widget, setting):
        if setting in ["awaketime", "sleeptime"]:
            newval = int(widget.get_value())
            tab_settings.set_int(setting, newval)
        elif setting in ["showmessage", "smartresume"]:
            newval = widget.get_active()
            tab_settings.set_boolean(setting, newval)
        elif setting == "mode":
            newval = self.effect_options[widget.get_active()][0]
            tab_settings.set_string(setting, newval)


class BudgieTakeaBreakApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """

    def __init__(self, uuid):

        self.tab_message = ""
        Budgie.Applet.__init__(self)
        self.uuid = uuid

        # applet appearance
        self.icon = Gtk.Image()
        self.img_normal = "takeabreak-symbolic"
        self.img_normal = "takeabreakpaused-symbolic"
        self.icon.set_from_icon_name(
            "takeabreak-symbolic", Gtk.IconSize.MENU
        )

        self.box = Gtk.EventBox()
        self.box.add(self.icon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        self.maingrid = Gtk.Grid()
        self.popover.add(self.maingrid)
        self.maingrid.attach(Gtk.Label("\t"), 0, 0, 1, 1)
        self.maingrid.attach(Gtk.Label("\t"), 100, 100, 1, 1)
        self.next_label = Gtk.Label("Next break")
        self.time_label = Gtk.Label("")
        self.next_label.set_xalign(0.5)
        self.time_label.set_xalign(0.5)
        self.maingrid.attach(self.next_label, 1, 1, 1, 1)
        self.maingrid.attach(self.time_label, 1, 2, 1, 1)
        tab_settings.connect("changed", self.test)

        self.on_offbutton = Gtk.Switch()
        self.onoff_set = tab_settings.get_boolean("paused")
        self.switched_on = self.onoff_set is False
        if self.switched_on:
            self.on_offbutton.set_active(True)
        else:
            self.on_offbutton.set_active(False)
            self.icon.set_from_icon_name(
                "takeabreakpaused-symbolic", Gtk.IconSize.MENU
            )
        self.maingrid.attach(self.on_offbutton, 1, 3, 1, 1)
        self.on_offbutton.connect("state-set", self.act_on_switch)
        self.maingrid.show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)
        self.reset_app(self.onoff_set is False)

    def test(self, *args):
        self.reset_app(tab_settings.get_boolean("paused") is False)

    def act_on_switch(self, button, state):
        tab_settings.set_boolean("paused", state is False)
        self.reset_app(state)
        # if switched on/of from the popup, calculate the time here
        # instead of reading it from the file (else timing issue on startup)
        if state:
            self.set_time_fromapplet()
            self.icon.set_from_icon_name(
                "takeabreak-symbolic", Gtk.IconSize.MENU
            )
        else:
            self.icon.set_from_icon_name(
                "takeabreakpaused-symbolic", Gtk.IconSize.MENU
            )

    def set_time_fromapplet(self):
        wait = tab_settings.get_int("awaketime") * 60
        currt = time.time()
        newtime = time.strftime("%H:%M", time.localtime(wait + currt))
        self.time_label.set_text(newtime)

    def set_labels(self, state):
        if state:
            try:
                popuptime = open(nextbreakfile).read().split(".")[0]
                ltime = time.localtime(int(popuptime))
                newtime = time.strftime(
                    "%H:%M", time.localtime(int(popuptime))
                )
                self.time_label.set_text(newtime)
            except (FileNotFoundError, UnboundLocalError):
                self.set_time_fromapplet()
        else:
            self.time_label.set_text(".  .  .")

    def reset_app(self, state):
        self.set_labels(state)
        appletpath = os.path.dirname(os.path.abspath(__file__))
        app = os.path.join(appletpath, "takeabreak_run")
        try:
            # I know, old school, but it works well
            pid = subprocess.check_output([
                "pgrep", "-f", "-u", user, app,
            ]).decode("utf-8").strip()
            subprocess.Popen(["kill", pid])
        except subprocess.CalledProcessError:
            pass
        if state:
            return subprocess.Popen(app)

    def on_press(self, box, arg):
        curr_paused = tab_settings.get_boolean("paused")
        self.set_labels(curr_paused is False)
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return BudgieTakeaBreakSettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True
