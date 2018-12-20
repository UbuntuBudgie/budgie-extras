#!/usr/bin/env python3

"""
Workspace Overview
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

import subprocess
from itertools import groupby
from operator import itemgetter

# wm_classes to be ignored
ignore = [
    '"budgie-panel", "Budgie-panel"', '"desktop_window", "Nautilus"',
    '"plank", "Plank"', '"Showtime", "showtime"', None,
]


def get(cmd):
    # just a helper. (re-) try/except for buggy wmctrl
    try:
        return subprocess.check_output(cmd).decode("utf-8").strip()
    except subprocess.CalledProcessError:
        pass


def getspaces(wsdata):
    # get the current workspace and n- spaces from wmctrl -d
    newsrc = wsdata.splitlines()
    n_ws = len(newsrc)
    curr_ws = [l.split()[0] for l in newsrc if "*" in l][0]
    return n_ws, curr_ws


def show_wmclass(wid):
    # get WM_CLASS from window- id
    try:
        return get(["xprop", "-id", wid, "WM_CLASS"]).split("=")[-1].strip()
    except (IndexError, AttributeError):
        pass


def get_wmname(wid):
    # get WM_NAME from window- id
    try:
        return get([
            "xprop", "-id", wid, "WM_NAME"
        ]).split("=")[-1].strip().strip('"')
    except (IndexError, AttributeError):
        pass


def get_menuset(wdata):
    # return valid window-ids and workspaces from wmctrl -l
    allwindows = [l.split() for l in wdata.splitlines()]
    return [wid[1] for wid in allwindows if not show_wmclass(wid[0]) in ignore]


def new_icon(currws):
    # arrange icon path from current workspace
    return "ws" + str(int(currws) + 1) + "-symbolic"


def update_winmenu(currdata):
    newdata = get(["wmctrl", "-l"])
    newmenudata = []
    try:
        test = currdata[0] == newdata
    except TypeError:
        test = False
    if all([not test, newdata]):
        for l in [w.split() for w in newdata.splitlines()]:
            wid = l[0]
            wspace = l[1]
            wname = get_wmname(wid)
            wmclass = show_wmclass(wid)
            if all([wname, wmclass, wmclass not in ignore]):
                appname = wmclass.split(",")[-1].strip().strip('"')
                newmenudata.append([int(wspace), appname, wname, wid])
        newmenudata = sorted(newmenudata, key=itemgetter(0, 1, 2))
        newmenu = []
        subspace = []
        for wsp, data in groupby(newmenudata, itemgetter(0)):
            subspace.append(wsp)
            wlst = [w[1:] for w in list(data)]
            for app, windows in groupby(wlst, itemgetter(0)):
                subspace.append([app, [w[1:] for w in list(windows)]])
            newmenu.append(subspace)
            subspace = []
        return (newdata, newmenu)
    else:
        return currdata
