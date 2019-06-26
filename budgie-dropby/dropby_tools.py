#!/usr/bin/env python3
import pyudev
import psutil
import subprocess
import time


"""
DropBy
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


def bytes_toreadable(bte):
    """
    convert b (float/int) into the most convenient unit (str)
    """
    unit_names = ["KB", "MB", "GB", "TB"]
    units = [1024**q for q in range(4)]
    numbers = [d for d in [bte / (n * 1024) for n in units] if d >= 1]
    try:
        return str(round(numbers[-1], 1)) + " " + unit_names[len(numbers) - 1]
    except IndexError:
        return "0 KB"


def get_usb():
    """
    get usb devices by uuid (pyudev)
    """
    relevant = []
    udev_context = pyudev.Context()
    allvols = udev_context.list_devices(subsystem='block')
    for v in allvols:
        try:
            uuid = v['ID_FS_UUID']
        except KeyError:
            pass
        else:
            if "usb" in v["DEVPATH"]:
                relevant.append(uuid)
    return relevant


def get_mounted():
    """
    get info on *mounted* volumes (psutil)
    device path, mountpoint, usage
    """
    relevant = []
    mounted = psutil.disk_partitions(all=False)
    for v in mounted:
        usage = None
        try:
            usage = psutil.disk_usage(v.mountpoint)
        except PermissionError:
            continue
        dev = v.device
        # mountpoint is relevant for possible actions
        mpoint = v.mountpoint
        try:
            us = usage.free
        except AttributeError:
            us = "--"
        relevant.append([dev, mpoint, us])
    return relevant


def uuid_todev(uuid):
    try:
        return subprocess.check_output(
            ["findfs", "UUID=" + uuid]
        ).decode("utf-8").strip()
    except (subprocess.CalledProcessError, TypeError):
        return None


def get_volumes(allvols):
    """
    get relevant data on all usb volumes
    """
    relevant = []
    # gather data
    usb_devs = get_usb()
    use_data = get_mounted()
    mounted_devspaths = [d[0] for d in use_data]
    # filter out relevants
    for v in allvols:
        # filter out usb devices
        uuid = v.get_uuid()
        if uuid in usb_devs:
            devdata = {
                "volume": v,
                "name": v.get_name(),
                "uuid": uuid,
                "device": uuid_todev(uuid),
                "can_mount": v.can_mount(),
                "icon": v.get_icon(),
                "flashdrive": v.can_eject(),
                "ismounted": v.get_mount(),
            }
            # try to determine usage
            path = uuid_todev(uuid)
            try:
                match = mounted_devspaths.index(path)
            except ValueError:
                free = ""
                fpath = None
            else:
                free = bytes_toreadable(use_data[match][2])
                fpath = use_data[match][1]
            devdata["free"] = free
            devdata["volume_path"] = fpath
            relevant.append(devdata)
    return(relevant)
