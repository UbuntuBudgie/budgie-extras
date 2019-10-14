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
sysconfdir = join_paths(prefix, get_option('sysconfdir'))


LOCALE_DIR = join_paths(prefix, get_option('localedir'))
APP = 'budgie-wallstreet'

LIB_INSTALL_DIR = join_paths(prefix, libdir, APP)

install_data('schema/org.ubuntubudgie.budgie-wallstreet.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

PIXMAPS_DIR = join_paths(datadir, 'pixmaps')

message('Installing applet...')

subdir('src')
subdir('data')

meson.add_install_script('meson_post_install.py')
