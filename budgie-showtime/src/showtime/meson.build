configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

custom_target('plugin-file-showtime',
    input : 'ShowTime.plugin.in',
    output : 'ShowTime.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

BudgieShowTimeSources = [
'BudgieShowTime.vala'
]

BudgieShowTimeDependencies = [
dependency('gtk+-3.0'),
dependency('budgie-1.0'),
dependency('gio-2.0'),
dependency('gdk-3.0'),
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

shared_library(
    'budgieshowtime',
    BudgieShowTimeSources,
    dependencies: BudgieShowTimeDependencies,
    vala_args: BudgieShowTimeValaArgs,
    c_args: BudgieShowTimeCArgs,
    install: true,
    install_dir: LIB_INSTALL_DIR
)




