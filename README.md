# budgie-extras

Additional enhancements for the user experience

## Plugins:

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
 - Take-A-Break
 - Workspace Stopwatch
 - Fuzzy Clock
 - Brightness Controller
 - Visualspace
 - Applications Menu
 - Network Manager

## Standalone

budgie mini-apps - see the individual components for details

 - Budgie Extras Daemon
 - Budgie Wallstreet
 - Budgie Quickchar (needs the extras daemon as a runtime dependency)
 - Budgie Window Previews (needs the extras daemon as a runtime dependency)
 - Budgie Shuffler (needs the extras daemon as a runtime dependency)
 
 ## Installation

 By default all applets are compiled and installed:

     mkdir build && cd build
     meson --buildtype plain --prefix=/usr --libdir=/usr/lib
     ninja -v
     sudo ninja install

If individual applets (or groups of applets) are to be compiled and installed use
the options described in meson_options.txt i.e. use `-Dbuild-all=false -Dbuild-appletoption=true`

e.g. to build just the hotcorners and weathershow applets

     mkdir build && cd build
     meson --buildtype plain -Dbuild-all=false -Dbuild-hotcorners=true -Dbuild-weathershow=true --prefix=/usr --libdir=/usr/lib
     ninja -v
     sudo ninja install

## Distro's

We love Budgie-Extras to work across as many distro's as possible.  So please let us know if your distro has packaged budgie-extras and how to install.

 - Arch - https://www.archlinux.org/packages/community/x86_64/budgie-extras/
 - Ubuntu - use the ubuntu-budgie-welcome snap - and install via Menu - Budgie Applets
 - Debian - packages are available in Buster/Bullseye named "budgie-insertname-applet" https://goo.gl/R4eF7q
 
 [![Packaging status](https://repology.org/badge/vertical-allrepos/budgie-extras.svg)](https://repology.org/project/budgie-extras/versions)

## Build/Runtime dependencies

Individual applets/mini apps have build and runtime dependencies. These are described by https://github.com/UbuntuBudgie/budgie-extras/blob/debian/debian/control

 
 ## Project License
 
 The overall license for the project is GPL-3+.  It is important to note, various individual source files varies from this and git-submodules have a separate licensing.
 
 This is covered by https://github.com/UbuntuBudgie/budgie-extras/blob/debian/debian/copyright
