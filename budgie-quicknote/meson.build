# QuickNote Applet build

configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', 'budgie-extras')
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)


PLUGIN='budgie-quicknote'
applet_quicknote_dir = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

custom_target('plugin-file-quicknote',
    input : 'QuickNoteApplet.plugin.in',
    output : 'QuickNoteApplet.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : applet_quicknote_dir)

applet_quicknote_sources = [
    'QuickNoteApplet.vala',
]

applet_quicknote_deps = [
dependency('gtk+-3.0'),
dependency('budgie-1.0'),
dependency('gio-2.0'),
dependency('gdk-3.0'),
dependency('libpeas-gtk-1.0'),
meson.get_compiler('c').find_library('m', required: false)
]

QuickNoteValaArgs = [
    '--pkg=config',
    '--target-glib=2.38',
    '--pkg', 'libpeas-1.0',
    '--pkg', 'gtk+-3.0',
    '--pkg', 'gio-unix-2.0',
    '--vapidir=' + VAPI_DIR,
]

QuickNoteCArgs = [
'-include',
'config.h',
'-lm'
]

shared_library(
    'quicknoteapplet',
    applet_quicknote_sources,
    dependencies: applet_quicknote_deps,
    vala_args: QuickNoteValaArgs,
    c_args: QuickNoteCArgs,
    install: true,
    install_dir: applet_quicknote_dir,
)


install_data(
    'budgie-quicknote-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

install_data(
    'org.ubuntubudgie.plugins.quicknote.gschema.xml',
    install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
)
