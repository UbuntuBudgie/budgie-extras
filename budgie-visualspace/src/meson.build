configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

install_data('VisualSpace.plugin', install_dir: LIB_INSTALL_DIR)

VisualSPaceSources = [
'visualspace.vala'
]

VisualSPaceDependencies = [
dependency('gtk+-3.0'), 
dependency('budgie-1.0'),
dependency('gdk-x11-3.0'),
dependency('libwnck-3.0'),
dependency('libpeas-gtk-1.0')
]

# dependency('gio-2.0'),
# dependency('gdk-3.0'),

VisualSpaceArgs = [
'--pkg=config', 
'--vapidir=' + VAPI_DIR, 
'--target-glib=2.38',
]

VisualSPaceCArgs = [
'-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
'-include', 
'config.h',
'-lm'
]

shared_library(
    'visualspace', 
    VisualSPaceSources, 
    dependencies: VisualSPaceDependencies, 
    vala_args: VisualSpaceArgs, 
    c_args: VisualSPaceCArgs, 
    install: true, 
    install_dir: LIB_INSTALL_DIR
)




