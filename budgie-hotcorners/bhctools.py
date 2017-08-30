#!/usr/bin/env python3
import subprocess
import os

# config path
dr = os.path.join(os.environ["HOME"], ".config/budgie-hotcorners")
# settings file
settings = os.path.join(dr, "hotc_settings")

def get(cmd):
    #----------------------
    try:
        return subprocess.check_output(cmd).decode("utf-8").strip()
    except subprocess.CalledProcessError:
        pass

def getres():
    #----------------------
    # get the resolution from wmctrl
    resdata = get(["wmctrl", "-d"])
    res = [int(n) for n in resdata.split()[3].split("x")] if resdata else None
    return res

def mousepos():
    # get mouseposition
    #----------------------
    try:
        pos = get(["xdotool", "getmouselocation"]).split()
    except AttributeError:
        return 0, 0
    else:
        return int(pos[0].split(":")[1]), int(pos[1].split(":")[1])

def get_hot(marge, res):
    #----------------------
    pos = mousepos(); x_pos = pos[0]; y_pos = pos[1]
    
    top, left = marge, marge
    right = res[0] - marge; bottom = res[1] - marge

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
        return matches.index(True)+1
    except ValueError:
        pass
