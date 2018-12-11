#gnome = import('gnome')

PLUGIN = 'budgie-clockworks'

install_data(
    'BudgieClockWorks.plugin',
    'cwtools.py',
    'budgie_clockworks.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, PLUGIN)
)

install_data(
    'budgie-clockworks-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

install_data('schema/org.ubuntubudgie.plugins.budgie-clockworks.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

meson.add_install_script('meson_post_install')
