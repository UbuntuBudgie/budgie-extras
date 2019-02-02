# Budgie TakeaBreak

Budgie TakeaBreak is a pomodoro- like applet, to make sure to take regular breaks from working. Options from Budgie Settings include turning the screen upside down, dim the screen, lock screen or show a countdown message on break time. The applet can be accessed quickly from the panel to temporarily switch it off. 

![switch1](https://github.com/UbuntuBudgie/experimental/blob/master/unreleased_ready_to_use/budgie-takeabreak/switch1.png)

![switch2](https://github.com/UbuntuBudgie/experimental/blob/master/unreleased_ready_to_use/budgie-takeabreak/switch2.png)

![options](https://github.com/UbuntuBudgie/experimental/blob/master/unreleased_ready_to_use/budgie-takeabreak/options.png)

# Install
For testing:

- copy `org.ubuntubudgie.plugins.takeabreak.gschema.xml` to `/usr/share/glib-2.0/schemas`
- run from a terminal: `sudo glib-compile-schemas /usr/share/glib-2.0/schemas/`
- copy `takeabreak-symbolic.svg` and `takeabreakpaused-symbolic.svg` to `/usr/share/pixmaps`, all other files to `~/.local/share/budgie-desktop/plugins/budgie-takeabreak`. Log out and back in, add the applet from Budgie Settings.


