
custom_target('plugin-file-weather',
    input : 'WeatherShow.plugin.in',
    output : 'WeatherShow.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

#install_data('WeatherShow.plugin', install_dir: LIB_INSTALL_DIR)

WeatherShowSources = [
'WeatherShow.vala',
'position_picker.vala'
]

budgie_soup_vala_args = []
dep_soup = dependency('libsoup-2.4', required: false)
if dep_soup.found()
    budgie_soup_vala_args += ['-D', 'HAVE_SOUP_2_4']
else
    dep_soup = dependency('libsoup-3.0')
        if dep_soup.found()
            budgie_soup_vala_args += ['-D', 'HAVE_SOUP_3']
        endif
endif

WeatherShowDependencies = [
dependency('gtk+-3.0'),
budgie_dep,
dependency('gee-0.8'),
dep_soup,
peas_dep,
dependency('json-glib-1.0'),
meson.get_compiler('c').find_library('m', required: false)
]

budgie_weathershow_vala_args = []
if for_wayland == true
    WeatherShowDependencies += dependency('libxfce4windowing-0', version: '>= 4.19.7')
    budgie_weathershow_vala_args += ['-D', 'FOR_WAYLAND']
endif


WeatherShowValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
budgie_soup_vala_args,
budgie_weathershow_vala_args
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

