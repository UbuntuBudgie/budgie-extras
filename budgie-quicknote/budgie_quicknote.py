import gi.repository

gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk
import os

"""
Budgie WallpaperSwitcher
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

settingsdir = os.path.join(os.environ["HOME"],
                           ".config/budgie-extras/quicknote")
undo_steps = 11

try:
    os.makedirs(settingsdir)
except FileExistsError:
    pass

textfile = os.path.join(settingsdir, "quicknote-data")

css_data = """
.moverwindow {
    background-color: #404552;
}
.moverbutton {
  color: white;
  border-radius: 20px;
  border: 0px;
}
"""


class BudgieQuickNote(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "BudgieQuickNote"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return BudgieQuickNoteApplet(uuid)


class BudgieQuickNoteApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.box = Gtk.EventBox()
        icon = Gtk.Image.new_from_icon_name(
            "budgie-quicknote-panel",
            Gtk.IconSize.MENU,
        )

        provider = Gtk.CssProvider.new()
        provider.load_from_data(css_data.encode())

        self.box.add(icon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        # grid to contain all the stuff
        self.maingrid = Gtk.Grid()
        rcontext = self.maingrid.get_style_context()
        rcontext.add_class("moverwindow")
        Gtk.StyleContext.add_provider(rcontext,
                                      provider,
                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        # the scrolled window
        self.win = Gtk.ScrolledWindow.new()
        self.win.set_size_request(280, 180)
        self.win.set_vexpand(True)
        self.win.set_hexpand(True)
        # main textbuffer
        self.buffer = Gtk.TextBuffer()
        # undo "buffer 1"
        self.undo_list = []
        self.currtext = self.set_starttext()
        self.back_index = -1
        # initial_text
        starttext = self.set_starttext()
        self.buffer.set_text(starttext)
        # textview
        self.text = Gtk.TextView.new_with_buffer(self.buffer)
        self.text.connect("key-release-event", self.manage_undo)
        self.text.set_left_margin(20)
        self.text.set_top_margin(20)
        self.text.set_right_margin(20)
        self.text.set_bottom_margin(20)
        self.win.add(self.text)
        self.text.set_wrap_mode(Gtk.WrapMode.WORD)
        # buttonbox / buttons
        bbox = Gtk.ButtonBox()
        bbox.set_layout(Gtk.ButtonBoxStyle.CENTER)
        undo = Gtk.Button.new_from_icon_name('edit-undo-symbolic',
                                             Gtk.IconSize.BUTTON)
        undo.connect("clicked", self.undo)
        bcontext = undo.get_style_context()
        bcontext.add_class("moverbutton")
        Gtk.StyleContext.add_provider(rcontext,
                                      provider,
                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        undo.set_relief(Gtk.ReliefStyle.NONE)
        redo = Gtk.Button.new_from_icon_name('edit-redo-symbolic',
                                             Gtk.IconSize.BUTTON)
        redo.connect("clicked", self.redo)
        rcontext = redo.get_style_context()
        rcontext.add_class("moverbutton")
        redo.set_relief(Gtk.ReliefStyle.NONE)
        bbox.pack_start(undo, False, False, 0)
        bbox.pack_start(redo, False, False, 0)
        # throw it in maingrid
        self.maingrid.attach(bbox, 0, 1, 1, 1)
        self.maingrid.attach(self.win, 0, 0, 1, 1)
        # throw it in popover
        self.popover.add(self.maingrid)
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)

    def on_press(self, box, arg):
        self.manager.show_popover(self.box)

    def get_txt(self, *args):
        start = self.buffer.get_start_iter()
        end = self.buffer.get_end_iter()
        buffer = self.text.get_buffer()
        return buffer.get_text(start, end, True)

    def set_starttext(self):
        try:
            text = open(textfile).read()
        except FileNotFoundError:
            text = "Welcome to QuickNote!\n\n" + \
                   "Just replace this text with your " + \
                   "notes. Notes are saved automatically while writing."
        self.undo_list.append(text)
        return text

    def manage_undo(self, *args):
        self.back_index = -1
        newtext = self.get_txt()
        self.undo_list.append(newtext)
        self.undo_list = self.undo_list[-undo_steps:]
        open(textfile, "wt").write(newtext)

    def undo(self, *args):
        n_edits = len(self.undo_list) - 1
        if abs(self.back_index) < n_edits:
            self.back_index = self.back_index - 1
            reverted = self.undo_list[self.back_index]
            self.buffer.set_text(reverted)
            open(textfile, "wt").write(reverted)

    def redo(self, *args):
        if self.back_index < -1:
            self.back_index = self.back_index + 1
            try:
                reverted = self.undo_list[self.back_index]
            except IndexError:
                pass
            else:
                self.buffer.set_text(reverted)
                open(textfile, "wt").write(reverted)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)
