App Launcher
========

App Launcher is a Budgie Desktop applet for productivity. This applet lists your favourite apps.  


Evo Pop                    |  Arc Design
:-------------------------:|:-------------------------:
<img src="https://raw.githubusercontent.com/UbuntuBudgie/experimental/master/budgie-app-launcher/screenshots/screenshot1.gif" width="400"/>  |  <img src="https://raw.githubusercontent.com/UbuntuBudgie/experimental/master/budgie-app-launcher/screenshots/screenshot2.gif" width="400"/>

<br/>

Install
-------
```bash
   # Clone or download the repository
   git clone https://github.com/UbuntuBudgie/experimental.git

   # Go to the budgie-app-launcher directory (first)
   cd experimental/budgie-app-launcher

   # Configure the the installation
   mkdir build && cd build
   meson --buildtype plain --prefix=/usr --libdir=/usr/lib

   # Install
   sudo ninja install

   # To uninstall
   sudo ninja uninstall

   # Logout and login after installing the applet.
   # You can add App Launcher to your panel from Budgie Desktop Settings.

   # Have fun!
```

<br/>

Changelog
-------
### Added

### Changed
* List icon size is fixed at 24
### Removed

<br/>

References
-------
[Ubuntu Budgie](https://ubuntubudgie.org/)<br/>
[budgie-desktop-examples](https://github.com/budgie-desktop/budgie-desktop-examples/tree/master/python_project)<br/>
[budgie-desktop applets](https://github.com/solus-project/budgie-desktop/tree/master/src/applets)<br/>

License
-------

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or at your option) any later version.
