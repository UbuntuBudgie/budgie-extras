#gnome = import('gnome')

PLUGIN = 'budgie-showtime'

install_data(
    'BudgieShowTime.plugin',
    'budgie_showtime.py',
    'clocktools.py',
    'colorpicker',
    'ShowTime',
    'bshowtime_panelrunner',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, PLUGIN)
)

install_data(
    'bshowtime-bpanel.svg',
    install_dir: PIXMAPS_DIR
)
