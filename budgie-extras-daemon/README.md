# budgie-extras-daemon

This on logon process manages keyboard shortcuts delivered via .bde files
for various extras-plugins.

# budgie-extras-daemon & layouts capability

In addition it delivers desktop layouts which can be run via invoke.py layoutname

Layouts include:

1. theone aka "Unity 7"
2. redmond (guess what!)
3. traditional (bottom panel no plank)
4. cupertino aka the fruity flavor
5. ubuntubudgie

Each layout requires extra plugins, budgie-desktop plugins or third-party plugins

* budgie-appmenu-applet - recommended runtime dependency
* budgie-trash-applet - recommended runtime dependency
* budgie-applications-menu-applet - the is an absolute runtime dependency for extras-daemon
* budgie-recentlyused-applet - recommended runtime dependency
* budgie-indicator-applet - recommended runtime dependency
* budgie-network-manager-applet - recommended runtime dependency
* budgie-dropby-applet - recommended runtime dependency
* budgie-showtime-applet - recommended runtime dependency
* budgie-quicknote-applet - recommended runtime dependency

In addition (for ubuntubudgie and cupertino) plank is started bottom centered.
Plank is a suggested dependency