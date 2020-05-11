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

LIB_INSTALL_DIR = join_paths(prefix, libdir, SHUFFLER)

conf.set_quoted('PACKAGE_APPDIR', LIB_INSTALL_DIR)

install_data('schema/org.ubuntubudgie.windowshuffler.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

message('Installing miniapp...')

subdir('src')
subdir('data')

meson.add_install_script('meson_post_install.py')
