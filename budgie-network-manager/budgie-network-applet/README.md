# Budgie Network Applet
This is a fork of [Wingpanel Network Indicator](https://github.com/elementary/wingpanel-indicator-network), ported to budgie desktop


![Screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* gobject-introspection
* libnm-dev
* libnma-dev
* budgie-1.0
* meson
* valac
* gee-0.8

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
    
### Arch
you can install that applet on archlinux with aur : [budgie-network-applet](https://aur.archlinux.org/packages/budgie-network-applet)

### Solus (dependencies)
```
sudo eopkg it -c system.devel
sudo eopkg it budgie-desktop-devel libgtk-3-devel ninja gobject-introspection meson vala network-manager-applet-devel libgee-devel gcc
```
## Donation

If you like this applet, you can donate via **[PayPal](https://www.paypal.me/danielpinto8zz6)**. It will help me to spend more time improving this!
