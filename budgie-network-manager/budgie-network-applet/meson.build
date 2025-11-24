project('com.github.danielpinto8zz6.budgie-network-applet',
        ['vala', 'c'],
        version: '1.0',
        meson_version: '>=0.40.0',
        license: 'GPL2')

i18n=import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

VAPI_DIR = join_paths(meson.source_root(),
                      'vapi')

budgie_dep=dependency('budgie-1.0', version: '>=2')
i18n=import('i18n')
intltool = find_program('intltool-merge')
podir = join_paths(meson.source_root(), 'po')
prefix = get_option('prefix')

lib_install_dir=join_paths(get_option('prefix'), get_option(
    'libdir'), 'budgie-desktop', 'plugins', meson.project_name())

subdir('src')
subdir('data')
subdir('po')
