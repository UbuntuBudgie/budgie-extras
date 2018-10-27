configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', 'budgie-extras')
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)


custom_target('plugin-file-recently',
    input : 'BudgieRecentlyUsed.plugin.in',
    output : 'BudgieRecentlyUsed.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

#install_data('BudgieRecentlyUsed.plugin', install_dir: LIB_INSTALL_DIR)

BudgieRecentlyUsedSources = [
'budgie-recentlyused.vala'
]

BudgieRecentlyUsedDependencies = [
dependency('gtk+-3.0'),
dependency('budgie-1.0'),
dependency('libpeas-gtk-1.0'),
dependency('gee-0.8'),
meson.get_compiler('c').find_library('m', required: false)
]

BudgieRecentlyUsedValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

BudgieRecentlyUsedCArgs = [
'-include',
'config.h',
'-lm'
]

shared_library(
    'budgie-recentlyused',
    BudgieRecentlyUsedSources,
    dependencies: BudgieRecentlyUsedDependencies,
    vala_args: BudgieRecentlyUsedValaArgs,
    c_args: BudgieRecentlyUsedCArgs,
    install: true,
    install_dir: LIB_INSTALL_DIR
)
