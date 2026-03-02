PLUGIN = 'budgie-screencast'

install_data('schema/org.ubuntubudgie.budgie-screencast.gschema.xml',
   install_dir: join_paths(prefix, datadir, 'glib-2.0', 'schemas')
)

SCREENCAST_INSTALL_DIR = join_paths(PLUGINS_INSTALL_DIR, PLUGIN)

message('Installing applet...')

subdir('src')
subdir('icons')

meson.add_install_script('meson_post_install')
