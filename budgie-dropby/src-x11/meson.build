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
    'budgie-dropby-idle.svg',
    'budgie-dropby-exit-symbolic.svg',
    'budgie-dropbybigsq-symbolic.svg',
    'budgie-dropbysmallsq-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

install_data('schema/org.ubuntubudgie.plugins.budgie-dropby.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

subdir('data')

meson.add_install_script('meson_post_install.py')
