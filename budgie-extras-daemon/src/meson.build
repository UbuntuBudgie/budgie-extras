daemon_name = 'budgie-extras-daemon'


custom_target('desktop-file-daemon',
    input : 'budgie-extras-daemon.desktop.in',
    output : 'budgie-extras-daemon.desktop',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : join_paths(get_option('sysconfdir'), 'xdg', 'autostart'))

subdir('config')

ExtrasDaemonSources = [
'main.vala',
'manager.vala',
'dbus.vala',
'layouts.vala'
]

ExtrasDaemonDependencies = [
dependency('gtk+-3.0'),
dependency('keybinder-3.0'),
link_libconfig
]

ExtrasDaemonValaArgs = [
'--pkg=keybinder-3.0',
'--pkg=daemon',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

ExtrasDaemonCArgs = [
'-include',
'config.h',
'-lm'
]

executable(
    daemon_name, ExtrasDaemonSources,
    dependencies: ExtrasDaemonDependencies,
    vala_args: ExtrasDaemonValaArgs,
    c_args: ExtrasDaemonCArgs,
    install: true,
    install_dir: join_paths(prefix, get_option('bindir'))
)

install_data(
    join_paths('.', 'examplebde', 'example.bde'),
    install_dir: join_paths(prefix, get_option('datadir'), daemon_name)
)

install_data('invoke.py',
    install_dir: LIB_INSTALL_DIR)

install_man('budgie-extras-daemon.1')
