project('budgie-extras',
	version: '0.1.5',
	meson_version: '>= 0.40.0'
)

#i18n = import('i18n')
python = import('python3')

message('Looking for dependencies')
python_bin = python.find_python()
if not python_bin.found()
	error('No python3 binary found')
else
	message('Found python3 binary')
endif
dependency('glib-2.0')
dependency('gobject-introspection-1.0', version: '>=1.51.1')
dependency('gtk+-3.0', version :'>=3.18')

# Global path variabel
prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))
runnerdir = get_option('sysconfdir')

PLUGINS_INSTALL_DIR = join_paths(libdir, 'budgie-desktop',
	'plugins')
PIXMAPS_DIR = join_paths(datadir, 'pixmaps')
EXTRAS_DIR = join_paths(runnerdir, meson.project_name())
APPLICATIONS_DIR = join_paths(datadir, 'applications')

conf = configuration_data()
conf.set('PROJECT_NAME', meson.project_name())

message('Installing applets...')

subdir('budgie-WPreviews')
subdir('budgie-wswitcher')
subdir('budgie-hotcorners')
subdir('budgie-quicknote')
subdir('wmover')
subdir('budgie-wsoverview')

#configure_file(
#	input: meson.project_name() + '.py.in',
#	output: meson.project_name() + '.py',
#	configuration: conf,
#	install_dir: APPLET_INSTALL_DIR
#)
