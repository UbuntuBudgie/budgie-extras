project('budgie-extras',
	['vala', 'c'],
	version: '0.8.2',
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

VAPI_DIR = join_paths(meson.source_root(),
                      'vapi')

message('Installing applets...')

build_all = get_option('build-all')
subdir('po')

build_wpreviews = get_option('build-wpreviews')
if build_all == true or build_wpreviews == true
  subdir('budgie-wpreviews')
endif

build_wswitcher = get_option('build-wswitcher')
if build_all == true or build_wswitcher == true
	subdir('budgie-wswitcher')
endif

build_hotcorners = get_option('build-hotcorners')
if build_all == true or build_hotcorners == true
	subdir('budgie-hotcorners')
endif

build_quicknote = get_option('build-quicknote')
if build_all == true or build_quicknote == true
	subdir('budgie-quicknote')
endif

build_wmover = get_option('build-wmover')
if build_all == true or build_wmover == true
	subdir('budgie-wmover')
endif

build_wsoverview = get_option('build-wsoverview')
if build_all == true or build_wsoverview == true
	subdir('budgie-wsoverview')
endif

build_showtime = get_option('build-showtime')
if build_all == true or build_showtime == true
	subdir('budgie-showtime')
endif

build_countdown = get_option('build-countdown')
if build_all == true or build_countdown == true
	subdir('budgie-countdown')
endif

build_clockworks = get_option('build-clockworks')
if build_all == true or build_clockworks == true
	subdir('budgie-clockworks')
endif

build_keyboard_autoswitch = get_option('build-keyboard-autoswitch')
if build_all == true or build_keyboard_autoswitch == true
	subdir('budgie-keyboard-autoswitch')
endif

build_rotation_lock = get_option('build-rotation-lock')
if build_all == true or build_rotation_lock == true
	subdir('budgie-rotation-lock')
endif

build_dropby = get_option('build-dropby')
if build_all == true or build_dropby == true
	subdir('budgie-dropby')
endif

build_kangaroo = get_option('build-kangaroo')
if build_all == true or build_kangaroo == true
	subdir('budgie-kangaroo')
endif

build_weathershow = get_option('build-weathershow')
if build_all == true or build_weathershow == true
	subdir('budgie-weathershow')
endif

build_trash = get_option('build-trash')
if build_all == true or build_trash == true
	subdir('budgie-trash')
endif

build_app_launcher = get_option('build-app-launcher')
if build_all == true or build_app_launcher == true
	subdir('budgie-app-launcher')
endif

build_recentlyused = get_option('build-recentlyused')
if build_all == true or build_recentlyused == true
	subdir('budgie-recentlyused')
endif

build_takeabreak = get_option('build-takeabreak')
if build_all == true or build_takeabreak == true
	subdir('budgie-takeabreak')
endif
