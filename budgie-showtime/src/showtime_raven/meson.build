
custom_target('plugin-file-showtime',
    input : 'ShowTime.plugin.in',
    output : 'ShowTime.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : RAVEN_INSTALL_DIR)

BudgieRavenShowTimeSources = [
'BudgieRavenShowTime.vala'
]

BudgieRavenShowTimeDependencies = [
    dependency('gtk+-3.0'),
    raven_dep,
    peas_dep,
    dependency('gio-2.0'),
    dependency('gdk-3.0'),
    dependency('libxfce4windowing-0', version: '>= 4.19.1'),
    meson.get_compiler('c').find_library('m', required: false)
    ]
    BudgieRavenShowTimeCArgs = [
    '-lm',
]

budgie_applet_vala_args = []
budgie_applet_vala_args += ['-D', 'FOR_WAYLAND']

BudgieRavenShowTimeValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
budgie_applet_vala_args
]


shared_library(
    WIDGET,
    BudgieRavenShowTimeSources,
    dependencies: BudgieRavenShowTimeDependencies,
    vala_args: BudgieRavenShowTimeValaArgs,
    c_args: BudgieRavenShowTimeCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: RAVEN_INSTALL_DIR
)




