#!/usr/bin/env python3
import os
import subprocess
import time
import gi
gi.require_version("Pango", "1.0")
gi.require_version('Gdk', '3.0')
from gi.repository import Pango, Gdk


"""
Budgie WindowMover
Author: Jacob Vlijm
Copyright © 2017-2020 Ubuntu Budgie Developers
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

settings_path = os.path.join(
    os.environ["HOME"], ".config", "budgie-extras", "wmover"
)

user = os.environ["USER"]
fpath = "/tmp/" + user + "_wmover_busy"
appletpath = os.path.dirname(os.path.abspath(__file__))
wmover_ismuted = os.path.join(settings_path, "muted")

try:
    os.makedirs(settings_path)
except FileExistsError:
    pass

# wm_classes to be ignored
ignore = [
    '"budgie-panel", "Budgie-panel"',
    '"desktop_window", "Nautilus"',
    '"plank", "Plank"',
    None,
]


def get(cmd):
    try:
        return subprocess.check_output(cmd).decode("utf-8")
    except subprocess.CalledProcessError:
        pass


def show_wmclass(wid):
    # get WM_CLASS from window- id
    try:
        return get([
            "/usr/bin/xprop",
            "-id", wid,
            "WM_CLASS"
        ]).split("=")[-1].strip()
    except (IndexError, AttributeError):
        pass


def get_wsdata():
    wsdata = get(["/usr/bin/wmctrl", "-d"]).splitlines()
    return (len(wsdata), wsdata.index([l for l in wsdata if "*" in l][0]))


def run(cmd):
    try:
        subprocess.Popen(cmd)
    except TypeError:
        pass


def check_ypos(yres):
    # get active window, check y- position
    name = None
    try:
        subj = get(["xdotool", "getactivewindow"])
        ydata = get(["xdotool", "getwindowgeometry", subj])
        name = get(["xdotool", "getwindowname", subj])
    except (subprocess.CalledProcessError, TypeError):
        return False, None
    else:
        if name not in ["dropby_popup"]:
            ypos = int(
                [l for l in ydata.splitlines()
                 if "Position" in l][0].split(",")[1].split()[0]
            )
            return ypos > yres - 300, subj.strip()


def getres():
    dsp = Gdk.Display.get_default()
    prim = dsp.get_primary_monitor()
    geo = prim.get_geometry()
    xoffset = geo.x
    yoffset = geo.y
    width = geo.width
    height = geo.height
    return (width, height, xoffset, yoffset)


def area(x_area, y_area, xres, yres, x, y, xoffset, yoffset):
    # see if the mouse is in the hotspot
    center = xres / 2
    halfwidth = x_area / 2
    x_match = center + xoffset - halfwidth < x < center + xoffset + halfwidth
    y_match = y > yres + yoffset - y_area
    return all([x_match, y_match])


def mousepos():
    return Gdk.get_default_root_window().get_pointer()[1:3]


def find_bar():
    return get(["xdotool", "search", "--class", "wmover"])


def callwindow(target, xres, yres, xoffset, yoffset):
    wtype = show_wmclass(target)
    if wtype in ignore:
        run(["/usr/bin/notify-send", "-i", "wmover-panel",
             "WindowMover", "Please first activate a window."])
    else:
        runwindow(target, xres, yres, xoffset, yoffset)


def runwindow(target, xres, yres, xoffset, yoffset):
    # run the mover bar
    subprocess.Popen([
        os.path.join(appletpath, "moverbar"),
        target,
        str(xres),
        str(yres),
        str(xoffset),
        str(yoffset),
    ])
    time.sleep(0.5)
    limit_exist()


def get_font():
    key = ["org.gnome.desktop.wm.preferences", "titlebar-font"]
    fontdata = get(["/usr/bin/gsettings", "get", key[0], key[1]]).strip("'")
    fdscr = Pango.FontDescription(fontdata)
    return Pango.FontDescription.get_family(fdscr)


def limit_exist():
    # make sure the bar stays on top *and* active, allow 5 seconds
    t = 1
    while True:
        time.sleep(1)
        if t >= 5:
            run(["/usr/bin/wmctrl", "-ic", find_bar()])
            break
        else:
            try:
                if "w_moversplash" in get(["/usr/bin/wmctrl", "-l"]):
                    run(["/usr/bin/wmctrl", "-a", "w_moversplash"])
                else:
                    break
            except TypeError:
                pass

        if os.path.exists(fpath):
            t = 1
            os.remove(fpath)
        else:
            t = t + 1
