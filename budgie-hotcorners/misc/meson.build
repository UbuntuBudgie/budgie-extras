install_data('defaults', install_dir: join_paths(datadir, 'budgie-hotcorners'))

hotcornersgetauto = custom_target('hotcornersautostart',
  output : 'org.ubuntubudgie.budgie-extras.HotCorners-autostart.desktop',
  input : 'org.ubuntubudgie.budgie-extras.HotCorners-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@', podir],
  install : true,
  install_dir : xdg_appdir
)
