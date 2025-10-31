#gnome = import('gnome')

PLUGIN = 'budgie-kangaroo'

configdata= configuration_data()
configdata.set('PYTHON', python_loader)
plugininstall = configure_file(
    input: 'BudgieKangaroo.plugin.in',
    output: 'BudgieKangaroo.plugin',
    configuration: configdata
)

install_data(
    plugininstall,
    'budgie_kangaroo.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, PLUGIN)
)

install_data(
    'budgie-foldertrack-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

subdir('data')
