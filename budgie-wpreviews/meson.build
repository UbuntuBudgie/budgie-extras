#gnome = import('gnome')

PLUGIN = 'wprviews'

install_data(
    'WPrviews.plugin',
    'budgie-wprviews.py',
    'wprviews_backgrounder',
    'wprviews_panelrunner',
    'wprviews_tools.py',
    'set_keys.py',
    'wprviews_window',
    'moveto.sh',
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
    'wprviews-bpanel.svg',
    'wprviews-panel.svg',
    install_dir: PIXMAPS_DIR
)
