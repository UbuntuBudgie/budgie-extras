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
