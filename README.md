# budgie-extras

additional enhancements for the user experience

## Plugins: 

 - Window Previews
 - Hotcorners
 - Quicknote
 - Workspace Switcher Overview
 - Workspace Switcher
 - Workspace Mover
 - ShowTime
 
 ## Installation
 
     mkdir build && cd build
     meson --buildtype plain --prefix=/usr --datadir=/usr/share ..
     ninja -v
     sudo ninja install

## Runtime dependencies

The following packages are required for the plugins to work:

 - wmctrl
 - xdotool
 - xprintidle
 - python3
 - python3-gi
