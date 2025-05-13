# Global path variable
prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))

LOCALE_DIR = join_paths(prefix, get_option('localedir'))

LIB_INSTALL_DIR = join_paths(prefix, libdir, SHUFFLER)
APPLET_INSTALL_DIR = join_paths(prefix, PLUGINS_INSTALL_DIR, SHUFFLER)


install_data('schema/org.ubuntubudgie.windowshuffler.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

message('Installing miniapp...')

subdir('src')
subdir('data')
subdir('applet')

meson.add_install_script('meson_post_install.py')
