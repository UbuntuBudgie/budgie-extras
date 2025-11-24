# Budgie Trash Applet

Manage items in your trash bin right from the Budgie panel.

![Main View](https://github.com/EbonJaeger/budgie-trash-applet/blob/master/data/images/screenshot1.png)

---

## Development

### Dependencies

```
budgie-1.0 >= 2
gtk+-3.0 >= 3.22
glib-2.0 >= 2.46.0
libnotify >= 0.7
sassc
```

You can get these on Solus with the following packages:

```
budgie-desktop-devel
libgtk-3-devel
libnotify-devel
glib2-devel
sassc
```

### Building and Installing

1. Configure the build directory and meson with:

```bash
mkdir build
meson --prefix=/usr build
```

2. Build the project with:

```bash
ninja -C build
```

3. Install the files with:

```bash
sudo ninja install -C build
```

### Code Style

This project uses pretty much the same code style as [Budgie Desktop](https://github.com/solus-project/budgie-desktop) in order to make the code bases more consistant across the Budgie projects. In theory, this makes it easier for people familiar with one project to see what's going on in other, related projects.

#### Differences

1. This project puts the pointer symbol (`*`) on the name instead of the type
2. This project uses spaces instead of tabs (sorry, Josh :P)
