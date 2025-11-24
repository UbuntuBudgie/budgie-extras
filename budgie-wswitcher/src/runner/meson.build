
BudgieWSwitcherSources = [
'wallpaperswitcher_runner.vala'
]

BudgieWSwitcherDependencies = [
dependency('libwnck-3.0'),
dependency('gtk+-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

BudgieWSwitcherValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

BudgieWSwitcherCArgs = [
'-DWNCK_I_KNOW_THIS_IS_UNSTABLE'
]

executable(
    'wallpaperswitcher_runner', BudgieWSwitcherSources,
    dependencies: BudgieWSwitcherDependencies,
    install: true,
    vala_args: BudgieWSwitcherValaArgs,
    c_args: BudgieWSwitcherCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

