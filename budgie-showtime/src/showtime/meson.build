
custom_target('plugin-file-showtime',
    input : 'ShowTime.plugin.in',
    output : 'ShowTime.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

BudgieShowTimeSources = [
'BudgieShowTime.vala'
]

if for_wayland == false
    BudgieShowTimeDependencies = [
    dependency('gtk+-3.0'),
    budgie_dep,
    dependency('gio-2.0'),
    dependency('gdk-3.0'),
    dependency('libwnck-3.0'),
    meson.get_compiler('c').find_library('m', required: false)
    ]
    BudgieShowTimeCArgs = [
    '-lm',
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE'
    ]

else
    BudgieShowTimeDependencies = [
    dependency('gtk+-3.0'),
    budgie_dep,
    dependency('gio-2.0'),
    dependency('gdk-3.0'),
    dependency('libxfce4windowing-0', version: '>= 4.19.1'),
    meson.get_compiler('c').find_library('m', required: false)
    ]
    BudgieShowTimeCArgs = [
    '-lm',
    ]

endif

budgie_applet_vala_args = []

if for_wayland == true
    budgie_applet_vala_args += ['-D', 'FOR_WAYLAND']
endif

BudgieShowTimeValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
budgie_applet_vala_args
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




