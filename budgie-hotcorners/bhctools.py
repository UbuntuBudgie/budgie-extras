#!/usr/bin/env python3
import os
import subprocess

"""
Budgie Hot Corners
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

# config path
dr = os.path.join(os.environ["HOME"], ".config", "budgie-extras", "hotcorners")
# settings file
settings = os.path.join(dr, "hotc_settings")


# main script

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


def mousepos():
    # get mouseposition
    try:
        pos = get(["xdotool", "getmouselocation"]).split()
    except AttributeError:
        return 0, 0
    else:
        return int(pos[0].split(":")[1]), int(pos[1].split(":")[1])


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
