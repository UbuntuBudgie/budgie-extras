#!/usr/bin/env python3
import svgwrite
from cairosvg import svg2png
import os
from PIL import Image
import gi
from gi.repository import Gio
import subprocess

"""
ClockWorks
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

tz_data = [
    "-12:00", "-11:00", "-10:00", "-09:30", "-09:00", "-08:00", "-07:00",
    "-06:00", "-05:00", "-04:00", "-03:30", "-03:00", "-02:00", "-01:00",
    "00:00", "+01:00", "+02:00", "+03:00", "+03:30", "+04:00", "+04:30",
    "+05:00", "+05:30", "+05:45", "+06:00", "+06:30", "+07:00", "+08:00",
    "+08:30", "+08:45", "+09:00", "+09:30", "+10:00", "+10:30", "+11:00",
    "+12:00", "+12:45", "+13:00", "+14:00",
]


def get(command):
    try:
        return subprocess.check_output(command).decode("utf-8").strip()
    except subprocess.CalledProcessError:
        pass


# dirs etc.
home = os.environ["HOME"]
settingsdir = os.path.join(home, ".config/budgie-extras/clockworks")
hrs_path = os.path.join(settingsdir, "hrs")
mins_path = os.path.join(settingsdir, "mins")
misc_dir = os.path.join(settingsdir, "misc")
user = os.environ["USER"]
tmp = os.path.join("/tmp", user + "_clockworks")
clock_datafile = os.path.join(settingsdir, "clockdata")
key = "org.ubuntubudgie.plugins.budgie-clockworks"
subkeys = ["background", "hour", "minute"]
settings = Gio.Settings.new(key)


# make sure directories exist
for dr in [hrs_path, mins_path, misc_dir, tmp]:
    try:
        os.makedirs(dr)
    except FileExistsError:
        pass


def prepare_rgb(hx):
    return [int(hx.strip("#")[i:i + 2], 16) for i in (0, 2, 4)]


def hex2rgb(hx):
    # convert hex color to rgb
    return "rgb(" + ", ".join([str(n) for n in prepare_rgb(hx)]) + ")"


def rgb2hex(r, g, b):
    hx = "#{:02x}{:02x}{:02x}".format(r, g, b)
    return hx


def get_current_colors():
    # produce current gsettings values
    return [
        settings.get_string(val) for val in [
            "background", "hour", "minute"
        ]
    ]


def create_png(svg, target):
    lines = open(svg).readlines()[1:][0]
    svg2png(bytestring=lines, write_to=target)


def create_bg(hx):
    # temp file
    tmp_bg = os.path.join(tmp, "tmp_bg.svg")
    # create svg file
    bg = svgwrite.Drawing(filename=tmp_bg, size=("100px", "100px"))
    # define circle
    bg.add(
        bg.circle(
            center=(50, 50), r=48, stroke_width="4",
            stroke=hex2rgb(hx), fill="none",
        )
    )
    # save & convert
    bg.save()
    create_png(tmp_bg, os.path.join(misc_dir, "background_image.png"))


def save_togsettings(color, subkey):
    settings.set_string(subkey, color)


def create_minutes(hx):
    tmp_min = os.path.join(tmp, "tmp_min.svg")
    minute = svgwrite.Drawing(
        filename=tmp_min, size=("100px", "100px")
    )
    minute.add(minute.line(
        start=(50, 45), end=(50, 10), stroke_width="3",
        stroke=hex2rgb(hx),
    )
    )
    minute.save()
    temp_minspng = tmp_min.replace(".svg", ".png")
    create_png(tmp_min, temp_minspng)
    # minutes
    min_source = Image.open(temp_minspng)
    for n in range(60):
        rotate = n * 6
        newminspath = os.path.join(mins_path, str(n) + ".png")
        new_min = min_source.rotate(
            rotate, resample=Image.BICUBIC, expand=False
        )
        new_min.save(newminspath)


def create_hours(hx):
    tmp_hr = os.path.join(tmp, "tmp_hr.svg")
    hr = svgwrite.Drawing(
        filename=tmp_hr, size=("100px", "100px")
    )
    hr.add(hr.line(
        start=(50, 45), end=(50, 20), stroke_width="3",
        stroke=hex2rgb(hx),
    )
    )
    hr.save()
    temp_hrspng = tmp_hr.replace(".svg", ".png")
    create_png(tmp_hr, temp_hrspng)
    # hours
    hr_source = Image.open(temp_hrspng)
    for n in range(60):
        rotate = n * 6
        newhrpath = os.path.join(hrs_path, str(n) + ".png")
        new_hr = hr_source.rotate(
            rotate, resample=Image.BICUBIC, expand=False
        )
        new_hr.save(newhrpath)


def create_set():
    curr_settings = get_current_colors()
    create_bg(curr_settings[0])
    create_hours(curr_settings[1])
    create_minutes(curr_settings[2])
