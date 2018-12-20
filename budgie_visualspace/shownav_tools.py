#!/usr/bin/env python3
import subprocess
import os
import gi
from gi.repository import Gio


"""
VisualSpace
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
program.  If not, see <https://www.gnu.org/licenses/>.
"""


navpath = os.path.dirname(os.path.abspath(__file__))
navigator = os.path.join(navpath, "shownav")
user = os.environ["USER"]
shownav_busy = "/tmp/" + user + "_shownav_busy"
shownav_right = "/tmp/" + user + "_shownav_right"
shownav_left = "/tmp/" + user + "_shownav_left"


# n-worspaces settings
path = "org.gnome.desktop.wm.preferences"
key = "num-workspaces"
settings = Gio.Settings.new(path)


# visualspace settings
visual = Gio.Settings.new("org.ubuntubudgie.visualspace")


def get(cmd):
    try:
        return subprocess.check_output(cmd).decode("utf-8").strip()
    except subprocess.CalledProcessError:
        pass


def get_wsdata():
    # get current workspace, n- workspaces
    data = get(["wmctrl", "-d"]).splitlines()
    return [int([l.split()[0] for l in data if "*" in l][0]) + 1, len(data)]
