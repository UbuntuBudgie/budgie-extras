import gi.repository
import subprocess
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk
import os


"""
QuickNote
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
program.  If not, see <https://www.gnu.org/licenses/>.
"""


settingsdir = os.path.join(
    os.environ["HOME"], ".config/budgie-extras/quicknote"
)


undo_steps = 11


try:
    os.makedirs(settingsdir)
except FileExistsError:
    pass


default_pathfile = os.path.join(settingsdir, "quicknote-path")
default_textfile = os.path.join(settingsdir, "quicknotes")
biggerwindow_file = os.path.join(settingsdir, "biggerwindow")


def get_notesdir():
    try:
        path = open(default_pathfile).read().strip()
        textfile = os.path.join(path, "quicknotes")
        custom = True
    except FileNotFoundError:
        textfile = default_textfile
        custom = False
        path = None
    else:
        if not os.path.exists(path):
            textfile = default_textfile
            subprocess.Popen([
                "notify-send",
                "An error occurred in QuickNote",
                "The custom directory was not found, " +
                settingsdir + " will be used for now.",
            ])
    return textfile, custom, path


class BudgieQuickNoteSettings(Gtk.Grid):
    def __init__(self, setting):

        super().__init__()

        self.set_row_spacing(12)
        self.setting = setting
        custom_set = get_notesdir()
        # used path (possibly fixed into default if not available)
        self.notesfile = custom_set[0]
        # bool, is custom set?
        custom = custom_set[1]
        # path, as entered in custom path
        path = custom_set[2]
        # buttons
        self.set_customdir = Gtk.CheckButton("Set a custom directory")
        self.set_root = Gtk.Button("Choose directory")
        self.dir_entry = Gtk.Entry(editable=False)
        if custom:
            self.dir_entry.set_text(path)
        self.set_root.connect("clicked", self.get_directory)
        self.attach(self.set_customdir, 1, 3, 1, 1)
        self.attach(self.set_root, 1, 5, 1, 1)
        self.attach(self.dir_entry, 1, 6, 1, 1)
        self.set_customdir.set_active(custom)
        self.set_customdir.connect("toggled", self.toggle_custom)
        # window size
        self.biggerwindow = os.path.exists(biggerwindow_file)
        self.set_customsize = Gtk.CheckButton("Use a bigger window")
        self.set_customsize.set_active(self.biggerwindow)
        self.set_customsize.connect("toggled", self.set_biggerwindow)
        distance = Gtk.Label("\n")
        self.attach(distance, 1, 8, 1, 1)
        self.attach(self.set_customsize, 1, 9, 1, 1)
        self.show_all()

    def toggle_custom(self, button, val=None):
        if not val:
            val = self.set_customdir.get_active()
        for item in [self.set_root, self.dir_entry]:
            item.set_sensitive(val)
        # not necessarily the same val, now possibly locally defined
        if not val:
            self.dir_entry.set_text("")
            try:
                os.remove(default_pathfile)
            except FileNotFoundError:
                pass

    def set_biggerwindow(self, button):
        newstate = self.set_customsize.get_active()
        if newstate:
            open(biggerwindow_file, "wt").write("")
        else:
            os.remove(biggerwindow_file)

    def get_directory(self, button):
        try:
            directory = subprocess.check_output([
                "zenity", "--file-selection", "--directory",
            ]).decode("utf-8").strip()
        except subprocess.CalledProcessError:
            pass
        else:
            self.dir_entry.set_text(directory)
            open(default_pathfile, "wt").write(directory)


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
        self.uuid = uuid
        self.box = Gtk.EventBox()
        icon = Gtk.Image.new_from_icon_name(
            "budgie-quicknote-symbolic", Gtk.IconSize.MENU,
        )
        self.box.add(icon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        # grid to contain all the stuff
        self.maingrid = Gtk.Grid()
        # the scrolled window
        self.win = Gtk.ScrolledWindow.new()
        self.win.set_vexpand(True)
        self.win.set_hexpand(True)
        # main textbuffer
        self.buffer = Gtk.TextBuffer()
        # undo "buffer 1"
        self.undo_list = []
        self.textfile = get_notesdir()[0]
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
        undo = Gtk.Button.new_from_icon_name(
            'edit-undo-symbolic',
            Gtk.IconSize.BUTTON,
        )
        undo.connect("clicked", self.undo)
        undo.set_relief(Gtk.ReliefStyle.NONE)
        redo = Gtk.Button.new_from_icon_name(
            'edit-redo-symbolic',
            Gtk.IconSize.BUTTON,
        )
        redo.connect("clicked", self.redo)
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
        winsize = self.get_winsize()
        self.win.set_size_request(winsize[0], winsize[1])
        self.textfile = get_notesdir()[0]
        starttext = self.set_starttext()
        self.buffer.set_text(starttext)
        self.manager.show_popover(self.box)

    def get_txt(self, *args):
        start = self.buffer.get_start_iter()
        end = self.buffer.get_end_iter()
        buffer = self.text.get_buffer()
        return buffer.get_text(start, end, True)

    def set_starttext(self):
        try:
            text = open(self.textfile).read()
        except FileNotFoundError:
            text = "Welcome to QuickNote!\n\n" + \
                   "Just replace this text with your " + \
                   "notes. Notes are saved automatically while writing."
        self.undo_list.append(text)
        return text

    def get_winsize(self):
        return (350, 220) if os.path.exists(biggerwindow_file) else (280, 180)

    def manage_undo(self, *args):
        self.back_index = -1
        newtext = self.get_txt()
        self.undo_list.append(newtext)
        self.undo_list = self.undo_list[-undo_steps:]
        open(self.textfile, "wt").write(newtext)

    def undo(self, *args):
        n_edits = len(self.undo_list) - 1
        if abs(self.back_index) < n_edits:
            self.back_index = self.back_index - 1
            reverted = self.undo_list[self.back_index]
            self.buffer.set_text(reverted)
            open(self.textfile, "wt").write(reverted)

    def redo(self, *args):
        if self.back_index < -1:
            self.back_index = self.back_index + 1
            try:
                reverted = self.undo_list[self.back_index]
            except IndexError:
                pass
            else:
                self.buffer.set_text(reverted)
                open(self.textfile, "wt").write(reverted)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)

    def do_get_settings_ui(self):
        """Return the applet settings with given uuid"""
        return BudgieQuickNoteSettings(self.get_applet_settings(self.uuid))

    def do_supports_settings(self):
        """Return True if support setting through Budgie Setting,
        False otherwise.
        """
        return True
