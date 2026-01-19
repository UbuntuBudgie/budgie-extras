custom_target('plugin-file-wswitcher',
    input : 'RavenWallpaperSwitcher.plugin.in',
    output : 'RavenWallpaperSwitcher.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : RAVEN_LIB_INSTALL_DIR)

BudgieWSwitcherSources = [
'ravenwallpaperswitcher.vala'
]

BudgieWSwitcherDependencies = [
dependency('gtk+-3.0'),
raven_dep,
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
    WIDGET,
    BudgieWSwitcherSources,
    dependencies: BudgieWSwitcherDependencies,
    vala_args: BudgieWSwitcherValaArgs,
    c_args: BudgieWSwitcherCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: RAVEN_LIB_INSTALL_DIR
)
