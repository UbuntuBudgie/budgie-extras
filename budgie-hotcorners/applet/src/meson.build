
custom_target('plugin-file-hotcorners',
    input : 'HotCorners.plugin.in',
    output : 'HotCorners.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

#install_data('HotCorners.plugin', install_dir: LIB_INSTALL_DIR)

HotCornersSources = [
'HotCornersApplet.vala'
]

HotCornersDependencies = [
dependency('gtk+-3.0'),
dependency('budgie-1.0'),
dependency('json-glib-1.0'),
dependency('gio-2.0'),
dependency('gdk-3.0'),
dependency('libpeas-gtk-1.0'),
dependency('libnotify'),
meson.get_compiler('c').find_library('m', required: false)
]

HotCornersValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

HotCornersCArgs = [
'-lm'
]

shared_library(
    'hotcorners',
    HotCornersSources,
    dependencies: HotCornersDependencies,
    vala_args: HotCornersValaArgs,
    c_args: HotCornersCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: LIB_INSTALL_DIR
)




