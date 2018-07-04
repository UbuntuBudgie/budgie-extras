#gnome = import('gnome')

PLUGIN = 'weathershow'

install_data(
    'colorpicker',
    'WeatherShow.plugin',
    'getweather.py',
    'weathershow_desktop',
    'weathershow.py',
    'weathertools.py',
    'wshow_panelrunner',
    'cities',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, 'budgie-' + PLUGIN)
)

install_data(
    'icons_for_pixmaps/budgie-wticon-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

subdir('misc_icons')
subdir('weather_icons')
