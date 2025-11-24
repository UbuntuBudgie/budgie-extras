
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
dependency('libwnck-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

BudgieShowTimeValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]


BudgieShowTimeCArgs = [
'-lm',
'-DWNCK_I_KNOW_THIS_IS_UNSTABLE'
]

shared_library(
    'budgieshowtime',
    BudgieShowTimeSources,
    dependencies: BudgieShowTimeDependencies,
    vala_args: BudgieShowTimeValaArgs,
    c_args: BudgieShowTimeCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: LIB_INSTALL_DIR
)




