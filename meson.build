project('budgie-extras',
	['vala', 'c'],
	version: '1.5.0',
	meson_version: '>= 0.40.0'
)

i18n = import('i18n')

message('Looking for dependencies')

vala_version_required = '0.40.0'
vala = meson.get_compiler('vala')
VAPI_DIR = join_paths(meson.source_root(),
                      'vapi')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

am_cflags = []
add_global_arguments(am_cflags, language: 'c')

# Global path variable
intltool = find_program('intltool-merge')
prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
libexecdir = get_option('libexecdir')
datadir = join_paths(prefix, get_option('datadir'))
bindir = get_option('bindir')
sysconfdir = get_option('sysconfdir')

add_project_arguments(
    '-DPKGDATADIR="@0@"'.format(join_paths(get_option('prefix'), get_option('libdir'), 'wingpanel')),
    language: 'c'
)

podir = join_paths(meson.source_root(), 'po')

LOCALE_DIR = join_paths(prefix, get_option('localedir'))
PLUGINS_INSTALL_DIR = join_paths(libdir, 'budgie-desktop',
	'plugins')
PIXMAPS_DIR = join_paths(datadir, 'pixmaps')
PLUGINS_DATA_DIR = join_paths(datadir, 'budgie-desktop',
	'plugins')
APPLICATIONS_DIR = join_paths(datadir, 'applications')

NEWS = meson.source_root() + '/NEWS'

# Global configuration data - matches vapi/config.vapi strings
conf = configuration_data()
conf.set('PACKAGE_NAME', 'budgie-extras')
conf.set_quoted('PACKAGE_LOCALEDIR', LOCALE_DIR)
conf.set_quoted('PACKAGE_LIBDIR', libdir)
if libexecdir == 'libexec'
    libexecdir = join_paths(prefix, libexecdir)
endif
conf.set_quoted('PACKAGE_LIBEXECDIR', libexecdir)
if bindir == 'bin'
	bindir = join_paths(prefix, bindir)
endif
conf.set_quoted('PACKAGE_BINDIR', bindir)
conf.set_quoted('PACKAGE_SHAREDIR', datadir)

SHUFFLER = 'budgie-window-shuffler'
conf.set_quoted('SHUFFLER_DIR', join_paths(libdir, SHUFFLER))

PREVIEWS = 'budgie-previews'
conf.set_quoted('PREVIEWS_DIR', join_paths(libdir, PREVIEWS))

WSWITCHER = 'budgie-wswitcher'
conf.set_quoted('WSWITCHER_DIR', join_paths(PLUGINS_INSTALL_DIR, WSWITCHER))

with_stateless = get_option('with-stateless')
if with_stateless == true
    warning('Only use stateless option with a supported OS like Solus')
endif

xdg_appdir = get_option('xdg-appdir')
if xdg_appdir == ''
    if with_stateless == true
        xdg_appdir = join_paths(datadir, 'xdg', 'autostart')
    else
        xdg_appdir = join_paths(get_option('sysconfdir'), 'xdg', 'autostart')
    endif
endif


config_h = configure_file(
	output: 'config.h',
	configuration: conf
)

config_dep = declare_dependency(
	dependencies: vala.find_library('config', dirs: VAPI_DIR),
	sources: config_h
)

config_inc_dir = include_directories('.')


# Now lets install applets

message('Installing applets...')

build_all = get_option('build-all')
subdir('po')

build_applications_menu = get_option('build-applications-menu')
if build_all == true or build_applications_menu == true
	subdir('budgie-applications-menu')
endif

build_wswitcher = get_option('build-wswitcher')
if build_all == true or build_wswitcher == true
	subdir('budgie-wswitcher')
endif

build_hotcorners = get_option('build-hotcorners')
if build_all == true or build_hotcorners == true
	subdir('budgie-hotcorners')
endif

build_wpreviews = get_option('build-wpreviews')
if build_all == true or build_wpreviews == true
  subdir('budgie-wpreviews')
endif

build_quicknote = get_option('build-quicknote')
if build_all == true or build_quicknote == true
	subdir('budgie-quicknote')
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

build_extrasdaemon = get_option('build-extrasdaemon')
if build_all == true or build_extrasdaemon == true
	subdir('budgie-extras-daemon')
endif

build_workspacestopwatch = get_option('build-workspacestopwatch')
if build_all == true or build_workspacestopwatch == true
	subdir('budgie-workspace-stopwatch')
endif

build_quickchar = get_option('build-quickchar')
if build_all == true or build_quickchar == true
	subdir('budgie-quickchar')
endif

build_fuzzyclock = get_option('build-fuzzyclock')
if build_all == true or build_fuzzyclock == true
	subdir('budgie-fuzzyclock')
endif

build_brightness_controller = get_option('build-brightness-controller')
if build_all == true or build_brightness_controller == true
	subdir('budgie-brightness-controller')
endif

build_visualspace = get_option('build-visualspace')
if build_all == true or build_visualspace == true
	subdir('budgie-visualspace')
endif

build_wallstreet = get_option('build-wallstreet')
if build_all == true or build_wallstreet == true
	subdir('budgie-wallstreet')
endif

build_network_manager = get_option('build-network-manager')
if build_all == true or build_network_manager == true
	subdir('budgie-network-manager')
endif

build_window_shuffler = get_option('build-window-shuffler')
if build_all == true or build_window_shuffler == true
	subdir('budgie-window-shuffler')
endif

with_default_schema = get_option('with-default-schema')
if build_all == true and with_default_schema == true
	subdir('default-schema')
endif
