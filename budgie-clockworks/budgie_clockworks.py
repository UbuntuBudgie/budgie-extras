import gi

gi.require_version("Gtk", "3.0")
gi.require_version('Budgie', '1.0')
from gi.repository import Gdk, Gtk, GObject, GdkPixbuf, Budgie, Gio
import os
import time
from threading import Thread
import math
import subprocess
import ast
import gi.repository
import cwtools as cw

"""
ClockWorks
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

# paths
home = cw.home
settingsdir = cw.settingsdir
hrs_path = cw.hrs_path
mins_path = cw.mins_path
clock_datafile = cw.clock_datafile
app_path = os.path.dirname(os.path.abspath(__file__))

# make sure directories exist
for dr in [hrs_path, mins_path]:
    try:
        os.makedirs(dr)
    except FileExistsError:
        pass

hours = []
minutes = []
tz_data = cw.tz_data
settings = cw.settings

# create images
cw.create_set()

for n in range(60):
    # hours
    newhrpath = os.path.join(hrs_path, str(n) + ".png")
    hours.append(GdkPixbuf.Pixbuf.new_from_file(newhrpath))
    # minutes
    newminspath = os.path.join(mins_path, str(n) + ".png")
    minutes.append(GdkPixbuf.Pixbuf.new_from_file(newminspath))

clw_css_data = """
.label {
  padding-bottom: 5px;
  padding-top: 5px;
  font-weight: bold;
}
"""

clw_colordata = """
.colorbutton {
  border-color: transparent;
  padding: 0px;
  border-width: 10px;
  border-radius: 4px;
}
.colorbutton:hover {
  border-color: transparent;
  padding: 0px;
  border-width: 10px;
  border-radius: 4px;
}
"""


class BudgieClockWorks(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieClockWorks"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieClockWorksApplet(uuid)


class ClockWorksSettings(Gtk.Grid):

    def __init__(self, setting):

        super().__init__()

        # grid & layout
        self.set_row_spacing(12)
        element_hsizer1 = self.h_spacer(13)
        self.attach(element_hsizer1, 0, 0, 1, 7)
        element_hsizer2 = self.h_spacer(25)
        self.attach(element_hsizer2, 2, 0, 1, 7)
        # color buttons & labels
        self.clockworks_colorbuttons = []
        labels = ["Frame color", "Hours color", "Minutes color"]
        self.initial_colors = [
            cw.prepare_rgb(hx) for hx in cw.get_current_colors()
        ]
        for n in range(3):
            # get color
            buttoncolor = self.initial_colors[n]
            color = Gdk.RGBA()
            color.red = buttoncolor[0] / 255
            color.green = buttoncolor[1] / 255
            color.blue = buttoncolor[2] / 255
            color.alpha = 1
            b_container = Gtk.Box()
            self.attach(b_container, 1, 4 + n, 1, 1)
            colorbutton = Gtk.ColorButton()
            colorbutton.set_rgba(color)
            self.set_buttonstyle(colorbutton)
            self.clockworks_colorbuttons.append(colorbutton)
            colorbutton.connect("color-set", self.pick_color, n)
            colorbutton.set_size_request(10, 10)
            b_container.pack_start(colorbutton, False, False, 0)
            label = Gtk.Label("\t" + labels[n])
            b_container.pack_start(label, False, False, 0)
        self.show_all()

    def pick_color(self, button, color_index):
        subs = cw.subkeys
        newcolor = button.get_rgba()
        r = round(newcolor.red * 255)
        g = round(newcolor.green * 255)
        b = round(newcolor.blue * 255)
        hx = cw.rgb2hex(r, g, b)
        cw.save_togsettings(hx, subs[color_index])

    def h_spacer(self, addwidth):
        # horizontal spacer
        spacegrid = Gtk.Grid()
        if addwidth:
            label1 = Gtk.Label()
            label2 = Gtk.Label()
            spacegrid.attach(label1, 0, 0, 1, 1)
            spacegrid.attach(label2, 1, 0, 1, 1)
            spacegrid.set_column_spacing(addwidth)
        return spacegrid

    def set_buttonstyle(self, button):
        provider = Gtk.CssProvider.new()
        provider.load_from_data(
            clw_colordata.encode())
        color_cont = button.get_style_context()
        color_cont.add_class("colorbutton")
        Gtk.StyleContext.add_provider(
            color_cont,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )


class BudgieClockWorksApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        self.connect("destroy", Gtk.main_quit)
        self.settings = cw.settings
        icon = Gtk.Image.new_from_icon_name(
            "budgie-clockworks-symbolic", Gtk.IconSize.MENU
        )
        self.provider = Gtk.CssProvider.new()
        self.provider.load_from_data(clw_css_data.encode())
        # maingrid
        self.maingrid = Gtk.Grid()
        self.maingrid.set_row_spacing(2)
        self.maingrid.attach(Gtk.Label(" " * 10), 0, 0, 1, 1)
        self.maingrid.set_column_spacing(5)
        self.clocklist = {}
        # create initial clock if it does not exists
        currcl_data = self.read_datafile()
        if currcl_data:
            for cl in currcl_data:
                off = cl[1]
                clname = cl[2]
                self.create_newclock(offset=off, clockname=clname)
        else:
            self.create_newclock(offset=0)
        self.dashbuttonbox = Gtk.Box()
        self.add_button = Gtk.Button()
        self.add_button.set_relief(Gtk.ReliefStyle.NONE)
        self.add_icon = Gtk.Image.new_from_icon_name(
            "list-add-symbolic", Gtk.IconSize.MENU
        )
        self.add_button.set_image(self.add_icon)
        self.search_button = Gtk.Button()
        self.search_button.set_relief(Gtk.ReliefStyle.NONE)
        self.search_icon = Gtk.Image.new_from_icon_name(
            "system-search-symbolic", Gtk.IconSize.MENU
        )
        self.search_button.set_image(self.search_icon)
        self.add_button.connect("clicked", self.create_newclock)
        self.search_button.connect("clicked", self.run_search)
        self.maingrid.attach(self.add_button, 100, 3, 1, 1)
        self.maingrid.attach(self.search_button, 100, 4, 1, 1)
        # throw it in popover
        self.box = Gtk.EventBox()
        self.box.add(icon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        self.popover.add(self.maingrid)
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)
        self.settings.connect("changed", self.update_clockcolor)
        # thread
        GObject.threads_init()
        self.update = Thread(target=self.update_gmt)
        # daemonize the thread to make the indicator stopable
        self.update.setDaemon(True)
        self.update.start()

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return ClockWorksSettings(self.get_applet_settings(self.uuid))

    def update_clockcolor(self, key, sub):
        subs = cw.subkeys
        newcolor = settings.get_string(subs[subs.index(sub)])
        if sub == "background":
            cw.create_bg(newcolor)
            keys = list(self.clocklist.keys())
            for k in keys:
                newbg = Gtk.Image.new_from_file(
                    os.path.join(cw.misc_dir, "background_image.png")
                )
                old = self.clocklist[k]["misc_widgets"][0]
                old.destroy()
                self.maingrid.attach(newbg, k, 1, 1, 5)
                self.clocklist[k]["misc_widgets"][0] = newbg
            self.maingrid.show_all()
        elif sub == "hour":
            cw.create_hours(newcolor)
            for n in range(60):
                newhrpath = os.path.join(hrs_path, str(n) + ".png")
                hours.append(GdkPixbuf.Pixbuf.new_from_file(newhrpath))
            self.refresh_clocks()
        elif sub == "minute":
            cw.create_minutes(newcolor)
            for n in range(60):
                newminspath = os.path.join(mins_path, str(n) + ".png")
                minutes.append(GdkPixbuf.Pixbuf.new_from_file(newminspath))
            self.refresh_clocks()

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True

    def run_search(self, button):
        subprocess.Popen(
            ["xdg-open", "https://www.timeanddate.com/time/map/"]
        )

    def double_digits(self, t):
        digits = len(t)
        return ((2 - digits) * "0") + t if digits < 2 else t

    def convert_offset_tolabel(self, offset):
        if offset != 0:
            prestring = "-" if offset < 0 else "+"
            set_time_hrs = self.double_digits(str(int(abs(offset) / 3600)))
            set_time_mins = self.double_digits(str(int((offset % 3600) / 60)))
            return prestring + set_time_hrs + ":" + set_time_mins
        else:
            return "00:00"

    def convert_label_tooffset(self, label):
        newval = label.split(":")
        hrs_offset = int(newval[0]) * 3600
        mins_offset = int(newval[1]) * 60
        mins_offset = mins_offset if hrs_offset > 0 else -mins_offset
        return (hrs_offset + mins_offset)

    def save_tofile(self):
        store_data = []
        for k in self.clocklist.keys():
            store_data.append([
                k, self.clocklist[k]["offset"],
                self.clocklist[k]["clocklabel"],
            ])
        open(clock_datafile, "wt").write(str(store_data))

    def read_datafile(self):
        try:
            return ast.literal_eval(open(clock_datafile).read().strip())
        except (FileNotFoundError, SyntaxError):
            pass

    def create_newclock(self, *args, offset=0, clockname=None):
        clockkeys = list(self.clocklist.keys())
        try:
            clock_id = max(list(clockkeys)) + 1
        except ValueError:
            clock_id = 1
        # set clock image
        bg = Gtk.Image.new_from_file(
            os.path.join(cw.misc_dir, "background_image.png")
        )
        # initial minute- image
        minute_image = Gtk.Image.new_from_pixbuf(minutes[0])
        # initial hour- imag
        hour_image = Gtk.Image.new_from_pixbuf(hours[0])
        for widget in [bg, minute_image, hour_image]:
            self.maingrid.attach(widget, clock_id, 1, 1, 5)
        # am/pm label
        ampm_label = Gtk.Label(xalign=0.5)
        # delete_clock -box + button
        trashbox = Gtk.Box()
        delete_button = Gtk.Button()
        delete_button.set_image(Gtk.Image.new_from_icon_name(
            "user-trash-symbolic", Gtk.IconSize.MENU)
        )
        delete_button.set_relief(Gtk.ReliefStyle.NONE)
        trashbox.pack_end(delete_button, False, False, 0)
        self.maingrid.attach(trashbox, clock_id, 0, 1, 1)
        self.maingrid.attach(ampm_label, clock_id, 6, 1, 1)
        # timezonbe label, up- down buttons
        offset_down = Gtk.Button()
        offset_down.set_image(
            Gtk.Image.new_from_icon_name(
                "pan-down-symbolic", Gtk.IconSize.MENU
            )
        )
        offset_down.set_relief(Gtk.ReliefStyle.NONE)
        offset_up = Gtk.Button()
        offset_up.set_image(
            Gtk.Image.new_from_icon_name(
                "pan-up-symbolic", Gtk.IconSize.MENU
            )
        )
        offset_up.set_relief(Gtk.ReliefStyle.NONE)
        timezone_time = Gtk.Label(xalign=0.5)
        timezone_time.set_text(self.convert_offset_tolabel(offset))
        timezone_time.set_width_chars(6)
        timezone_box = Gtk.Box(Gtk.BaselinePosition.CENTER)
        timezone_box.set_spacing(0)
        self.maingrid.attach(timezone_box, clock_id, 7, 1, 1)
        timezone_box.pack_start(offset_down, False, False, 0)
        timezone_box.pack_start(timezone_time, False, False, 0)
        timezone_box.set_center_widget(timezone_time)
        timezone_box.pack_start(offset_up, False, False, 0)
        # label entry
        clockname_label = Gtk.Entry()
        clockname_label.set_max_width_chars(15)
        clockname_label.set_width_chars(15)
        clockname_label.set_placeholder_text("Clock label")
        clockname_label.set_alignment(0.5)
        self.maingrid.attach(clockname_label, clock_id, 8, 1, 1)
        if clockname:
            clockname_label.set_text(clockname)
        else:
            clockname = ""
        offset_down.connect("pressed", self.set_down, clock_id, timezone_time)
        offset_up.connect("pressed", self.set_up, clock_id, timezone_time)
        delete_button.connect("pressed", self.delete_clock, clock_id)
        clockname_label.connect("changed", self.set_clockname, clock_id)

        label_cont = clockname_label.get_style_context()
        label_cont.add_class("label")
        Gtk.StyleContext.add_provider(
            label_cont,
            self.provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )
        self.maingrid.show_all()
        # update clockdata
        self.clocklist[clock_id] = {
            "hour_img": hour_image,
            "minute_img": minute_image,
            "misc_widgets": [
                bg, delete_button, trashbox, delete_button, offset_down,
                offset_up, timezone_time, timezone_box, clockname_label,
            ],
            "offset": offset,
            "clockname_label": clockname_label,
            "clocklabel": clockname,
            "ampm": ampm_label,
        }

        # save new data to file, refresh interface
        self.save_tofile()
        curr_time = time.time()
        self.refresh_clocks(curr_time)

    def waitfornext(self):
        # fetch current epoch and time until next minute (break time - 1 sec)
        startt = time.time()
        wait = 61 - (int(startt) % 60)
        return startt, wait

    def update_images(self, t, clockdata):
        # single clock update of images
        offset = clockdata["offset"]
        showtime = (t + offset)
        # am/pm?
        am = "a.m." if showtime % 86400 < 43200 else "p.m."
        # defining time to find image-indexes, images
        hour = int((showtime % 43200) / 720)
        minute = int((showtime % 3600) / 60)
        hr_index = 60 - hour if hour != 0 else 0
        min_index = 60 - minute if minute != 0 else 0
        # update images
        clockdata["hour_img"].set_from_pixbuf(hours[hr_index - 60])
        clockdata["minute_img"].set_from_pixbuf(minutes[min_index - 60])
        set_ampm = clockdata["ampm"]
        set_ampm.set_text(am)
        self.show_all()

    def refresh_clocks(self, currepoch=None):
        currepoch = currepoch if currepoch else time.time()
        # refresh all widgets
        for clockdata in [self.clocklist[k] for k in self.clocklist.keys()]:
            GObject.idle_add(
                self.update_images, currepoch, clockdata,
                priority=GObject.PRIORITY_DEFAULT,
            )

    def update_gmt(self):
        # The loop, sleep is set automaically (appr 1 minute after first cycle)
        while True:
            timedata = self.waitfornext()
            curr_time = timedata[0]
            self.refresh_clocks(curr_time)
            time.sleep(timedata[1])

    def set_down(self, button, clock, label):
        # set previous step in timeshift
        self.set_timeshift(button, clock, label, down=True)

    def set_up(self, button, clock, label):
        # set next step in timeshift
        self.set_timeshift(button, clock, label, down=False)

    def set_timeshift(self, button, clock, label, down):
        # sets the time shift on combo change
        curr_offset = self.clocklist[clock]["offset"]
        nxt = -1 if down else +1
        newindex = tz_data.index(
            self.convert_offset_tolabel(curr_offset)
        ) + nxt
        newindex = 0 if newindex < 0 else newindex
        try:
            newlabel = tz_data[newindex]
        except IndexError:
            newlabel = tz_data[-1]
        label.set_text(newlabel)
        self.clocklist[clock]["offset"] = self.convert_label_tooffset(newlabel)
        curr_time = time.time()
        self.refresh_clocks(curr_time)
        self.save_tofile()

    def set_clockname(self, entry, clock):
        # set the time shift on combo change
        newlabel = entry.get_text()
        self.clocklist[clock]["clocklabel"] = newlabel
        self.save_tofile()

    def delete_clock(self, button, clock):
        if len(self.clocklist) > 1:
            # delete the clock; data and all corresponding widgets
            misc_widgets = self.clocklist[clock]["misc_widgets"]
            hour_image = self.clocklist[clock]["hour_img"]
            minute_image = self.clocklist[clock]["minute_img"]
            ampm_mention = self.clocklist[clock]["ampm"]
            for w in misc_widgets + [hour_image, minute_image, ampm_mention]:
                w.destroy()
            del self.clocklist[clock]
            self.save_tofile()

    def on_press(self, box, arg):
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)
