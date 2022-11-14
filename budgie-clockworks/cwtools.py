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
Copyright © 2017-2022 Ubuntu Budgie Developers
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
    "-24:00", "-23:45", "-23:30", "-23:15", "-23:00", "-22:45", "-22:30",
    "-22:15", "-22:00", "-21:45", "-21:30", "-21:15", "-21:00", "-20:45",
    "-20:30", "-20:15", "-20:00", "-19:45", "-19:30", "-19:15", "-19:00",
    "-18:45", "-18:30", "-18:15", "-18:00", "-17:45", "-17:30", "-17:15",
    "-17:00", "-16:45", "-16:30", "-16:15", "-16:00", "-15:45", "-15:30",
    "-15:15", "-15:00", "-14:45", "-14:30", "-14:15", "-14:00", "-13:45",
    "-13:30", "-13:15", "-13:00", "-12:45", "-12:30", "-12:15", "-12:00",
    "-11:45", "-11:30", "-11:15", "-11:00", "-10:45", "-10:30", "-10:15",
    "-10:00", "-09:45", "-09:30", "-09:15", "-09:00", "-08:45", "-08:30",
    "-08:15", "-08:00", "-07:45", "-07:30", "-07:15", "-07:00", "-06:45",
    "-06:30", "-06:15", "-06:00", "-05:45", "-05:30", "-05:15", "-05:00",
    "-04:45", "-04:30", "-04:15", "-04:00", "-03:45", "-03:30", "-03:15",
    "-03:00", "-02:45", "-02:30", "-02:15", "-02:00", "-01:45", "-01:30",
    "-01:15", "-01:00", "-00:45", "-00:30", "-00:15", "00:00", "+00:15",
    "+00:30", "+00:45", "+01:00", "+01:15", "+01:30", "+01:45", "+02:00",
    "+02:15", "+02:30", "+02:45", "+03:00", "+03:15", "+03:30", "+03:45",
    "+04:00", "+04:15", "+04:30", "+04:45", "+05:00", "+05:15", "+05:30",
    "+05:45", "+06:00", "+06:15", "+06:30", "+06:45", "+07:00", "+07:15",
    "+07:30", "+07:45", "+08:00", "+08:15", "+08:30", "+08:45", "+09:00",
    "+09:15", "+09:30", "+09:45", "+10:00", "+10:15", "+10:30", "+10:45",
    "+11:00", "+11:15", "+11:30", "+11:45", "+12:00", "+12:15", "+12:30",
    "+12:45", "+13:00", "+13:15", "+13:30", "+13:45", "+14:00", "+14:15",
    "+14:30", "+14:45", "+15:00", "+15:15", "+15:30", "+15:45", "+16:00",
    "+16:15", "+16:30", "+16:45", "+17:00", "+17:15", "+17:30", "+17:45",
    "+18:00", "+18:15", "+18:30", "+18:45", "+19:00", "+19:15", "+19:30",
    "+19:45", "+20:00", "+20:15", "+20:30", "+20:45", "+21:00", "+21:15",
    "+21:30", "+21:45", "+22:00", "+22:15", "+22:30", "+22:45", "+23:00",
    "+23:15", "+23:30", "+23:45", "+24:00",
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
