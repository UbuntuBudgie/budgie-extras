#!/usr/bin/env python3
import subprocess
import time
import os

previews = os.path.join(os.environ["HOME"], ".budgie-PV")

try:
    os.mkdir(previews)
except FileExistsError:
    pass

ignore = [
    "= _NET_WM_WINDOW_TYPE_DOCK",
     "= _NET_WM_WINDOW_TYPE_DESKTOP",
    ]

# default resize is v_size, unless w exceeds threshold
max_w = 260
v_size = 160
# strings, to be used in the resize- commands
comm = str(max_w)+"x"+str(v_size)

def get_area():
    # get size of the primary screen. Too bad we can't use wmctrl. xrandr is slower
    # _NET_DESKTOP_GEOMETRY ?
    windata = get("xrandr").split()
    return int(windata[windata.index("primary")+1].split("x")[0])

def get(cmd):
    # just a helper
    try:
        return subprocess.check_output(cmd).decode("utf-8").strip()
    except (subprocess.CalledProcessError, TypeError):
        pass
    
def get_ws():
    # get current workspace
    try:
        return [l.split()[0] for l in get([
            "wmctrl", "-d"
            ]).splitlines() if "*" in l][0]
    except AttributeError:
        pass

def empty_dir():
    for w in os.listdir(previews):
        path = os.path.join(previews, w)
        os.remove(path)

def get_valid(w_id):
    # see if the window is a valid one (type)
    w_data = get(["xprop", "-id", w_id])
    if w_data:
        return True if not any([t in w_data for t in ignore]) else False 
    else:
        return False

def show_wmclass(wid):
    # get WM_CLASS from window- id
    try:
        cl = get(["xprop", "-id", wid, "WM_CLASS"]).split("=")[-1].strip()
    except (IndexError, AttributeError):
        pass
    else:
        # exceptions; one application, multiple WM_CLASS
        if "Thunderbird" in cl:
            return "Thunderbird"
        elif "Toplevel" in cl:
            return "Toplevel"
        else:
            return cl
        
def get_activeclass():
    # get WM_CLASS of active window
    return show_wmclass(get(["xdotool", "getactivewindow"]))

def get_hex(w_id):
    win = hex(int(w_id))
    return win[:2]+(10-len(win))*"0"+win[2:]

def get_wmname(w_id):
    # get WM_NAME from window- id
    return get(["xdotool", "getwindowname", w_id])
       
def create_preview(w_id, w):
    # create the actual image
    output_path = setname(w)
    subprocess.Popen([
    "import", "-silent", "-window", w_id, "-trim", 
    "-resize", comm, output_path,
     ])

def setname(window):
    name = "/"+".".join(window)+".jpg"
    path = previews+name
    return path

    
  
print(get_ws())




