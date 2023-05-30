# budgie-extras

[![](https://opencollective.com/ubuntubudgie/tiers/backer.svg?avatarHeight=96)](https://opencollective.com/ubuntubudgie)

Additional enhancements for the user experience

## Plugins:

 - Hotcorners
 - Quicknote
 - Wallpaper Switcher
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
 - Shuffler

## Standalone

budgie mini-apps - see the individual components for details

 - Budgie Extras Daemon
 - Budgie Wallstreet
 - Budgie Quickchar (needs the extras daemon as a runtime dependency)
 - Budgie Window Previews (needs the extras daemon as a runtime dependency)
 - Budgie Shuffler (needs the extras daemon as a runtime dependency)
 - Budgie Hotcorners (needs shuffler daemon as a runtime dependency for full functionality)
 
 ## Installation

 By default all applets are compiled and installed:

     git clone https://github.com/ubuntubudgie/budgie-extras
     cd budgie-extras
     git submodule init
     git submodule update

     mkdir build && cd build
     meson --buildtype plain --prefix=/usr --libdir=/usr/lib
     ninja -v
     sudo ninja install

If individual applets (or groups of applets) are to be compiled and installed use
the options described in meson_options.txt i.e. use `-Dbuild-all=false -Dbuild-appletoption=true`

e.g. to build just the hotcorners and weathershow applets
(remember to git clone and git submodule etc as above)

     mkdir build && cd build
     meson --buildtype plain -Dbuild-all=false -Dbuild-hotcorners=true -Dbuild-weathershow=true --prefix=/usr --libdir=/usr/lib
     ninja -v
     sudo ninja install

## Distro's

We love Budgie-Extras to work across as many distro's as possible.  Budgie Extras should be packaged as individual applets - NOT as one "budgie-extras" package, so that end users can install one or more applets.  Please let us know if your distro has packaged budgie-extras and how to install each applet.

 - Arch - https://www.archlinux.org/packages/community/x86_64/budgie-extras/ NOTE - this installs everything rather than allowing per applet installation
 - Ubuntu - use the ubuntu-budgie-welcome snap - and install via Menu - Budgie Applets
 - Debian - packages are available in Buster/Bullseye named "budgie-insertname-applet" https://goo.gl/R4eF7q
 - Gentoo - Overlay for budgie desktop including budgie-extras https://gitlab.com/SarahMia/sarahmiaoverlay
 
 [![Packaging status](https://repology.org/badge/vertical-allrepos/budgie-extras.svg)](https://repology.org/project/budgie-extras/versions)

## Build/Runtime dependencies

Individual applets/mini apps have build and runtime dependencies. These are described by https://github.com/UbuntuBudgie/budgie-extras/blob/debian/debian/control

 
 ## Project License
 
 The overall license for the project is GPL-3+.  It is important to note, various individual source files varies from this and git-submodules have a separate licensing.
 
 This is covered by https://github.com/UbuntuBudgie/budgie-extras/blob/debian/debian/copyright
