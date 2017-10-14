#gnome = import('gnome')

PLUGIN = 'wmover'

install_data(
    'WMover.plugin',
    'budgie-wmover.py',
    'wmover_run',
    'wmovertools.py',
    'wmover_panelrunner',
    'moverbar',

    install_dir: join_paths(PLUGINS_INSTALL_DIR, 'budgie-' + PLUGIN)
)

install_data(
    'wmover-bpanel.svg',
    'wmover-panel.svg',
    install_dir: PIXMAPS_DIR
)
