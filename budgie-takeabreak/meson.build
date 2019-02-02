#gnome = import('gnome')

PLUGIN = 'budgie-takeabreak'

install_data(
    'BudgieTakeaBreak.plugin',
    'message_window',
    'takeabreak_run',
    'budgie_takeabreak.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, PLUGIN)
)

install_data(
    'takeabreakpaused-symbolic.svg',
    'takeabreak-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

install_data('schema/org.ubuntubudgie.plugins.takeabreak.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

meson.add_install_script('meson_post_install')
