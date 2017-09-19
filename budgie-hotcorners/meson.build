#gnome = import('gnome')

PLUGIN = 'hcorners'

install_data(
    'BHCorners.plugin',
    'bhcorners.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, 'budgie-' + PLUGIN)
)

install_data(
    'bhcorners.svg',
    'bhcorners-bpanel.svg',
    'bhcpanel.svg',
    install_dir: PIXMAPS_DIR
)

install_data(
    'bhcorners.desktop',
    install_dir: APPLICATIONS_DIR
)

install_data(
    'bhcorners',
    'bhc-panelrunner',
    'bhcsettings',
    'bhctools.py',
    install_dir: join_paths(EXTRAS_DIR, 'budgie-hotcorners', 'code')
)
