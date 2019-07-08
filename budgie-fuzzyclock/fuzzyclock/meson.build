# Fuzzy Clock Applet build

configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configurationData.set_quoted('GETTEXT_PACKAGE', meson.project_version())
add_global_arguments('-DGETTEXT_PACKAGE="budgie-desktop"', language: 'c')

custom_target('plugin-fuzzy-clock',
    input : 'FuzzyClockApplet.plugin.in',
    output : 'FuzzyClockApplet.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

fuzzy_applet_sources = [
    'FuzzyClockApplet.vala',
]

fuzzy_applet_deps = [
dependency('gtk+-3.0'),
dependency('budgie-1.0'),
dependency('gdk-3.0'),
dependency('libpeas-gtk-1.0'),
meson.get_compiler('c').find_library('m', required: false)
]

shared_library(
    'fuzzyclock', fuzzy_applet_sources,
    dependencies: fuzzy_applet_deps ,
    install: true,
    vala_args: [
        '--pkg', 'libpeas-1.0',
        '--pkg', 'gio-unix-2.0',
        '--pkg', 'gtk+-3.0',
    ],
    install_dir: LIB_INSTALL_DIR,
)
