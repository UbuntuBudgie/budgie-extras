project('budgie-trash-applet', 'c',
        version: '2.0.0',
        default_options: [
            'warning_level=2',
            'c_std=gnu11',
        ],
)

add_project_arguments([
	'-I' + meson.current_build_dir(),
], language: 'c')

gnome = import('gnome')

#
# Global stuff
#

prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))
localedir = join_paths(prefix, get_option('localedir'))
podir = join_paths(meson.source_root(), 'po')

APPLET_INSTALL_DIR = join_paths(libdir, 'budgie-desktop', 'plugins', meson.project_name())

subdir('data')
subdir('style')
subdir('src')

gnome.post_install(
    glib_compile_schemas: true
)
