configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', 'budgie-extras')
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)


custom_target('desktop-file-daemon',
    input : 'budgie-extras-daemon.desktop.in',
    output : 'budgie-extras-daemon.desktop',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : join_paths(datadir, 'applications'))

ExtrasDaemonSources = [
'main.vala',
'manager.vala'
]

ExtrasDaemonDependencies = [
dependency('gtk+-3.0'),
dependency('gio-2.0'),
dependency('gdk-3.0'),
dependency('keybinder-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

ExtrasDaemonValaArgs = [
'--pkg=keybinder-3.0',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

ExtrasDaemonCArgs = [
'-include',
'config.h',
'-lm'
]

shared_library(
    'ExtrasDaemon',
    ExtrasDaemonSources,
    dependencies: ExtrasDaemonDependencies,
    vala_args: ExtrasDaemonValaArgs,
    c_args: ExtrasDaemonCArgs,
    install: true,
    install_dir: LIB_INSTALL_DIR
)
