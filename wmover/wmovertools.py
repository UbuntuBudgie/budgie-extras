#!/usr/bin/env python3
import subprocess
import time

# wm_classes to be ignored
ignore = [
    '"budgie-panel", "Budgie-panel"',
    '"desktop_window", "Nautilus"',
    '"plank", "Plank"',
    None,
    ]

def get(cmd):
    try:
        return subprocess.check_output(cmd).decode("utf-8")
    except subprocess.CalledProcessError:
        pass

def show_wmclass(wid):
    # get WM_CLASS from window- id
    try:
        return get(["xprop", "-id", wid, "WM_CLASS"]).split("=")[-1].strip()
    except (IndexError, AttributeError):
        pass

def get_wsdata():
    wsdata = get(["wmctrl", "-d"]).splitlines()
    return(len(wsdata), wsdata.index([l for l in wsdata if "*" in l][0]))

def run(cmd):
    try:
        subprocess.Popen(cmd)
    except TypeError:
        pass

def check_ypos(yres):
    # get active window, check y- position
    try:
        subj = get(["xdotool", "getactivewindow"])
        ydata = get(["xdotool", "getwindowgeometry", subj])
    except (subprocess.CalledProcessError, TypeError):
        return False, None
    else:
        ypos = int([
            l for l in ydata.splitlines() if "Position" in l
            ][0].split(",")[1].split()[0])
        return ypos > yres-150, subj.strip()

def getres():
    # get the resolution from wmctrl
    resdata = get(["wmctrl", "-d"])
    res = [int(n) for n in resdata.split()[3].split("x")] if resdata else None
    return res
    
def area(x_area, y_area, xres, yres, x, y):
    # see if the mouse is in the hotspot
    center = xres/2; halfwidth = x_area/2
    x_match = center-halfwidth < x < center+halfwidth
    y_match = y > yres-y_area        
    return all([x_match, y_match])

def mousepos():
    # get mouseposition
    try:
        pos = get(["xdotool", "getmouselocation"]).split()
    except AttributeError:
        return 0, 0
    else:
        return int(pos[0].split(":")[1]), int(pos[1].split(":")[1])

def find_bar():
    return get(["xdotool", "search", "--class", "wmover"])

def callwindow(target, xres, yres):
    wtype = show_wmclass(target)
    if wtype in ignore:
        run(["notify-send", "-i", "wmover",
             "WindowMover", "Please first activate a window."])
    else:
        runwindow(target, xres, yres)
    
def runwindow(target, xres, yres):
    # run the mover bar
    subprocess.Popen([
        "/opt/budgie-extras/wmover/code/moverbar",
        target,
        str(xres),
        str(yres),
         ])
    time.sleep(0.5)
    limit_exist()

def limit_exist():
    # make sure the bar stays on top *and* active, allow 5 seconds
    t = 1
    while True:
        time.sleep(1)
        if t >= 5:
            run(["wmctrl", "-ic", find_bar()])
            break
        else:
            try:
                if "w_moversplash" in get(["wmctrl", "-l"]):
                    run(["wmctrl", "-a", "w_moversplash"])
                else:
                    break
            except TypeError:
                pass
        t = t+1

        
