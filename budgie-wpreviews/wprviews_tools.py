#!/usr/bin/env python3
import os
import subprocess
import gi
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk, Gio


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

dcpath = "/com/solus-project/budgie-panel/applets/"
plugin_path = os.path.dirname(os.path.abspath(__file__))
shortc_settings = Gio.Settings.new("org.ubuntubudgie.plugins.budgie-wpreviews")


user = os.environ["USER"]
previews_dir = "/tmp"
settings_dir = os.path.join(
    os.environ["HOME"], ".config", "budgie-extras", "previews"
)

previews = os.path.join(
    previews_dir,
    user + "_window-previews",
)

previews_ismuted = os.path.join(settings_dir, "muted")
temp_history = os.path.join(previews_dir, user + "_focus_history")

for dr in [previews_dir, previews, settings_dir]:
    try:
        os.makedirs(dr)
    except FileExistsError:
        pass

ignore = [
    "= _NET_WM_WINDOW_TYPE_DOCK",
    "= _NET_WM_WINDOW_TYPE_DESKTOP",
]


# default resize is v_size, unless w exceeds threshold
max_w = 260
v_size = 160
# strings, to be used in the resize- commands
comm = str(max_w) + "x" + str(v_size)


def getkey():
    # get the specific dconf path, referring to the applet's key
    data = subprocess.check_output([
        "dconf", "dump", dcpath,
    ]).decode("utf-8").splitlines()
    try:
        match = [l for l in data if "Window Previews" in l][0]
        watch = data.index(match) - 3
        return data[watch][1:-1]
    except IndexError:
        pass


def get_area():
    # width of the primary screen.
    dsp = Gdk.Display().get_default()
    prim = dsp.get_primary_monitor()
    return prim.get_geometry().width


def get(cmd):
    # just a helper
    try:
        return subprocess.check_output(cmd).decode("utf-8").strip()
    except (subprocess.CalledProcessError, TypeError, UnicodeDecodeError):
        pass


def get_ws():
    # get current workspace
    try:
        return [l.split()[0] for l in get([
            "wmctrl", "-d"
        ]).splitlines() if "*" in l][0]
    except AttributeError:
        pass


def empty_dir():
    for w in os.listdir(previews):
        path = os.path.join(previews, w)
        os.remove(path)


def get_valid(w_id):
    # see if the window is a valid one (type)
    w_data = get(["xprop", "-id", w_id])
    if w_data:
        return True if not any([t in w_data for t in ignore]) else False
    else:
        return False


def show_wmclass(wid):
    # get WM_CLASS from window- id
    try:
        cl = get(["xprop", "-id", wid, "WM_CLASS"]).split("=")[-1].strip()
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


def get_activeclass():
    # get WM_CLASS of active window
    return show_wmclass(get(["xdotool", "getactivewindow"]))


def get_hex(w_id):
    win = hex(int(w_id))
    return win[:2] + (10 - len(win)) * "0" + win[2:]


def get_wmname(w_id):
    # get WM_NAME from window- id
    return get(["xdotool", "getwindowname", w_id])
