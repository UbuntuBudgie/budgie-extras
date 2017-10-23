import gi.repository

gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk, Gio
import os
import clocktools as clt

"""
Budgie ShowTime
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

css_data = """
.colorbutton {
  border-color: transparent;
  background-color: hexcolor;
  padding: 0px;
  border-width: 1px;
  border-radius: 4px;
}
.colorbutton:hover {
  border-color: hexcolor;
  background-color: hexcolor;
  padding: 0px;
  border-width: 1px;
  border-radius: 4px;
}
"""

colorpicker = os.path.join(clt.app_path, "colorpicker")


class BudgieShowTime(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieShowTime"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieShowTimeApplet(uuid)


class BudgieShowTimeSettings(Gtk.Grid):
    def __init__(self, setting):
        super().__init__()
        self.setting = setting

        # files & colors
        self.tcolorfile = clt.timecolor
        self.dcolorfile = clt.datecolor
        mute_time = clt.mute_time
        mute_date = clt.mute_date
        # grid & layout
        self.set_row_spacing(12)
        element_hsizer1 = self.h_spacer(13)
        self.attach(element_hsizer1, 0, 0, 1, 7)
        element_hsizer2 = self.h_spacer(25)
        self.attach(element_hsizer2, 2, 0, 1, 7)
        # toggle buttons
        self.runtime = Gtk.CheckButton("Show time")
        self.rundate = Gtk.CheckButton("Show date")
        self.runtime.set_active(not os.path.exists(mute_time))
        self.rundate.set_active(not os.path.exists(mute_date))
        self.runtime.connect("toggled", self.toggle_show, mute_time)
        self.rundate.connect("toggled", self.toggle_show, mute_date)
        self.attach(self.runtime, 1, 1, 1, 1)
        self.attach(self.rundate, 1, 2, 1, 1)
        # color buttons & labels
        bholder1 = Gtk.Box()
        self.attach(bholder1, 1, 4, 1, 1)
        self.t_color = Gtk.Button()
        self.t_color.connect("clicked", self.pick_color, self.tcolorfile)
        self.t_color.set_size_request(10, 10)
        bholder1.pack_start(self.t_color, False, False, 0)
        timelabel = Gtk.Label(" Set time color")
        bholder1.pack_start(timelabel, False, False, 0)
        bholder2 = Gtk.Box()
        self.attach(bholder2, 1, 5, 1, 1)
        self.d_color = Gtk.Button()
        self.d_color.connect("clicked", self.pick_color, self.dcolorfile)
        self.d_color.set_size_request(10, 10)
        bholder2.pack_start(self.d_color, False, False, 0)
        datelabel = Gtk.Label(" Set date color")
        bholder2.pack_start(datelabel, False, False, 0)
        labelspacer = self.h_spacer(10)
        self.attach(labelspacer, 1, 6, 1, 1)
        noicon = Gtk.Label("Applet runs \nwithout a panel icon")
        self.attach(noicon, 1, 7, 1, 1)
        self.update_color()
        self.show_all

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

    def toggle_show(self, button, file):
        newstate = button.get_active()
        if newstate:
            try:
                os.remove(file)
            except FileNotGoundError:
                pass
        else:
            open(file, "wt").write("")
        clt.restart_clock()

    def set_css(self, hexcol):
        provider = Gtk.CssProvider.new()
        provider.load_from_data(css_data.replace("hexcolor", hexcol).encode())
        return provider

    def color_button(self, button, hexcol):
        provider = self.set_css(hexcol)
        color_cont = button.get_style_context()
        color_cont.add_class("colorbutton")
        Gtk.StyleContext.add_provider(
            color_cont,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def update_color(self, *args):
        self.tcolor = clt.hexcolor(clt.read_color(self.tcolorfile))
        self.dcolor = clt.hexcolor(clt.read_color(self.dcolorfile))
        self.color_button(self.d_color, self.dcolor)
        self.color_button(self.t_color, self.tcolor)

    def pick_color(self, button, f):
        wdata = clt.get(["wmctrl", "-l"])
        if "ShowTime - set color" not in wdata:
            subprocess = Gio.Subprocess.new([colorpicker, f], 0)
            subprocess.wait_check_async(None, self.update_color)
            self.update_color()


class BudgieShowTimeApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        self.box = Gtk.EventBox()
        self.add(self.box)
        self.show_all()
        clt.restart_clock()

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return BudgieShowTimeSettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True
