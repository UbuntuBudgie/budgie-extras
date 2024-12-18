#configurationData = configuration_data()
#configurationData.set('PACKAGE_NAME', meson.project_name())
#configurationData.set('LOCALE_DIR', LOCALE_DIR)
#configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

#install_data('WeatherShow.plugin', install_dir: LIB_INSTALL_DIR)

DesktopWeatherSources = [
'desktop_weather.vala'
]

DesktopWeatherDependencies = [
dependency('gtk+-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

budgie_display_vala_args = []
if for_wayland == true
    dep_wayland = [
        dependency('gtk-layer-shell-0'),
        dependency('libxfce4windowing-0', version: '>= 4.19.7'),
    ]
    budgie_display_vala_args += ['-D', 'FOR_WAYLAND']
    DesktopWeatherDependencies += dep_wayland
else
    budgie_display_vala_args += ['-D', 'FOR_X11']
endif

DesktopWeatherValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
budgie_display_vala_args,
]

#DesktopWeatherCArgs = [
#'-include',
#'config.h',
#'-lm'
#]

DesktopWeatherCArgs = [
'-lm'
]

#shared_library(
#    'weathershow',
#    WeatherShowSources,
#    dependencies: WeatherShowDependencies,
#    vala_args: WeatherShowValaArgs,
#    c_args: WeatherShowCArgs,
#    install: true,
#    install_dir: LIB_INSTALL_DIR
#)


executable(
    'desktop_weather', DesktopWeatherSources,
    dependencies: DesktopWeatherDependencies,
    install: true,
    vala_args: DesktopWeatherValaArgs,
    c_args: DesktopWeatherCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)



