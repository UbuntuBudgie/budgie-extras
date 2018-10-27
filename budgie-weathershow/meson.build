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
    '-W',
]

# Global path variable
prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))

LOCALE_DIR = join_paths(prefix, get_option('localedir'))
PLUGIN = 'budgie-weathershow'
VAPI_DIR = join_paths(meson.source_root(),
                      PLUGIN,
                      'vapi')

LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

install_data('schema/org.ubuntubudgie.plugins.weathershow.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

install_data(
    'cities',
    install_dir: join_paths(LIB_INSTALL_DIR)
)


PIXMAPS_DIR = join_paths(datadir, 'pixmaps')

message('Installing applet...')

subdir('src')
subdir('weather_icons')
subdir('icons_for_pixmaps')

meson.add_install_script('meson_post_install')
