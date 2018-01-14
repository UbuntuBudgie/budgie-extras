#gnome = import('gnome')

PLUGIN = 'hcorners'

install_data(
    'BudgieHotCorners.plugin',
    'budgie_hcorners.py',
    'bhcorners',
    'showdesktop',
    'bhctools.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, 'budgie-' + PLUGIN)
)

install_data(
    'budgie-hotcorners-symbolic.svg',
    install_dir: PIXMAPS_DIR
)
