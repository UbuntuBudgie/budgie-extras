PLUGIN = 'budgie-showtime'
WIDGET = 'org.ubuntubudgie.raven.widget.budgie-showtime'

if for_wayland
    SCHEMA='schema/org.ubuntubudgie.raven.widget.budgie-showtime.gschema.xml'
else
    SCHEMA='schema/org.ubuntubudgie.plugins.budgie-showtime.gschema.xml'
endif

install_data(SCHEMA, install_dir: '/usr/share/glib-2.0/schemas')

LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)
RAVEN_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'raven-plugins', WIDGET)

message('Installing applet...')

subdir('src')
subdir('data')
subdir('icons')

meson.add_install_script('meson_post_install.py')
