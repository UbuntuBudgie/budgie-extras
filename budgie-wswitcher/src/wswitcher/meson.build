
custom_target('plugin-file-wswitcher',
    input : 'WallpaperSwitcher.plugin.in',
    output : 'WallpaperSwitcher.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

BudgieWSwitcherSources = [
'wallpaperswitcher.vala'
]

BudgieWSwitcherDependencies = [
dependency('gtk+-3.0'),
budgie_dep,
meson.get_compiler('c').find_library('m', required: false)
]

BudgieWSwitcherValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]


BudgieWSwitcherCArgs = [
]

shared_library(
    'wallpaperswitcher',
    BudgieWSwitcherSources,
    dependencies: BudgieWSwitcherDependencies,
    vala_args: BudgieWSwitcherValaArgs,
    c_args: BudgieWSwitcherCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: LIB_INSTALL_DIR
)




