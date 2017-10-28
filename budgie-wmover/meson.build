#gnome = import('gnome')

PLUGIN = 'wmover'

install_data(
    'WMover.plugin',
    'budgie-wmover.py',
    'wmover_run',
    'wmovertools.py',
    'wmover_panelrunner',
    'set_keys.py',
    'moverbar',

    install_dir: join_paths(PLUGINS_INSTALL_DIR, 'budgie-' + PLUGIN)
)

install_data(
    'wmover-bpanel.svg',
    install_dir: PIXMAPS_DIR
)
