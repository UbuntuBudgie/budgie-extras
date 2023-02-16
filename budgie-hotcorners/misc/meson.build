hotcorners_config_data = configuration_data()
hotcorners_config_data.set('libexecdir', libexecdir)

hotcorners_config_data.set('bdesktopdir', join_paths(datadir, 'budgie-desktop'))
hotcorners_config_data.set('libdir', libdir)


hotcorners_defaults = configure_file(
    input: 'defaults.in.in',
    output: 'defaults.in',
    configuration: hotcorners_config_data,
)

custom_target('defaults.in',
    input : hotcorners_defaults,
    output : 'defaults',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : join_paths(datadir, 'budgie-hotcorners')
)


hotcorners_autostart_desktop = configure_file(
    input: 'org.ubuntubudgie.budgie-extras.HotCorners-autostart.desktop.in.in',
    output: 'org.ubuntubudgie.budgie-extras.HotCorners-autostart.desktop.in',
    configuration: hotcorners_config_data,
)

custom_target('desktop-file-hotcorners-autostart',
    input : hotcorners_autostart_desktop,
    output : 'org.ubuntubudgie.budgie-extras.HotCorners-autostart.desktop',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : xdg_appdir
)

hotcorners_desktop = configure_file(
    input: 'org.ubuntubudgie.budgie-extras.HotCorners.desktop.in.in',
    output: 'org.ubuntubudgie.budgie-extras.HotCorners.desktop.in',
    configuration: hotcorners_config_data,
)

custom_target('desktop-file-hotcorners',
    input : hotcorners_desktop,
    output : 'org.ubuntubudgie.budgie-extras.HotCorners.desktop',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : join_paths(datadir, 'applications'))
