#! /usr/bin/python3

"""
Count Down
Author: Jacob Vlijm
Copyright © 2017 Ubuntu Budgie Developers
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


import os
import gi
gi.require_version('Libxfce4windowing', '0.0')
from gi.repository import Libxfce4windowing
if Libxfce4windowing.windowing_get() == Libxfce4windowing.Windowing.WAYLAND:
    gi.require_version('Budgie', '2.0')
else:
    gi.require_version('Budgie', '1.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Budgie, GObject, GdkPixbuf, Gtk, Gio, GLib
from threading import Thread
import time
import subprocess
import ast


powersettings = Gio.Settings.new(
    "org.gnome.settings-daemon.plugins.power"
)


subs = [
    ["ac", "sleep-inactive-ac-type"],
    ["battery", "sleep-inactive-battery-type"],
]


settingspath = os.path.join(
    os.environ["HOME"], ".config", "budgie-extras", "countdown",
)


try:
    os.makedirs(settingspath)
except FileExistsError:
    pass

# icons
path = "/usr/share/pixmaps"


class CountDown(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieCountDown"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return CountDownApplet(uuid)


class CountDownSettings(Gtk.Grid):

    def __init__(self, setting):

        super().__init__()
        self.show_seconds = True
        self.setting = setting
        # grid & layout
        countdown_spacegrid = Gtk.Grid()
        self.add(countdown_spacegrid)
        for cell in [[0, 0], [100, 0], [0, 100], [100, 100]]:
            countdown_spacegrid.attach(
                Gtk.Label(label="\t"), cell[0], cell[1], 1, 1
            )
        self.space_settings = Gio.Settings(
            schema="org.ubuntubudgie.plugins.budgie-countdown"
        )
        currvalue = self.space_settings.get_int("spacersize")
        space = Gtk.SpinButton()
        space.set_range(0, 50)
        space.set_increments(1, 1)
        space.set_value(currvalue)
        space.connect("value-changed", self.update_value)
        label = Gtk.Label("Built-in spacer" + "\n")
        label.set_xalign(0)
        countdown_spacegrid.attach(label, 1, 1, 2, 1)
        countdown_spacegrid.attach(space, 1, 2, 1, 1)
        self.show_all()

    def update_value(self, spin):
        newval = spin.get_value()
        self.space_settings.set_int("spacersize", newval)


class CountDownApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        self.red_time = 60
        self.yellow_time = 300
        # setup watching applet presence
        self.currpanelsubject_settings = None
        GLib.timeout_add_seconds(1, self.watchout)
        self.countdown_onpanel = True
        # spacesettings
        self.space_settings = Gio.Settings(
            schema="org.ubuntubudgie.plugins.budgie-countdown"
        )
        self.claimed_panelspace = self.space_settings.get_int("spacersize")
        self.space_settings.connect("changed", self.get_currclaimedspace)
        # --- panelgrid/containergrid ---
        self.panelgrid = Gtk.Grid()
        self.panelgrid.set_row_spacing(5)
        self.panelgrid.set_column_spacing(5)
        self.containergrid = Gtk.Grid()
        self.containergrid.attach(self.panelgrid, 1, 1, 1, 1)
        # --- let's initiate some stuff ---
        self.panelspacing = 0
        self.position_index = 0
        # label/spacer position
        self.labelpos = [0, 0, 1, 1]
        self.spacerpos = "top"
        self.grid_helpers = []  # spacer images
        self.labelplacement = 0  # distance
        # icons
        grey = os.path.join(path, "cr_grey.png")
        green = os.path.join(path, "cr_green.png")
        yellow = os.path.join(path, "cr_yellow.png")
        red = os.path.join(path, "cr_red.png")
        # pixbuf
        self.iconset = [
            GdkPixbuf.Pixbuf.new_from_file(ic) for ic in
            [red, yellow, green, grey]
        ]
        # initial icon
        self.seticon = Gtk.Image.new_from_pixbuf(self.iconset[0])
        self.panelgrid.attach(self.seticon, 1, 1, 1, 1)
        # menu label
        self.timer = Gtk.Label(label="00:00:00")
        self.panelgrid.attach(self.timer, 2, 1, 1, 1)
        # --- menugrid ---
        self.menugrid = Gtk.Grid()
        self.menugrid.set_column_spacing(15)
        self.menugrid.set_row_spacing(5)
        # left space
        self.menugrid.attach(Gtk.Label(""), 1, 0, 1, 1)
        # hrs
        self.hrs_label = Gtk.Label("Hours: ", xalign=0)
        self.menugrid.attach(self.hrs_label, 1, 2, 1, 1)
        adjustment = Gtk.Adjustment(0, 0, 23, 1)
        self.hoursbutton = Gtk.SpinButton()
        self.hoursbutton.set_adjustment(adjustment)
        self.menugrid.attach(self.hoursbutton, 2, 2, 1, 1)
        # mins
        self.mins_label = Gtk.Label("Minutes: ", xalign=0)
        self.menugrid.attach(self.mins_label, 1, 3, 1, 1)
        adjustment = Gtk.Adjustment(0, 0, 59, 1)
        self.minsbutton = Gtk.SpinButton()
        self.minsbutton.set_adjustment(adjustment)
        self.menugrid.attach(self.minsbutton, 2, 3, 1, 1)
        # secs
        self.secs_label = Gtk.Label("Seconds: ", xalign=0)
        self.menugrid.attach(self.secs_label, 1, 4, 1, 1)
        adjustment = Gtk.Adjustment(0, 0, 59, 1)
        self.secsbutton = Gtk.SpinButton()
        self.secsbutton.set_adjustment(adjustment)
        self.menugrid.attach(self.secsbutton, 2, 4, 1, 1)
        for sp in [self.hoursbutton, self.minsbutton, self.secsbutton]:
            sp.set_numeric(True)
            sp.set_update_policy(True)
        # prevent pause
        self.sleep = Gtk.CheckButton("Prevent pausing countdown")
        self.menugrid.attach(self.sleep, 1, 6, 2, 1)
        sep = Gtk.Separator()
        self.menugrid.attach(sep, 4, 1, 1, 8)
        self.bbox = Gtk.Box()
        self.menugrid.attach(self.bbox, 0, 10, 9, 2)
        self.menugrid.attach(Gtk.Label(""), 1, 9, 1, 1)
        # apply
        self.applybutton = Gtk.Button("Run")
        # set style start/stop
        self.context_start = self.applybutton.get_style_context()
        self.applybutton.set_size_request(80, 20)
        self.bbox.pack_end(self.applybutton, False, False, 0)
        self.applybutton.connect("clicked", self.handle_apply)
        self.nf_bell = Gtk.CheckButton("Ring bell")
        self.menugrid.attach(self.nf_bell, 5, 2, 1, 1)
        self.nf_icon = Gtk.CheckButton("Flash icon")
        self.menugrid.attach(self.nf_icon, 5, 3, 1, 1)
        self.nf_message = Gtk.CheckButton("Display window")
        self.menugrid.attach(self.nf_message, 5, 4, 1, 1)
        self.runcomm = Gtk.CheckButton("Run command:")
        self.menugrid.attach(self.runcomm, 5, 5, 1, 1)
        self.command_entry = Gtk.Entry()
        self.command_entry.connect("key-release-event", self.update_command)
        self.menugrid.attach(self.command_entry, 5, 6, 1, 1)
        # button, file, related variable-key
        self.settingsdata = [
            [self.nf_bell, "mute_ringbell", "ringbell"],
            [self.nf_icon, "mute_flashicon", "flashicon"],
            [self.nf_message, "mute_showwindow", "showwindow"],
            [self.sleep, "mute_nosleep", "keeprun"],
            [self.runcomm, "runcommand", "runcmd"],
        ]
        self.vals = []
        # fetch values for checkbuttons (except command: separate)
        for item in self.settingsdata[:-1]:
            val = True if self.get_setting(item) is False else False
            subj = item[0]
            item[0].set_active(val)
            self.vals.append(val)
            item[0].connect("toggled", self.manage_checkbox)
        # fetch command if True, set checkbutton
        command_set = self.settingsdata[-1]
        commandval = self.get_setting(command_set, True)
        try:
            data = ast.literal_eval(commandval[1])
        except TypeError:
            self.runcomm.set_active(False)
            self.command_entry.set_sensitive(False)
        else:
            self.runcmd = data[0]
            self.command_entry.set_text(data[1])
            self.runcomm.set_active(self.runcmd)
            self.command_entry.set_sensitive(self.runcmd)
        self.runcomm.connect("toggled", self.manage_checkbox)
        self.runvars = {
            "ringbell": self.vals[0],
            "flashicon": self.vals[1],
            "showwindow": self.vals[2],
            "keeprun": self.vals[3],
            "runcmd": self.runcomm.get_active(),
        }
        self.countdown, self.span = 0, 0
        self.cancel = True
        # panel
        self.box = Gtk.EventBox()
        self.box.add(self.containergrid)
        self.add(self.box)
        # menu
        self.popover = Budgie.Popover.new(self.box)
        self.popover.add(self.menugrid)
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)
        GObject.threads_init()
        # thread
        self.update = Thread(target=self.run_countdown)
        # daemonize the thread to make the indicator stopable
        self.update.setDaemon(True)
        self.update.start()
        self.seticon.set_from_pixbuf(self.iconset[1])

    def watchout(self):
        path = "com.solus-project.budgie-panel"
        panelpath_prestring = "/com/solus-project/budgie-panel/panels/"
        panel_settings = Gio.Settings.new(path)
        allpanels_list = panel_settings.get_strv("panels")
        for p in allpanels_list:
            panelpath = panelpath_prestring + "{" + p + "}/"
            self.currpanelsubject_settings = Gio.Settings.new_with_path(
                path + ".panel", panelpath
            )
            applets = self.currpanelsubject_settings.get_strv("applets")
            if self.uuid in applets:
                self.currpanelsubject_settings.connect(
                    "changed", self.check_ifonpanel
                )
        return False

    def check_ifonpanel(self, *args):
        applets = self.currpanelsubject_settings.get_strv("applets")
        self.countdown_onpanel = self.uuid in applets

    def get_currclaimedspace(self, *args):
        self.claimed_panelspace = self.space_settings.get_int("spacersize")
        if self.spacerpos == "top":
            self.containergrid.set_column_spacing(self.claimed_panelspace)
        else:
            self.containergrid.set_row_spacing(self.claimed_panelspace)

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return CountDownSettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True

    def do_panel_size_changed(self, panelsize, icsize, small_icsize):
        diff = icsize - small_icsize
        # 22 is the used icon size, 3 is an apparent constant
        self.panelspacing = round(
            ((panelsize - icsize) / 2) + ((icsize - 22) / 2) - 3
        )
        self.edit_grid()

    def do_panel_position_changed(self, panelposition):
        if panelposition != Budgie.PanelPosition.NONE:
            panelpositions = [
                Budgie.PanelPosition.RIGHT,
                Budgie.PanelPosition.LEFT,
                Budgie.PanelPosition.BOTTOM,
                Budgie.PanelPosition.TOP,
            ]
            angles = [270, 90, 0, 0]
            self.position_index = panelpositions.index(panelposition)
            if self.position_index > 1:
                self.labelpos = [2, 1, 1, 1]
                self.spacerpos = "top"
                self.timer.set_angle(0)
            else:
                self.labelpos = [1, 2, 1, 1]
                self.spacerpos = "left"
            self.timer.set_angle(angles[self.position_index])
            self.edit_grid()

    def edit_grid(self):
        for img in self.grid_helpers:
            self.containergrid.remove(img)
        spacerpath = "/usr/share/pixmaps/cr_panelspacer.png"
        self.grid_helpers = []
        spacerimg = Gtk.Image.new_from_file(spacerpath)
        built_in_spacer1 = Gtk.Image.new_from_file(spacerpath)
        built_in_spacer2 = Gtk.Image.new_from_file(spacerpath)
        for img in [
            spacerimg, built_in_spacer1, built_in_spacer2,
        ]:
            self.grid_helpers.append(img)
        if self.spacerpos == "left":
            self.containergrid.set_margin_left(3)
            self.containergrid.attach(spacerimg, 0, 1, 1, 1)
            self.containergrid.attach(built_in_spacer1, 1, 0, 1, 1)
            self.containergrid.attach(built_in_spacer2, 1, 2, 1, 1)
            self.containergrid.set_column_spacing(self.panelspacing)
            self.containergrid.set_row_spacing(self.claimed_panelspace)
        else:
            self.containergrid.set_margin_top(3)
            self.containergrid.attach(spacerimg, 1, 0, 1, 1)
            self.containergrid.attach(built_in_spacer1, 0, 1, 1, 1)
            self.containergrid.attach(built_in_spacer2, 2, 1, 1, 1)
            self.containergrid.set_row_spacing(self.panelspacing)
            self.containergrid.set_column_spacing(self.claimed_panelspace)
        # helper left or right, set size, add to self.grid_helpers
        self.panelgrid.remove(self.timer)
        if self.countdown != 0:
            self.panelgrid.attach(
                self.timer,
                self.labelpos[0],
                self.labelpos[1],
                self.labelpos[2],
                self.labelpos[3],
            )
        self.panelgrid.show_all()
        self.containergrid.show_all()

    def get_setting(self, checkbox, readval=False):
        file = os.path.join(settingspath, checkbox[1])
        exists = os.path.exists(file)
        if exists:
            val = open(file).read().strip()
            return exists, val
        else:
            return exists

    def manage_checkbox(self, button):
        newset = button.get_active()
        subject = [r for r in self.settingsdata if r[0] == button][0]
        runvar = subject[2]
        # set the runvar
        self.runvars[runvar] = newset
        # manage file
        file = os.path.join(settingspath, subject[1])
        if runvar in ["ringbell", "flashicon", "showwindow", "keeprun"]:
            if newset is False:
                open(file, "wt").write("")
            else:
                try:
                    os.remove(file)
                except FileNotFoundError:
                    pass
        elif runvar == "runcmd":
            self.command_entry.set_sensitive(newset)
            if newset is False:
                newfile = [False, self.command_entry.get_text()]
                open(file, "wt").write(str(newfile))

    def disable_suspend(self, filename, subkey):
        currval = powersettings.get_string(subkey)
        stored = os.path.join(settingspath, filename)
        open(stored, "wt").write(currval)
        powersettings.set_string(subkey, "nothing")

    def restore_prevset(self, filename, subkey):
        stored = os.path.join(settingspath, filename)
        try:
            prevset = open(stored).read().strip()
        except FileNotFoundError:
            print("failing to reset")
            pass
        else:
            powersettings.set_string(subkey, prevset)

    def two_dg(self, n):
        n = str(n)
        return "0" + n if len(n) == 1 else n

    def calc_timedisplay(self, seconds):
        hrs = self.two_dg(int(seconds / 3600))
        mins = self.two_dg(int((seconds % 3600) / 60))
        secs = self.two_dg(seconds % 60)
        return ":".join([hrs, mins, secs])

    def set_label(self, newlabel):
        GObject.idle_add(
            self.timer.set_text, newlabel,
            priority=GObject.PRIORITY_DEFAULT
        )

    def set_newicon(self, newicon):
        GObject.idle_add(
            self.seticon.set_from_pixbuf, newicon,
            priority=GObject.PRIORITY_DEFAULT
        )

    def lookup_stage(self, countdown):
        return [countdown == 0,
                0 < countdown <= self.red_time,
                self.red_time < countdown <= self.yellow_time,
                self.yellow_time < countdown,
                ].index(True)

    def end_signal(self):
        flash = self.runvars["flashicon"]
        ringbell = self.runvars["ringbell"]
        t = 0
        GObject.idle_add(
            self.applybutton.set_sensitive, False,
            priority=GObject.PRIORITY_DEFAULT
        )
        # set gsettings if self.runvars[keep_run]
        if self.runvars["keeprun"]:
            for s in subs:
                self.restore_prevset(s[0], s[1])
        if not self.cancel:
            if self.runvars["showwindow"]:
                subprocess.Popen([
                    "/usr/bin/zenity", "--info", '--title=CountDown message',
                    "--text=Count Down has ended"
                ])
            wait = any([flash, ringbell])
            bellcmd = [
                "/usr/bin/ogg123", "-q",
                "/usr/share/sounds/freedesktop/stereo/complete.oga"
            ]
            if self.runvars["runcmd"]:
                cmd = self.command_entry.get_text()
                self.run_command(cmd)

            while t < 6:
                if t % 2 == 0:
                    if ringbell:
                        subprocess.Popen(bellcmd)
                    if flash:
                        self.set_newicon(self.iconset[0])
                else:
                    if flash:
                        self.set_newicon(self.iconset[1])
                if wait:
                    time.sleep(0.7)
                t = t + 1
        for item in [
            self.set_state, self.applybutton.set_sensitive
        ]:
            GObject.idle_add(
                item, True,
                priority=GObject.PRIORITY_DEFAULT,
            )
        self.cancel = False

    def run_command(self, command):
        try:
            subprocess.Popen(["/bin/bash", "-c", command])
        except subprocess.CalledProcessError:
            pass

    def get_settime(self):
        return int(sum([
            self.hoursbutton.get_value() * 3600,
            self.minsbutton.get_value() * 60,
            self.secsbutton.get_value(),
        ]))

    def set_state(self, state, *args):
        for widget in [
            self.hoursbutton, self.minsbutton, self.secsbutton,
            self.sleep, self.nf_bell, self.runcomm,
            self.nf_icon, self.nf_message, self.command_entry,
            self.hrs_label, self.secs_label, self.mins_label,
        ]:
            widget.set_sensitive(state)
        if state is True:
            self.context_start.remove_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION)
            self.context_start.add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION)
            self.applybutton.set_label("Run")
            GObject.idle_add(
                self.panelgrid.remove, self.timer,
                priority=GObject.PRIORITY_DEFAULT,
            )
            GObject.idle_add(
                self.panelgrid.set_row_spacing, 10,
                priority=GObject.PRIORITY_DEFAULT,
            )
        else:
            self.applybutton.set_label("Stop")
            self.context_start.remove_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION)
            self.context_start.add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION)
            GObject.idle_add(
                self.panelgrid.attach, self.timer,
                self.labelpos[0], self.labelpos[1],
                self.labelpos[2], self.labelpos[3],
                priority=GObject.PRIORITY_DEFAULT,
            )
            GObject.idle_add(
                self.panelgrid.set_row_spacing, 6,
                priority=GObject.PRIORITY_DEFAULT,
            )
        active = self.runcomm.get_active()
        active = False if not all([active, state]) else True
        GObject.idle_add(
            self.command_entry.set_sensitive, active,
            priority=GObject.PRIORITY_DEFAULT,
        )

    def handle_apply(self, button):
        set_t = self.get_settime()
        self.show_seconds = True
        if self.countdown != 0:
            # cancelling countdown
            self.cancel = True
            self.countdown, self.span = 0, 0
            timelabel = self.calc_timedisplay(self.countdown)
            self.set_label(timelabel)
        elif set_t != 0:
            # starting countdown, if set time > 0
            self.set_state(False)
            self.countdown = set_t + 1
            self.init_t = time.time()
            # time shift to the real time
            self.diff = 0
            self.span = self.countdown
            self.currstate1 = None
            # set gsettings if self.runvars[keep_run]
            if self.runvars["keeprun"]:
                for s in subs:
                    self.disable_suspend(s[0], s[1])

    def update_command(self, entry, *args):
        file = os.path.join(settingspath, "runcommand")
        b_state = self.runcomm.get_active()
        cmd = self.command_entry.get_text()
        newcmd = [b_state, cmd]
        open(file, "wt").write(str(newcmd))

    def run_countdown(self):
        cycle = 9
        self.currstate1 = None
        self.diff = 0
        while self.countdown_onpanel:
            time.sleep(1 - self.diff)
            # see where we are in the time stages
            self.currstate2 = self.lookup_stage(self.countdown)
            if self.currstate2 != self.currstate1:
                if self.currstate2 == 0:
                    self.end_signal()
                self.set_newicon(self.iconset[self.currstate2 - 1])
            if self.countdown != 0:
                self.countdown = self.countdown - 1
                timelabel = self.calc_timedisplay(self.countdown)
                if timelabel is not None:
                    self.set_label(timelabel)
                cycle = cycle + 1
                if cycle == 10:
                    # once per 10 seconds, synchronize with real clock
                    cycle = 0
                    realchange = time.time() - self.init_t
                    theo_change = self.span - self.countdown
                    self.diff = realchange - theo_change
                    self.diff = self.diff if self.diff <= 1 else 1
                else:
                    self.diff = 0
            self.currstate1 = self.currstate2

    def on_press(self, box, arg):
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)
