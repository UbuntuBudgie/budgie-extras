#!/usr/bin/env python3
import requests
import json
import weathertools as wt


"""
Budgie WeatherShow
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


def get_data(key, city, wtype, lang):
    # data = sky, temp, wind_dir, wind_speed, pressure
    lang = "&lang=" + lang if lang else ""
    try:
        data = requests.get(
            "http://api.openweathermap.org/data/2.5/" + wtype + "?id=" +
            city + "&APPID=" + key + lang
        )
        if data.status_code == requests.codes.ok:
            return dict(json.loads(data.text))
        else:
            print("Status returned not ok")
    except Exception:
        print("Connection failure or invalid key- or citycode")


def try_read(data, path, name):
    src = data
    for k in path:
        try:
            src = src[k]
        except Exception:
            src = None
    return name, src


def check_dictpaths(raw_data):
    newdata = {}
    for item in [
        [["weather", 0, "icon"], "icon"],
        [["sys", "sunrise"], "sunrise"],
        [["sys", "sunset"], "sunset"],
        [["weather", 0, "description"], "sky"],
        [["main", "temp"], "temp"],
        [["wind", "speed"], "wind_speed"],
        [["wind", "deg"], "wind_deg"],
        [["main", "humidity"], "humidity"],
        [["weather", 0, "id"], "weather_code"],
    ]:
        newvalue = try_read(raw_data, item[0], item[1])
        newdata[newvalue[0]] = newvalue[1]
    return newdata


def get_fields(key, city, lang, wtype="weather"):
    raw_data = get_data(key, city, wtype, lang)
    if raw_data:
        newdata = check_dictpaths(raw_data)
    else:
        newdata = {}
        for k in [
            "icon", "sunrise", "sunset", "sky", "temp", "wind_speed",
            "wind_deg", "humidity", "weather_code",
        ]:
            newdata[k] = None
    return newdata
