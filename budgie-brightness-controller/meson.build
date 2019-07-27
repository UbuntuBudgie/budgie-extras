am_cflags = [
    '-fstack-protector',
    '-pedantic',
    '-Wstrict-prototypes',
    '-Wundef',
    '-Werror-implicit-function-declaration',
    '-Wformat',
    '-Wformat-security',
    '-Werror=format-security',
    '-Wconversion',
    '-Wunused-variable',
    '-Wunreachable-code',
    '-Wall',
    '-W'
]

PLUGIN = 'budgie-brightness-controller'
LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

DEPENDENCY_GNOME_SETTINGS_DAEMON = dependency('gnome-settings-daemon', version: '>=3.28.0')
DEPENDENCY_XRANDR = dependency('xrandr', version: '>=1.5.0')
DEPENDENCY_GTK = dependency('gtk+-3.0', version: '>=3.18')
DEPENDENCY_BUDGIE = dependency('budgie-1.0', version: '>=2')


message('Installing applet...')

subdir('src')
subdir('icons')
