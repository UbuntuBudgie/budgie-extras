
# Dependencies
dep_budgie = dependency('budgie-1.0', version: '>= 2')
dep_gtk3 = dependency('gtk+-3.0', version: '>= 3.22.0')
dep_glib = dependency('glib-2.0', version: '>= 2.46.0')

PLUGIN = 'budgie-trash'
SRC_DIR = join_paths(meson.source_root(), PLUGIN, 'trash')
APPLET_INSTALL_DIR = join_paths(libdir, 'budgie-desktop', 'plugins', PLUGIN)
data_dir = join_paths(SRC_DIR, 'data')

subdir('trash/src')
