
custom_target('plugin-file-weather',
    input : 'WeatherShow.plugin.in',
    output : 'WeatherShow.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

#install_data('WeatherShow.plugin', install_dir: LIB_INSTALL_DIR)

WeatherShowSources = [
'WeatherShow.vala'
]

WeatherShowDependencies = [
dependency('gtk+-3.0'),
dependency('budgie-1.0'),
dependency('gee-0.8'),
dependency('libsoup-3.0'),
dependency('libpeas-gtk-1.0'),
dependency('json-glib-1.0'),
dependency('libpeas-gtk-1.0'),
meson.get_compiler('c').find_library('m', required: false)
]

WeatherShowValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

WeatherShowCArgs = [
'-lm'
]

shared_library(
    'weathershow',
    WeatherShowSources,
    vala_args: WeatherShowValaArgs,
    dependencies: WeatherShowDependencies,
    c_args: WeatherShowCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: LIB_INSTALL_DIR
)

