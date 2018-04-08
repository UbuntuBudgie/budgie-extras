#gnome = import('gnome')

PLUGIN = 'wprviews'

install_data(
    'wprv',
    'WPrviews.plugin',
    'budgie-wprviews.py',
    'wprviews_backgrounder',
    'wprviews_panelrunner',
    'wprviews_tools.py',
    'set_keys.py',
    'wprviews_window',
    'moveto.sh',
    'wprv_hc',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, 'budgie-' + PLUGIN)
)

install_data(
    'prv_grey.png',
    'prv_white.png',
    'grey_x.png',
    'white_x.png',
    'white2_x.png',
    install_dir: join_paths(PLUGINS_DATA_DIR, 'budgie-' + PLUGIN, 'pics')
)

install_data(
    'budgie-wprviews-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

install_data('schema/org.ubuntubudgie.plugins.budgie-wpreviews.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

meson.add_install_script('meson_post_install')
