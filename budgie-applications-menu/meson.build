i18n = import('i18n')
gnome = import('gnome')

asresources = gnome.compile_resources(
    'as-resources', 'applications-menu/data/icons.gresource.xml',
    source_dir: 'applications-menu/data',
    c_name: 'as'
)

prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))

LOCALE_DIR = join_paths(prefix, get_option('localedir'))

glib_dep = dependency('glib-2.0')
gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0')
gtk_dep = dependency('gtk+-3.0')
granite_dep = dependency('granite')
if granite_dep.version().version_compare('>=5.2')
    add_project_arguments('--define=GRANITE5', language: 'vala')
endif
gobject_dep = dependency('gobject-2.0')
libsoup_dep = dependency('libsoup-2.4')
appstream_dep = dependency('appstream')
gio_unix_dep = dependency('gio-unix-2.0')
json_glib_dep = dependency('json-glib-1.0')
zeitgeist_dep = dependency('zeitgeist-2.0')
libgnome_menu_dep = dependency('libgnome-menu-3.0')
posix_dep = meson.get_compiler('vala').find_library('posix')
libhandy_dep = dependency('libhandy-0.0')
budgie_dep = dependency('budgie-1.0')
peas_dep = dependency('libpeas-gtk-1.0')
plank_dep = dependency('plank', required: false)
if plank_dep.version().version_compare('>=0.10.9')
    add_project_arguments('--define=HAS_PLANK', language: 'vala')
endif

zeitgeist_dep = []

if get_option('with-zeitgeist')
    zeitgeist_dep = dependency('zeitgeist-2.0')
    add_project_arguments('--define=HAVE_ZEITGEIST', language: 'vala')
endif

subdir('applications-menu/src')
subdir('applications-menu/data')
#subdir('po')

meson.add_install_script('applications-menu/meson/post_install.py')
