# budgie-extras

additional enhancements for the user experience

## Plugins: 

 - Window Previews
 - Hotcorners
 - Quicknote
 - Workspace Switcher Overview
 - Workspace Switcher
 - Workspace Mover
 
 ## Installation
 
     mkdir build && cd build
     meson --buildtype plain --prefix=/usr --datadir=/usr/share --sysconfdir=/opt ..
     ninja
     sudo ninja install

## Runtime dependencies

The following packages are required for the plugins to work:

 - wmctrl
 - xdotool
 - xprintidle
 - python3
 - python3-gi
