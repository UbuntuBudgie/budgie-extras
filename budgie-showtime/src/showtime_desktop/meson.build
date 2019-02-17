#configurationData = configuration_data()
#configurationData.set('PACKAGE_NAME', meson.project_name())
#configurationData.set('LOCALE_DIR', LOCALE_DIR)
#configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

#install_data('WeatherShow.plugin', install_dir: LIB_INSTALL_DIR)

BudgieShowTimeSources = [
'showtime_desktop.vala'
]

BudgieShowTimeDependencies = [
dependency('gtk+-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

BudgieShowTimeValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

BudgieShowTimeCArgs = [
'-include',
'config.h',
'-lm'
]

BudgieShowTimeCArgs = [
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
    'showtime_desktop', BudgieShowTimeSources,
    dependencies: BudgieShowTimeDependencies,
    install: true,
    vala_args: BudgieShowTimeValaArgs,
    c_args: BudgieShowTimeCArgs,
    install_dir: LIB_INSTALL_DIR,
)

