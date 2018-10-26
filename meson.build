project('budgie-extras',
	['vala', 'c'],
	version: '0.6.1.1',
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

# Global path variable
intltool = find_program('intltool-merge')
prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))
podir = join_paths(meson.source_root(), 'po')

LOCALE_DIR = join_paths(prefix, get_option('localedir'))
PLUGINS_INSTALL_DIR = join_paths(libdir, 'budgie-desktop',
	'plugins')
PIXMAPS_DIR = join_paths(datadir, 'pixmaps')
PLUGINS_DATA_DIR = join_paths(datadir, 'budgie-desktop',
	'plugins')
APPLICATIONS_DIR = join_paths(datadir, 'applications')

conf = configuration_data()
conf.set('PROJECT_NAME', meson.project_name())

message('Installing applets...')

subdir('po')
subdir('budgie-wpreviews')
subdir('budgie-wswitcher')
subdir('budgie-hotcorners')
subdir('budgie-quicknote')
subdir('budgie-wmover')
subdir('budgie-wsoverview')
subdir('budgie-showtime')
subdir('budgie-countdown')
subdir('budgie-keyboard-autoswitch')
subdir('budgie-rotation-lock')
subdir('budgie-clockworks')
subdir('budgie-dropby')
subdir('budgie-kangaroo')
subdir('budgie-weathershow')
subdir('budgie-trash')
subdir('budgie-app-launcher')
subdir('budgie-recentlyused')

#configure_file(
#	input: meson.project_name() + '.py.in',
#	output: meson.project_name() + '.py',
#	configuration: conf,
#	install_dir: APPLET_INSTALL_DIR
#)
