#!/usr/bin/env python3
import os
import subprocess
import time
import gi
gi.require_version('Pango', '1.0')
from gi.repository import Pango

"""
Budgie ShowTime
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
program.  If not, see <http://www.gnu.org/licenses/>.
"""

# paths
prefspath = os.path.join(
    os.environ["HOME"], ".config", "budgie-extras", "showtime"
)

app_path = os.path.dirname(os.path.abspath(__file__))
user = os.environ["USER"]


try:
    os.makedirs(prefspath)
except FileExistsError:
    pass

# files
timecolor = os.path.join(prefspath, "timecolor")
datecolor = os.path.join(prefspath, "datecolor")
mute_time = os.path.join(prefspath, "mute_time")
mute_date = os.path.join(prefspath, "mute_date")
pos_file = os.path.join(prefspath, "position")
clock = os.path.join(app_path, "ShowTime")
panelrunner = os.path.join(app_path, "bshowtime_panelrunner")


def get(command):
    try:
        return subprocess.check_output(command).decode("utf-8").strip()
    except subprocess.CalledProcessError:
        pass


def get_pid(proc):
    return get(["pgrep", "-f", "-u", user, proc]).splitlines()


def restart_clock():
    for proc in [clock, panelrunner]:
        try:
            for p in get_pid(proc):
                subprocess.Popen(["kill", p])
        except AttributeError:
            pass
    subprocess.Popen(panelrunner)


def get_area():
    # size of the primary screen. Too bad we can't use wmctrl. xrandr is slower
    windata = None
    while not windata:
        try:
            windata = get("xrandr").split()
            xy_data = windata[windata.index("primary") + 1].split("x")
            return int(xy_data[0]), int(xy_data[1].split("+")[0])
            break
        except AttributeError:
            pass
        time.sleep(1)


def get_textposition():
    try:
        pos = [int(p) for p in open(pos_file).readlines()][:2]
        x = pos[0]
        y = pos[1]
        custom = True
    except (FileNotFoundError, ValueError, IndexError):
        scr = get_area()
        x = (scr[0] * 0.75) - 100
        y = scr[1] * 0.75
        custom = False
    return (custom, x, y)


def read_color(f):
    try:
        return [int(n) for n in open(f).read().splitlines()]
    except FileNotFoundError:
        return [65535, 65535, 65535]


def write_settings(file, newval):
    subj = os.path.join(prefspath, file)
    open(subj, "wt").write(newval)


def hexcolor(rgb):
    c = [int((int(n) / 65535) * 255) for n in rgb]
    return '#%02x%02x%02x' % (c[0], c[1], c[2])


def get_font():
    key = ["org.gnome.desktop.wm.preferences", "titlebar-font"]
    fontdata = get(["gsettings", "get", key[0], key[1]]).strip("'")
    fdscr = Pango.FontDescription(fontdata)
    return Pango.FontDescription.get_family(fdscr)
