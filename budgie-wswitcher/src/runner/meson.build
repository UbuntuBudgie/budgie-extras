
BudgieWSwitcherSources = [
'wallpaperswitcher_runner.vala'
]

BudgieWSwitcherDependencies = [
dependency('libxfce4windowing-0'),
dependency('gtk+-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

BudgieWSwitcherValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

executable(
    'wallpaperswitcher_runner', BudgieWSwitcherSources,
    dependencies: BudgieWSwitcherDependencies,
    install: true,
    vala_args: BudgieWSwitcherValaArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

