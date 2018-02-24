#!/usr/bin/env python3
import gi
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk
import os
import subprocess

"""
Hot Corners
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

# config path
dr = os.path.join(os.environ["HOME"], ".config", "budgie-extras", "hotcorners")
# settings file
settings = os.path.join(dr, "hotc_settings")
# user, to make sure all procs run per user
user = os.environ["USER"]
# keypath
dcpath = "/com/solus-project/budgie-panel/applets/"
# pressure- triggerfile
pressure_trig = os.path.join(dr, "usepressure")


def get(cmd):
    try:
        return subprocess.check_output(cmd).decode("utf-8").strip()
    except subprocess.CalledProcessError:
        pass


def getres():
    # get the resolution from wmctrl
    resdata = get(["wmctrl", "-d"])
    res = [int(n) for n in resdata.split()[3].split("x")] if resdata else None
    return res


def get_pressure():
    return os.path.exists(pressure_trig)


def mousepos():
    return Gdk.get_default_root_window().get_pointer()[1:3]


def get_hot(marge, res):
    # ----------------------
    pos = mousepos()
    x_pos = pos[0]
    y_pos = pos[1]

    top, left = marge, marge
    right = res[0] - marge
    bottom = res[1] - marge

    test = [
        x_pos < left,
        x_pos > right,
        y_pos < top,
        y_pos > bottom,
    ]

    matches = [
        all([test[0], test[2]]),
        all([test[1], test[2]]),
        all([test[0], test[3]]),
        all([test[1], test[3]]),
    ]
    try:
        return matches.index(True) + 1
    except ValueError:
        pass


def getkey(string="Hot Corners"):
    # get the specific dconf path, referring to the applet's key
    data = get(["dconf", "dump", dcpath]).splitlines()
    try:
        match = [l for l in data if string in l][0]
        watch = data.index(match) - 3
        return data[watch][1:-1]
    except IndexError:
        pass
