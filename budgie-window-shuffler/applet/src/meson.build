configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

install_data('ShufflerApplet.plugin', install_dir: LIB_INSTALL_DIR)

ShufflerAppletSources = [
'ShufflerApplet.vala'
]

ShufflerAppletDependencies = [
dependency('gtk+-3.0'),
dependency('gdk-3.0'),
dependency('budgie-1.0'),
dependency('libpeas-gtk-1.0'),
dependency('libnotify'),
dependency('libwnck-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

ShufflerAppletValaArgs = [
'--pkg=config', 
'--vapidir=' + VAPI_DIR, 
'--target-glib=2.38',
]

ShufflerAppletCArgs = [
'-include', 
'config.h',
'-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
'-lm'
]

shared_library(
    'shufflerapplet', 
    ShufflerAppletSources, 
    dependencies: ShufflerAppletDependencies, 
    vala_args: ShufflerAppletValaArgs, 
    c_args: ShufflerAppletCArgs, 
    install: true, 
    install_dir: LIB_INSTALL_DIR
)




