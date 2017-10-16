#!/usr/bin/env python3
import subprocess
import ast
import os

# the key defining the default shortcut
def_key = ["org.gnome.desktop.wm.keybindings", "switch-applications"]
# the shortcut names to look up in dconf
shortcut_names = ["prv_all", "prv_single"]
# command (main-) line to run previews
aw = "/usr/lib/budgie-desktop/plugins/budgie-wprviews/wprviews_window"

def remove_custom():
    key = [
        "org.gnome.settings-daemon.plugins.media-keys",
        "custom-keybindings",
        "custom-keybinding",
        ]
    remove = []
    try:
        customs = ast.literal_eval(subprocess.check_output([
        "gsettings", "get", key[0], key[1],
        ]).decode("utf-8"))
    except SyntaxError:
        pass
    else:
        for c in customs:
            name = subprocess.check_output([
                "gsettings", "get", key[0]+"."+key[2]+":"+c, "name",
                ]).decode("utf-8").strip().strip("'")
            print(name)
            if name in shortcut_names:
                remove.append(c)
        newlist = [item for item in customs if not item in remove]
        subprocess.Popen([
            "gsettings", "set", key[0], key[1], str(newlist),
            ])
        reset_default()

def clear_default():
    # clear the set key so the shortcuts become available
    subprocess.Popen(["gsettings", "set", def_key[0], def_key[1], "[]"])

def reset_default():
    # restore default shortcut
    subprocess.Popen(["gsettings", "reset", def_key[0], def_key[1]])

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
    if arg == "set_custom":
        clear_default()
        define_keyboard_shortcut("prv_all", aw, '<Alt>Tab')
        define_keyboard_shortcut("prv_single", aw+" current", '<Super>Tab')
    elif arg == "restore":
        remove_custom()
        reset_default()
        








            




