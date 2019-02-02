#gnome = import('gnome')

PLUGIN = 'budgie-wsoverview'

install_data(
    'WsOverview.plugin',
    'wsotools.py',
    'budgie-wsoverview.py',
    install_dir: join_paths(PLUGINS_INSTALL_DIR, PLUGIN)
)

install_data(
    'numbers/ws1-symbolic.svg',
    'numbers/ws2-symbolic.svg',
    'numbers/ws3-symbolic.svg',
    'numbers/ws4-symbolic.svg',
    'numbers/ws5-symbolic.svg',
    'numbers/ws6-symbolic.svg',
    'numbers/ws7-symbolic.svg',
    'numbers/ws8-symbolic.svg',
    'numbers/ws9-symbolic.svg',
    'numbers/ws10-symbolic.svg',
    'numbers/ws11-symbolic.svg',
    'numbers/ws12-symbolic.svg',
    'numbers/ws13-symbolic.svg',
    'numbers/ws14-symbolic.svg',
    'numbers/ws15-symbolic.svg',
    'numbers/ws16-symbolic.svg',
    'numbers/ws17-symbolic.svg',
    'numbers/ws18-symbolic.svg',
    'numbers/ws19-symbolic.svg',
    'numbers/ws20-symbolic.svg',
    'numbers/ws21-symbolic.svg',
    'numbers/ws22-symbolic.svg',
    'numbers/ws23-symbolic.svg',
    'numbers/ws24-symbolic.svg',
    'budgie-wsoverview-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

install_data('schema/org.ubuntubudgie.plugins.budgie-wsoverview.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

meson.add_install_script('meson_post_install')
