PLUGIN = 'budgie-hotcorners'

LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

message('Installing applet...')

subdir('src')
subdir('icons')

meson.add_install_script('meson_post_install.py')
