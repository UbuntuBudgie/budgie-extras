
PLUGIN = 'budgie-brightness-controller'
LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

DEPENDENCY_GNOME_SETTINGS_DAEMON = dependency('gnome-settings-daemon', version: '>=3.36.0')

if for_wayland == false
    DEPENDENCY_XRANDR = dependency('xrandr', version: '>=1.5.0')
endif
DEPENDENCY_GTK = dependency('gtk+-3.0', version: '>=3.18')
DEPENDENCY_BUDGIE = budgie_dep

message('Installing applet...')

subdir('src')
subdir('icons')
