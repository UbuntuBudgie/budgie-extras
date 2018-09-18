# budgie-extras

Additional enhancements for the user experience

## Plugins: 

 - Window Previews
 - Hotcorners
 - Quicknote
 - Workspace Switcher Overview
 - Wallpaper Switcher
 - Workspace Mover
 - ShowTime
 - CountDown
 - Automatic Keyboard Layout Switcher
 - Screen Rotation Lock
 - ClockWorks
 - DropBy
 - Kangaroo
 - WeatherShow
 - Trash
 - App-launcher
 - RecentlyUsed
 
## Standalone

Non-budgie plugins - see the individual components for details

 - Budgie Visualspace
 
 ## Installation
 
     mkdir build && cd build
     meson --buildtype plain --prefix=/usr --libdir=/usr/lib --datadir=/usr/share ..
     ninja -v
     sudo ninja install
     
## Distro's

We love Budgie-Extras to work across as many distro's as possible.  So please let us know if your distro has packaged budgie-extras and how to install.

 - Arch - https://aur.archlinux.org/packages/budgie-extras/
 - Ubuntu - use the ubuntu-budgie-welcome snap - and install via Menu - Budgie Applets
 - Debian - packages are available in Buster named "budgie-insertname-applet" https://goo.gl/R4eF7q

## Build/Runtime dependencies

The following packages are required for the various Python plugins to work:

 - wmctrl
 - xdotool
 - xprintidle
 - python3
 - python3-gi
 - python3-gi-cairo
 - python3-cairo
 - zenity
 - ogg123 (from vorbis-tools)
 - gir1.2-budgie-1.0
 - gir1.2-gtk-3.0
 - gir1.2-glib-2.0
 - python3-psutil
 - dconf-cli
 - sound-theme-freedesktop
 - imagemagick
 - python3-pil
 - python3-svgwrite
 - python3-cairosvg
 - python3-pyudev
 - python3-requests
 
The following packages are required for the various Vala plugins to work:
 - gobject-introspection
 - libgtk-3-dev
 - valac
 - budgie-core-dev
 - libbudgie-plugin0
 - libpeas-dev
 - libjson-glib-dev
 - libgee-0.8-dev

