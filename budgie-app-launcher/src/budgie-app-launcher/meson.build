configdata= configuration_data()
configdata.set('PYTHON', python_loader)
plugininstall = configure_file(
    input: 'AppLauncher.plugin.in',
    output: 'AppLauncher.plugin',
    configuration: configdata
)

install_data(
    'App.py',
    'AppButton.py',
    plugininstall,
    'AppLauncher.py',
    'AppLauncherApplet.py',
    'ArrowButton.py',
    'DirectionalButton.py',
    'EditButton.py',
    'Error.py',
    'FilterHelper.py',
    'JsonHelper.py',
    'LocaleHelper.py',
    'Log.py',
    'MenuButton.py',
    'PanelButton.py',
    'SelectButton.py',
    'SortHelper.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, PLUGIN)
)
