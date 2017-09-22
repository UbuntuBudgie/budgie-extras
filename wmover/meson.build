#gnome = import('gnome')

PLUGIN = 'wmover'

install_data(
    'WMover.plugin',
    'wmover.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, 'budgie-' + PLUGIN)
)

install_data(
    'wmover-bpanel.svg',
    'wmover-panel.svg',
    install_dir: PIXMAPS_DIR
)

install_data(
    'style.css',
    install_dir: join_paths(EXTRAS_DIR, PLUGIN, 'misc')
)

install_data(
    'wmover_run',
    'wmovertools.py',
    'wmover_panelrunner',
    'moverbar',
    install_dir: join_paths(EXTRAS_DIR, PLUGIN, 'code')
)
