#gnome = import('gnome')

PLUGIN = 'budgie-countdown'

configdata= configuration_data()
configdata.set('PYTHON', python_loader)
plugininstall = configure_file(
    input: 'CountDown.plugin.in',
    output: 'CountDown.plugin',
    configuration: configdata
)

install_data(
    plugininstall,
    'budgie-countdown.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, PLUGIN)
)

install_data(
    'cr_green.png',
    'cr_red.png',
    'cr_yellow.png',
    'cr_panelspacer.png',
    'cr_grey.png',
    'budgie-countdown-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

install_data('schema/org.ubuntubudgie.plugins.budgie-countdown.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

meson.add_install_script('meson_post_install.py')
