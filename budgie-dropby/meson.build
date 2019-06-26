#gnome = import('gnome')

PLUGIN = 'budgie-dropby'

install_data(
    'BudgieDropBy.plugin',
    'dropby_tools.py',
    'budgie_dropby.py',
    'copy_flash',
    'checkonwin',
    'dropover',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, PLUGIN)
)

install_data(
    'budgie-dropby-symbolic.svg',
    'budgie-dropby-idle.png',
    'exit-dropby-symbolic.svg',
    install_dir: PIXMAPS_DIR
)
