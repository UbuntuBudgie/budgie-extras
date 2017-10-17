#!/usr/bin/env python3
import subprocess
import ast
import os

"""
Budgie WindowMover
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

# the key defining the custom keys
key = [
    "org.gnome.settings-daemon.plugins.media-keys",
    "custom-keybindings",
    "custom-keybinding",
    ]
# the shortcut names to look up in dconf
shortcut_names = ["wmover_window", "wmover_workspace"]
# command (main-) line to run previews
aw = "/usr/lib/budgie-desktop/plugins/budgie-wmover/wmover_run"

def get_currnames():
    relevant = []
    allnames = []
    try:
        customs = ast.literal_eval(subprocess.check_output([
        "gsettings", "get", key[0], key[1],
        ]).decode("utf-8"))
    except SyntaxError:
        return [], []
    else:
        for c in customs:
            name = subprocess.check_output([
                "gsettings", "get", key[0]+"."+key[2]+":"+c, "name",
                ]).decode("utf-8").strip().strip("'")
            if name in shortcut_names:
                relevant.append(c)
            allnames.append(c)
        return allnames, relevant
    
def remove_custom():
    customs = get_currnames()[0]
    remove = get_currnames()[1]
    newlist = [item for item in customs if not item in remove]
    subprocess.call([
        "gsettings", "set", key[0], key[1], str(newlist),
        ])

def define_keyboard_shortcut(name, command, shortcut):
    # defining keys & strings to be used
    # params example 'open gedit' 'gedit' '<Alt>7'
    key = "org.gnome.settings-daemon.plugins.media-keys custom-keybindings"
    subkey1 = key.replace(" ", ".")[:-1]+":"
    item_s = "/"+key.replace(" ", "/").replace(".", "/")+"/"
    firstname = "custom"
    # get the current list of custom shortcuts
    get = lambda cmd: subprocess.check_output([
        "/bin/bash", "-c", cmd
        ]).decode("utf-8")
    x = get("gsettings get "+key)
    if '@as []' in str(x):
       current = []
    else:
       current = ast.literal_eval(x)
    # make sure the additional keybinding mention is no duplicate
    n = 1
    while True:
        new = item_s+firstname+str(n)+"/"
        if new in current:
            n = n+1            
        else:
            break
    # add the new keybinding to the list
    current.append(new)
    # create the shortcut, set the name, command and shortcut key
    cmd0 = 'gsettings set '+key+' "'+str(current)+'"'
    cmd1 = 'gsettings set '+subkey1+new+" name '"+ name +"'"
    cmd2 = 'gsettings set '+subkey1+new+" command '"+ command +"'"
    cmd3 = 'gsettings set '+subkey1+new+" binding '"+ shortcut +"'"              
    for cmd in [cmd0, cmd1, cmd2, cmd3]:
        subprocess.call(["/bin/bash", "-c", cmd])

def change_keys(arg):
    # clean up possible duplicates (from unclean stop)
    remove_custom()
    if arg == "set_custom":
        # clean up possible duplicates (from unclean stop)
        define_keyboard_shortcut("wmover_window", aw+" -single", '<Control><Alt>w')
        define_keyboard_shortcut("wmover_workspace", aw+" -singlespace", '<Control><Alt>s')
    elif arg == "restore":
        pass

