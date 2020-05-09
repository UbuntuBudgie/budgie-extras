
BudgieShowTimeSources = [
'showtime_desktop.vala'
]

BudgieShowTimeDependencies = [
dependency('libwnck-3.0'),
dependency('gtk+-3.0'),
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

executable(
    'showtime_desktop', BudgieShowTimeSources,
    dependencies: BudgieShowTimeDependencies,
    install: true,
    vala_args: BudgieShowTimeValaArgs,
    c_args: BudgieShowTimeCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

