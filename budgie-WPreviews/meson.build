#gnome = import('gnome')

PLUGIN = 'wprviews'

install_data(
    'WPrviews.plugin',
    'wprviews.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, 'budgie-' + PLUGIN)
)

install_data(
    'wprviews-bpanel.svg',
    'wprviews-panel.svg',
    install_dir: PIXMAPS_DIR
)

install_data(
    'style.css',
    install_dir: join_paths(EXTRAS_DIR, PLUGIN, 'misc')
)

install_data(
    'wprviews_backgrounder',
    'wprviews_panelrunner',
    'wprviews_tools.py',
    'wprviews_window',
    install_dir: join_paths(EXTRAS_DIR, PLUGIN, 'code')
)
