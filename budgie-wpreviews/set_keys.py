#!/usr/bin/env python3
import ast
import subprocess
import os

"""
Budgie WindowPreviews
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

# the key defining the custom keys
key = [
    "org.gnome.settings-daemon.plugins.media-keys",
    "custom-keybindings",
    "custom-keybinding",
]
# the key defining the default shortcut
def_keys = [
    ["org.gnome.desktop.wm.keybindings", "switch-applications"],
    ["org.gnome.desktop.wm.keybindings", "switch-group"],
]
# the shortcut names to look up in dconf
shortcut_names = ["prv_all", "prv_single"]
# command (main-) line to run previews
aw = os.path.dirname(os.path.abspath(__file__)) + "/wprv"


def get(cmd):
    return subprocess.check_output(cmd).decode("utf-8").strip()


def get_currnames():
    relevant = []
    allnames = []
    try:
        customs = ast.literal_eval(
            get(["gsettings", "get", key[0], key[1]])
        )
    except SyntaxError:
        return [], []
    else:
        for c in customs:
            name = get([
                "gsettings", "get", key[0] + "." + key[2] + ":" + c, "name",
            ]).strip("'")
            if name in shortcut_names:
                relevant.append(c)
            allnames.append(c)
    return allnames, relevant


def remove_custom():
    customs = get_currnames()[0]
    remove = get_currnames()[1]
    newlist = [item for item in customs if item not in remove]
    subprocess.call([
        "gsettings", "set", key[0], key[1], str(newlist),
    ])


def clear_default():
    for k in def_keys:
        # clear the set key so the shortcuts become available
        subprocess.call(["gsettings", "set", k[0], k[1], "[]"])


def reset_default():
    for k in def_keys:
        # restore default shortcut
        subprocess.call(["gsettings", "reset", k[0], k[1]])


def define_keyboard_shortcut(name, command, shortcut):
    # defining keys & strings to be used
    # params example 'open gedit' 'gedit' '<Alt>7'
    subkey1 = ".".join([key[0], key[2]]) + ":"
    item_s = "/" + subkey1[:-1] + "s".replace(".", "/") + "/"
    firstname = "custom"
    # get the current list of custom shortcuts
    getcurrent = get(["gsettings", "get", key[0], key[1]])
    if '@as []' in getcurrent:
        current = []
    else:
        current = ast.literal_eval(getcurrent)
    # make sure the additional keybinding mention is no duplicate
    n = 1
    while True:
        new = item_s + firstname + str(n) + "/"
        if new in current:
            n = n + 1
        else:
            break
    # add the new keybinding to the list
    current.append(new)
    # create the shortcut, set the name, command and shortcut key
    for cmd in ([
        [key[0], key[1], str(current)],
        [subkey1 + new, "name", name],
        [subkey1 + new, "command", command],
        [subkey1 + new, "binding", shortcut],
    ]):
        subprocess.call(["gsettings", "set"] + cmd)


def change_keys(arg):
    # clean up possible duplicates (from unclean stop)
    remove_custom()
    if arg == "set_custom":
        # clean up possible duplicates (from unclean stop)
        clear_default()
        define_keyboard_shortcut("prv_all", aw, '<Alt>Tab')
        define_keyboard_shortcut(
            "prv_single", aw + " current", '<Alt>grave'
        )
    elif arg == "restore":
        reset_default()
