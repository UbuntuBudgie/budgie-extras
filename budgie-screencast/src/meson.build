install_data('budgie-screencast.plugin', install_dir: SCREENCAST_INSTALL_DIR)

ScreencastSources = [
'Screencast.vala',
'RecorderControl.vala',
'ScreencastIcon.vala'
]

ScreencastDependencies = [
dependency('gtk+-3.0'), 
budgie_dep,
peas_dep,
dependency('gtk-layer-shell-0'),
dependency('libxfce4windowing-0'),
meson.get_compiler('c').find_library('m', required: false)
]

ScreencastValaArgs = [
  '--vapidir', VAPI_DIR,
  '--target-glib=2.38',
  '--pkg', 'posix',
]

ScreencastCArgs = [
 '-w'
]

shared_library(
    'budgie-screencast', 
    ScreencastSources, 
    dependencies: ScreencastDependencies, 
    vala_args: ScreencastValaArgs,
    c_args: ScreencastCArgs,
    install: true, 
    install_dir: SCREENCAST_INSTALL_DIR
)




