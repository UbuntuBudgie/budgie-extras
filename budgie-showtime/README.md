# Budgie ShowTime

Budgie Showtime is a digital desktop clock, showing time, and optionally, date. Textcolor of both can be set separately from the applet's menu.

Settings from Budgie Settings include text alignment, -color, -size, temporarily make the applet dragable for custom positioning, 12 hrs format, custom data formatting according to:

https://valadoc.org/glib-2.0/GLib.DateTime.format.html

Furthermore, gsettings overrides can be done for font (-family), left or right bottom positioning.

To set left-bottom:
xposition = 1
yposition = -1

To set right-bottom:
xposition = 2
yposition = -1

# Install
Run from the repo's folder:

- `mkdir build && cd build`

- `meson --buildtype plain --prefix=/usr --libdir=/usr/lib`

- `ninja`

- `sudo ninja install`

