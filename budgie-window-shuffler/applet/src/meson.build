custom_target('plugin-file-windowshuffler',
    input : 'ShufflerApplet.plugin.in',
    output : 'ShufflerAPplet.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : APPLET_INSTALL_DIR)

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
    '--target-glib=2.38',
    '--vapidir=' + VAPI_DIR
]

ShufflerAppletCArgs = [
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    '-lm'
]

shared_library(
    'shufflerapplet', 
    ShufflerAppletSources, 
    dependencies: ShufflerAppletDependencies, 
    vala_args: ShufflerAppletValaArgs, 
    c_args: ShufflerAppletCArgs, 
    include_directories: config_inc_dir,
    install: true, 
    install_dir: APPLET_INSTALL_DIR
)




