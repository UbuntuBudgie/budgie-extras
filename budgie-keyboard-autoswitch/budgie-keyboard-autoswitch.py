#! /usr/bin/python3

"""
Keyboard Auto Switch
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


import os
import gi
gi.require_version('Budgie', '1.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Budgie, GObject, Gtk, Gio
from threading import Thread
import time
import subprocess
import ast
import psutil


settingspath = os.path.join(
    os.environ["HOME"], ".config", "budgie-extras", "langswitch",
)


default_langfile = os.path.join(settingspath, "default_lang")
lang_datafile = os.path.join(settingspath, "lang_data")


try:
    os.makedirs(settingspath)
except FileExistsError:
    pass


class KeyboardAutoSwitch(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "KeyboardAutoSwitch"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)

    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return KeyboardAutoSwitchApplet(uuid)


class KeyboardAutoSwitchApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        # general stuff
        self.key = "org.gnome.desktop.input-sources"
        self.settings = Gio.Settings.new(self.key)
        # menugrid
        self.menugrid = Gtk.Grid()
        self.menugrid.set_row_spacing(5)
        self.menugrid.set_column_spacing(20)
        # left space
        self.menugrid.attach(Gtk.Label("   "), 0, 0, 1, 1)
        # Default language section
        self.menugrid.attach(Gtk.Label(
            "Default layout:", xalign=0), 1, 1, 1, 1
        )
        self.langlist_combo = Gtk.ComboBoxText()
        self.langlist_combo.set_entry_text_column(0)
        self.langlist_combo.set_size_request(185, 20)
        self.menugrid.attach(self.langlist_combo, 1, 2, 1, 1)
        self.menugrid.attach(
            Gtk.Label("\nExceptions: ", xalign=0), 1, 4, 1, 1
        )
        # Exceptions section
        self.exc_combo = Gtk.ComboBoxText()
        self.exc_combo.set_entry_text_column(0)
        self.menugrid.attach(self.exc_combo, 1, 5, 1, 1)
        delete_button = Gtk.Button()
        delete_img = self.seticon = Gtk.Image.new_from_icon_name(
            "user-trash-symbolic", Gtk.IconSize.MENU
        )
        delete_button.set_image(delete_img)
        self.menugrid.attach(delete_button, 2, 5, 1, 1)
        # end spacer
        spacer_end = Gtk.Label("")
        self.menugrid.attach(spacer_end, 3, 10, 1, 1)
        # panel
        self.seticon = Gtk.Image.new_from_icon_name(
            "budgie-keyboard-autoswitch-symbolic", Gtk.IconSize.MENU
        )
        self.box = Gtk.EventBox()
        self.box.add(self.seticon)
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        self.popover.add(self.menugrid)
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)
        # initiate
        try:
            # get the possible existing dict data
            self.langdata = ast.literal_eval(
                open(lang_datafile).read().strip()
            )
        except FileNotFoundError:
            self.langdata = {}
        try:
            # get the possible previously set (and saved) default language
            self.default_lang = open(default_langfile).read().strip()
        except FileNotFoundError:
            lang_index = self.settings.get_uint("current")
            self.default_lang = self.readable_lang(
                self.settings.get_value("sources")[lang_index][1]
            )
        self.langlist_selection_id = self.langlist_combo.connect(
            "changed", self.change_ondeflang_select,
        )
        delete_button.connect("clicked", self.remove_exception)
        self.act_on_gsettingschange()
        self.settings.connect("changed::sources", self.act_on_gsettingschange)
        # thread
        GObject.threads_init()
        # thread
        self.update = Thread(target=self.watch_yourlanguage)
        # daemonize the thread to make the indicator stopable
        self.update.setDaemon(True)
        self.update.start()

    def on_press(self, box, arg):
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.box, self.popover)

    def readable_lang(self, lang):
        lang = lang.split("+")
        try:
            lang[1] = "(" + lang[1] + ")"
        except IndexError:
            return lang[0]
        else:
            return " ".join(lang)

    def lockscreen_check(self):
        lockproc = "gnome-screensaver-dialog"
        try:
            return lockproc in (p.name() for p in psutil.process_iter())
        except psutil.NoSuchProcess:
            return False

    def change_ondeflang_select(self, widget):
        """
        change the default language, update settings file and exceptions list
        """
        self.default_lang = self.langlist_combo.get_active_text()
        open(default_langfile, "wt").write(str(self.default_lang))
        self.clear_deflangkey()
        open(lang_datafile, "wt").write(str(self.langdata))
        self.update_exceptions_gui()

    def clear_deflangkey(self):
        """
        if th newly set default language has any exceptions, they should be
        cleared. there is no point in setting classes as exceptions (anymore)
        then. this function is called on change of the default language from
        the menu.
        """
        # list keys
        keys = list(self.langdata.keys())
        # find index of default lang dict-item
        sub = [
            self.langdata[k]["readable"] for k in keys
        ].index(self.default_lang)
        key = keys[sub]
        # clear the exceptions list of the default language
        self.langdata[key]["classes"] = []

    def remove_wmclass(self, wmclass):
        """
        finds occurrences of wmclass in the lang_data, removes them
        """
        keys = list(self.langdata.keys())
        sub = [self.langdata[k]["classes"] for k in keys]
        for s in sub:
            if wmclass in s:
                index = sub.index(s)
                self.langdata[keys[sub.index(s)]]["classes"].remove(wmclass)
                break
        open(lang_datafile, "wt").write(str(self.langdata))

    def update_langlist_gui(self):
        """
        update the list of languages, as it appears in "Default language"
        -options.
        """
        # disconnect
        self.langlist_combo.disconnect(self.langlist_selection_id)
        # why not fetch from self.raw_langlist?
        readable_list = []
        # delete all entries
        self.langlist_combo.remove_all()
        # add to readable list temporarily to determine index to set
        for k in self.langdata.keys():
            name = self.langdata[k]["readable"]
            readable_list.append(name)
        # add all languages to gui
        for n in readable_list:
            self.langlist_combo.append_text(n)
        # find index
        try:
            index = readable_list.index(self.default_lang)
        except ValueError:
            index = 0
        self.default_lang = readable_list[index]
        open(default_langfile, "wt").write(str(self.default_lang))
        self.langlist_combo.set_active(index)
        # set the connection again
        self.langlist_selection_id = self.langlist_combo.connect(
            "changed", self.change_ondeflang_select,
        )

    def act_on_gsettingschange(self, *args):
        """
        fetch current languages, update language data (dict), remove
        obsolete langs, add new ones. then save the new dict to file.
        """
        # fetch current languages from gsettings
        self.raw_langlist = [
            item[1] for item in self.settings.get_value("sources")
        ]
        # add new languages
        curr_keys = list(self.langdata.keys())
        for l in self.raw_langlist:
            readable = self.readable_lang(l)
            if l not in curr_keys:
                self.langdata[l] = {"classes": [], "readable": readable}
        # remove obsolete languages + data
        for k in curr_keys:
            if k not in self.raw_langlist:
                del self.langdata[k]
        open(lang_datafile, "wt").write(str(self.langdata))
        self.update_langlist_gui()

    def find_exception(self, wmclass):
        """
        search self.langdata for existing exceptions
        """
        keys = self.langdata.keys()
        exist = None
        for k in keys:
            data = self.langdata[k]["classes"]
            if wmclass in data:
                exist = k
                break
        # output = raw lang!
        return exist

    def set_lang_onclasschange(self, wmclass, lang):
        """
        if the wmclass changes (window change), check if an exception exists
        on the wmclass. switch language if lang is not the currently active one
        """
        curr_exception = self.find_exception(wmclass)
        if curr_exception:
            # if the window is an exception, *and* another language; set lang
            if lang != curr_exception:
                self.set_newlang(newlang=curr_exception)
        elif self.readable_lang(lang) != self.default_lang:
            self.set_newlang(default=True)

    def set_newlang(self, newlang=None, default=False):
        """
        switch source for the currently active window
        """
        if newlang:
            index = self.raw_langlist.index(newlang)
        elif default:
            getreadables = [self.readable_lang(l) for l in self.raw_langlist]
            index = getreadables.index(self.default_lang)
        self.settings.set_uint("current", index)

    def lock_state(self, oldlang):
        while True:
            time.sleep(1)
            if not self.lockscreen_check():
                break
        self.set_newlang(oldlang)

    def watch_yourlanguage(self):
        # fill exceptions (gui) list with data
        self.update_exceptions_gui()
        # fetch set initial data
        wmclass1 = self.get_activeclass()
        activelang1 = self.get_currlangname()
        while True:
            time.sleep(1)
            # if language is changed during lockstate, revert afterwards
            if self.lockscreen_check():
                self.lock_state(activelang1)
            wmclass2 = self.get_activeclass()
            activelang2 = self.get_currlangname()
            # first set a few conditions to act *at all*
            if all(
                [wmclass2, wmclass2 != "raven",
                 wmclass2 != "Wprviews_window",
                 activelang2]):
                classchange = wmclass2 != wmclass1
                langchange = activelang2 != activelang1
                if classchange:
                    self.set_lang_onclasschange(wmclass2, activelang2)
                    activelang2 = self.get_currlangname()
                elif langchange:
                    self.set_exception(activelang2, wmclass2)
                    GObject.idle_add(
                        self.update_exceptions_gui,
                        priority=GObject.PRIORITY_DEFAULT,
                    )
                    open(lang_datafile, "wt").write(str(self.langdata))
                wmclass1 = wmclass2
                activelang1 = activelang2

    def update_exceptions_gui(self):
        self.exc_combo.remove_all()
        keys = list(self.langdata.keys())
        for k in keys:
            wmclasses = self.langdata[k]["classes"]
            for cl in wmclasses:
                mention = ", ".join([cl, k])
                self.exc_combo.append_text(mention)
        self.exc_combo.set_active(0)

    def remove_exception(self, button):
        """
        remove an exception from the menu (gui)
        """
        try:
            toremove = self.exc_combo.get_active_text().split(", ")[0]
        except AttributeError:
            pass
        else:
            self.remove_wmclass(toremove)
            self.update_exceptions_gui()

    def set_exception(self, lang, wmclass):
        lang = self.readable_lang(lang)
        # remove possible existing exception
        self.remove_wmclass(wmclass)
        # add new exception
        keys = list(self.langdata.keys())
        sub = [self.langdata[k]["readable"] for k in keys].index(lang)
        if lang != self.default_lang:
            self.langdata[keys[sub]]["classes"].append(wmclass)

    def get(self, cmd):
        try:
            return subprocess.check_output(cmd).decode("utf-8").strip()
        except subprocess.CalledProcessError:
            pass

    def show_wmclass(self, wid):
        # handle special cases
        try:
            cl = self.get([
                "xprop", "-id", wid, "WM_CLASS"
            ]).split("=")[-1].split(",")[-1].strip().strip('"')
        except (IndexError, AttributeError):
            pass
        else:
            # exceptions; one application, multiple WM_CLASS
            if "Thunderbird" in cl:
                return "Thunderbird"
            elif "Toplevel" in cl:
                return "Toplevel"
            else:
                return cl

    def get_activeclass(self):
        # get WM_CLASS of active window
        currfront = self.get(["xdotool", "getactivewindow"])
        return self.show_wmclass(currfront) if currfront else None

    def get_currlangname(self):
        i = self.settings.get_uint("current")
        try:
            return self.raw_langlist[i]
        except IndexError:
            pass
