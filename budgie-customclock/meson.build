# Custom Clock Applet build

gnome = import('gnome')

custom_target('plugin-file-customclock',
    input : 'CustomClockApplet.plugin.in',
    output : 'CustomClockApplet.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

gresource = join_paths(meson.current_source_dir(), 'plugin.gresource.xml')

# Compile the assets into the binary
applet_clock_resources = gnome.compile_resources(
    'clock-applet-resources',
    gresource,
    source_dir: meson.current_source_dir(),
    c_name: 'budgie_customclock',
)

applet_clock_sources = [
    'CustomClockApplet.vala',
    applet_clock_resources,
]


shared_library(
    'customclockapplet',
    applet_clock_sources,
    dependencies: [
        dependency('budgie-1.0'),
        dependency('gtk+-3.0'),
        dependency('gio-unix-2.0'),
        dependency('libpeas-gtk-1.0'),
        meson.get_compiler('c').find_library('m', required: false)
    ],
    vala_args: [
        '--pkg', 'gtk+-3.0',
        '--pkg', 'glib-2.0',
        '--pkg', 'gio-unix-2.0',
        '--pkg', 'libpeas-1.0',
        # Make gresource work
        '--target-glib=2.38',
        '--gresources=' + gresource,
        '--vapidir=' + VAPI_DIR,
    ],
    install: true,
    install_dir: LIB_INSTALL_DIR,
)

install_data(
    'org.ubuntubudgie.budgie-customclock.gschema.xml',
    install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
)

meson.add_install_script('meson_post_install.py')