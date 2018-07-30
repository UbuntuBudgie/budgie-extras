configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

install_data('HotCorners.plugin', install_dir: LIB_INSTALL_DIR)

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
meson.get_compiler('c').find_library('m', required: false)
]

HotCornersValaArgs = [
'--pkg=config', 
'--vapidir=' + VAPI_DIR, 
'--target-glib=2.38',
]

HotCornersCArgs = [
'-include', 
'config.h',
'-lm'
]

shared_library(
    'hotcorners', 
    HotCornersSources, 
    dependencies: HotCornersDependencies, 
    vala_args: HotCornersValaArgs, 
    c_args: HotCornersCArgs, 
    install: true, 
    install_dir: LIB_INSTALL_DIR
)




