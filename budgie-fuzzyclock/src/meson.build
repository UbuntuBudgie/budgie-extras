# Fuzzy Clock Applet build

configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', 'budgie-extras')
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

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

FuzzyValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

FuzzyCArgs = [
'-include',
'config.h',
'-lm'
]

shared_library(
    'fuzzyclock', fuzzy_applet_sources,
    dependencies: fuzzy_applet_deps ,
    install: true,
    vala_args: FuzzyValaArgs,
    c_args: FuzzyCArgs,
    install_dir: LIB_INSTALL_DIR,
)
