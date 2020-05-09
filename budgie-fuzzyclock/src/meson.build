# Fuzzy Clock Applet build

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
'-lm'
]

shared_library(
    'fuzzyclock', fuzzy_applet_sources,
    dependencies: fuzzy_applet_deps ,
    install: true,
    vala_args: FuzzyValaArgs,
    c_args: FuzzyCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)
