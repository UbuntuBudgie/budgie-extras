custom_target('plugin-file-recently',
    input : 'BudgieRecentlyUsed.plugin.in',
    output : 'BudgieRecentlyUsed.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

BudgieRecentlyUsedSources = [
    'budgie-recentlyused.vala'
]

BudgieRecentlyUsedDependencies = [
dependency('gtk+-3.0'),
budgie_dep,
peas_dep,
dependency('gee-0.8'),
meson.get_compiler('c').find_library('m', required: false)
]

BudgieRecentlyUsedValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

BudgieRecentlyUsedCArgs = [
'-lm'
]

shared_library(
    'budgie-recentlyused',
    BudgieRecentlyUsedSources,
    dependencies: BudgieRecentlyUsedDependencies,
    vala_args: BudgieRecentlyUsedValaArgs,
    c_args: BudgieRecentlyUsedCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: LIB_INSTALL_DIR
)
