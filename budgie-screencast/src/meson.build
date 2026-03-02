custom_target('plugin-file-screencast',
  input : 'BudgieScreencast.plugin.in',
  output : 'BudgieScreencast.plugin',
  command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
  install : true,
  install_dir : SCREENCAST_INSTALL_DIR)

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
  '--pkg=config',
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
  include_directories: config_inc_dir,
  install: true,
  install_dir: SCREENCAST_INSTALL_DIR
)
