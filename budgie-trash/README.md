Trash
========

Trash is a Budgie Desktop applet for productivity.  


Evo Pop                    |  Arc Design
:-------------------------:|:-------------------------:
<img src="https://github.com/UbuntuBudgie/experimental/blob/master/budgie-trash/screenshots/screenshot1.gif" width="300"/>  |  <img src="https://github.com/UbuntuBudgie/experimental/blob/master/budgie-trash/screenshots/screenshot2.gif" width="300"/>

<br/>

Dependencies
-------
```
budgie-1.0 >= 2
gtk+-3.0
vala
```
<br/>

Install
-------
```bash
   # Clone or download the repository
   git clone https://github.com/UbuntuBudgie/experimental.git

   # Go to the budgie-trash directory
   cd experimental/budgie-trash

   # Configure the the installation
   mkdir build && cd build
   meson --buildtype plain --prefix=/usr --libdir=/usr/lib
   ninja

   # Install
   sudo ninja install

   # To uninstall
   sudo ninja uninstall

   # Logout and login after installing the applet.
   # You can add Trash to your panel from Budgie Desktop Settings.

   # Have fun!
```

<br/>

Changelog
-------
### Added
* Locale language support(en_GB, en_US)
* Listing files
* Restore file, open file options
* class namespaces

### Changed
* project language from python to vala
### Removed

References
-------
[Ubuntu Budgie](https://ubuntubudgie.org/)<br/>
[budgie-desktop-examples](https://github.com/budgie-desktop/budgie-desktop-examples/tree/master/python_project)<br/>
[budgie-desktop applets](https://github.com/solus-project/budgie-desktop/tree/master/src/applets)<br/>
[cybre/budgie-haste-applet](https://github.com/cybre/budgie-haste-applet)<br/>
[bertoldia/gnome-shell-trash-extension](https://github.com/bertoldia/gnome-shell-trash-extension)<br/>


License
-------

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or at your option) any later version.