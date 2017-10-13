#!/usr/bin/env python3
import os
import subprocess
import time

"""
Budgie ShowTime
Copyright (C) 2017  Jacob Vlijm
contact: vlijm@planet.nl
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
    os.environ["HOME"], ".config", "budgie-extras", "wallclock"
    )

app_path = "/usr/lib/budgie-desktop/plugins/budgie-showtime"

try:
    os.makedirs(prefspath)
except FileExistsError:
    pass

# files
timecolor = os.path.join(prefspath, "timecolor")
datecolor = os.path.join(prefspath, "datecolor")
mute_time = os.path.join(prefspath, "mute_time")
mute_date = os.path.join(prefspath, "mute_date")
clock = os.path.join(app_path, "WallClock")
panelrunner = os.path.join(app_path, "bshowtime_panelrunner")

def get(command):
    try:
        return subprocess.check_output(command).decode("utf-8").strip()
    except subprocess.CalledProcessError:
        pass

def get_pid(proc):
    return get(["pgrep", "-f", proc]).splitlines()

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
            xy_data = windata[windata.index("primary")+1].split("x")
            return int(xy_data[0]), int(xy_data[1].split("+")[0])
            break
        except AttributeError:
            pass
        time.sleep(1)

def read_color(f):
    try:
        return [int(n) for n in open(f).read().splitlines()]
    except FileNotFoundError:
        return [65535, 65535, 65535]

def write_settings(file, newval):
    subj = os.path.join(prefspath, file)
    open(subj, "wt").write(newval)

def hexcolor(rgb):
    c = [int((int(n)/65535)*255) for n in rgb]
    return '#%02x%02x%02x' % (c[0], c[1], c[2])
