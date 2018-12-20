#!/usr/bin/env python3
import gi
gi.require_version("Gtk", "3.0")
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk, Gio, GdkPixbuf
import os
import dropby_tools as db
import subprocess
import psutil
from threading import Thread


"""
DropBy
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


css_data = """
.label {
  padding-bottom: 7px;
  padding-top: 0px;
  font-weight: bold;
}
"""


app_path = os.path.dirname(os.path.abspath(__file__))
copyscript = os.path.join(app_path, "copy_flash")


class BudgieDropBy(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieDropBy"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieDropByApplet(uuid)


class ClockWorksSettings(Gtk.Grid):

    def __init__(self, setting):

        super().__init__()
        explanation = Gtk.Label(
            "\n\nThe applet icon will appear when a USB device is connected.",
            xalign=0,
        )
        explanation.set_line_wrap(True)
        self.attach(explanation, 0, 0, 1, 1)
        self.show_all()


class BudgieDropByApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.uuid = uuid
        self.connect("destroy", Gtk.main_quit)
        self.box = Gtk.EventBox()
        self.icon = Gtk.Image.new_from_icon_name(
            "budgie-dropby-symbolic", Gtk.IconSize.MENU
        )
        self.idle_icon = Gtk.Image.new_from_icon_name(
            "budgie-dropby-idle", Gtk.IconSize.MENU
        )
        self.provider = Gtk.CssProvider.new()
        self.provider.load_from_data(css_data.encode())
        self.box.add(self.icon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        # grid to contain all the stuff
        self.maingrid = Gtk.Grid()
        # throw it in popover
        self.popover.add(self.maingrid)
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)
        # thread
        GObject.threads_init()
        self.update = Thread(target=self.setup_watching)
        # daemonize the thread to make the indicator stopable
        self.update.setDaemon(True)
        self.update.start()
        self.refresh_from_idle()

    def setup_watching(self):
        self.watchdrives = Gio.VolumeMonitor.get()
        self.triggers = [
            "volume_added", "volume_removed", "mount_added", "mount_removed",
        ]
        for t in self.triggers:
            self.watchdrives.connect(t, self.refresh_from_idle)
        # workaround to only open nautilus on our own action
        self.act_onmount = False
        # make the applet pop up on the event of a new volume
        self.watchdrives.connect("volume_added", self.on_event, self.box)

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return ClockWorksSettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True

    def fill_grid(self, get_relevant, newvol):
        pos = 2
        for d in get_relevant:
            # get icon
            icon = Gtk.Image.new_from_gicon(d["icon"], Gtk.IconSize.MENU)
            # get name
            vol_name = d["name"]
            # mark possible new volume
            addition = " *" if d["volume"] == newvol else ""
            namebutton = Gtk.Button(" " + vol_name + addition, xalign=0)
            namebutton.set_image(icon)
            namebutton.set_always_show_image(True)
            namebutton.set_relief(Gtk.ReliefStyle.NONE)
            self.maingrid.attach(namebutton, 2, pos, 1, 1)
            # show free space
            freespace = Gtk.Label("     " + d["free"], xalign=0)
            self.maingrid.attach(freespace, 3, pos, 1, 1)
            # set gui attributes for mounted volumes
            if d["ismounted"]:
                mount = d["ismounted"]
                vol_path = d["volume_path"]
                if all([mount == newvol, self.act_onmount]):
                    self.open_folder(vol_path)
                    self.act_onmount = False
                eject_button = Gtk.Button()
                eject_button.set_relief(Gtk.ReliefStyle.NONE)
                eject_button.set_image(Gtk.Image.new_from_icon_name(
                    "media-eject-symbolic", Gtk.IconSize.MENU))
                self.maingrid.attach(eject_button, 6, pos, 1, 1)
                if d["flashdrive"]:
                    spacer = Gtk.Label("    ")
                    self.maingrid.attach(spacer, 4, pos, 1, 1)
                    tooltip = "Eject"
                    eject_button.connect("clicked", self.eject_volume, mount)
                    cp_button = Gtk.Button()
                    cp_button.set_image(Gtk.Image.new_from_icon_name(
                        "media-floppy-symbolic", Gtk.IconSize.MENU))
                    cp_button.set_relief(Gtk.ReliefStyle.NONE)
                    cp_button.set_tooltip_text("Make a local copy")
                    cp_button.connect(
                        "clicked", self.copy_flashdrive, vol_path, vol_name,
                    )
                    self.maingrid.attach(cp_button, 5, pos, 1, 1)
                else:
                    tooltip = "Unmount"
                    eject_button.connect("clicked", self.unmount_volume, mount)
                eject_button.set_tooltip_text(tooltip)
                namebutton.set_tooltip_text("Open " + vol_path)
                namebutton.connect("clicked", self.open_folder, vol_path)
            else:
                namebutton.connect("clicked", self.mount_volume, d["volume"])
                tooltip = "Mount and open " + vol_name
                namebutton.set_tooltip_text(tooltip)
            pos = pos + 1
        # create headers
        volume_label = Gtk.Label("  Volume", xalign=0)
        freespace_label = Gtk.Label("    Free   ", xalign=0)
        self.maingrid.attach(volume_label, 2, 1, 1, 1)
        self.maingrid.attach(freespace_label, 3, 1, 1, 1)
        for label in [volume_label, freespace_label]:
            label_cont = label.get_style_context()
            label_cont.add_class("label")
            Gtk.StyleContext.add_provider(
                label_cont,
                self.provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
            )
        self.set_spacers()

    def refresh_from_idle(self, subject=None, newvol=None):
        GObject.idle_add(
            self.refresh, subject, newvol,
            priority=GObject.PRIORITY_DEFAULT,
        )

    def refresh(self, subject=None, newvol=None):
        # empty grid
        for c in self.maingrid.get_children():
            c.destroy()
        # lookup usb drives
        allvols = self.watchdrives.get_volumes()
        get_relevant = db.get_volumes(allvols)
        # decide if we should show or not
        for c in self.box.get_children():
            c.destroy()
        if get_relevant:
            self.box.add(self.icon)
            self.fill_grid(get_relevant, newvol)
        else:
            self.box.add(self.idle_icon)
        self.box.show_all()

    def open_folder(self, *args):
        path = list(args)[-1]
        subprocess.Popen(["xdg-open", path])

    def mount_volume(self, button, vol):
        Gio.Volume.mount(
            vol, Gio.MountMountFlags.NONE, Gio.MountOperation(), None
        )
        self.act_onmount = True

    def unmount_volume(self, button, vol):
        Gio.Mount.unmount(vol, Gio.MountUnmountFlags.NONE, None)

    def eject_volume(self, button, vol):
        Gio.Mount.eject(vol, Gio.MountUnmountFlags.NONE, None)

    def copy_flashdrive(self, button, source, name):
        subprocess.Popen([copyscript, source, name])

    def set_spacers(self):
        """
        lazy choice to set borders
        """
        c = [[0, 0], [100, 0], [0, 100], [100, 100]]
        for n in range(4):
            spacer = Gtk.Label(" " * 8)
            self.maingrid.attach(spacer, c[n][0], c[n][1], 1, 1)
        self.maingrid.show_all()

    def lockscreen_check(self):
        lockproc = "gnome-screensaver-dialog"
        try:
            return lockproc in (p.name() for p in psutil.process_iter())
        except psutil.NoSuchProcess:
            return False

    def scrs_active_check(self):
        cmd = ["gnome-screensaver-command", "-t"]
        try:
            output = subprocess.check_output(cmd).decode("utf-8")
            return not any(char.isdigit() for char in output)
        except Exception:
            return False

    def on_event(self, box, *args):
        if all([
            not self.lockscreen_check(), self.scrs_active_check()
        ]):
            GObject.idle_add(
                self.manager.show_popover, self.box,
                priority=GObject.PRIORITY_DEFAULT,
            )

    def on_press(self, box, arg):
        self.refresh_from_idle()
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)
