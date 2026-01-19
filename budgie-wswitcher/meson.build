PLUGIN='budgie-wswitcher'
LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

WIDGET='org.ubuntubudgie.raven.widget.budgie-wswitcher'
RAVEN_LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'raven-plugins', WIDGET)

message('Installing applet...')

subdir('src')
subdir('data')

if for_wayland
    SCHEMA = 'schema/org.ubuntubudgie.raven.widget.budgie-wswitcher.gschema.xml'
else
    SCHEMA = 'schema/org.ubuntubudgie.plugins.budgie-wswitcher.gschema.xml'
endif

install_data(SCHEMA, install_dir: '/usr/share/glib-2.0/schemas')

meson.add_install_script('meson_post_install.py')
