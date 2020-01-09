substprog = find_program('subst.py')

install_data('shuffler-control.svg',
    install_dir: PIXMAPS_DIR
)

shufflertargetauto = custom_target('shufflerautostart',
  output : 'shufflerdaemon-autostart.desktop',
  input : 'shufflerdaemon-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@', podir],
  install : true,
  install_dir : join_paths(sysconfdir, 'xdg', 'autostart')
)

shufflerguitargetauto = custom_target('shufflerguiautostart',
  output : 'shufflergui-autostart.desktop',
  input : 'shufflergui-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@', podir],
  install : true,
  install_dir : join_paths(sysconfdir, 'xdg', 'autostart')
)

shufflertargetw = custom_target('shufflercontrols',
  output : 'shuffler-control.desktop',
  input : 'shuffler-control.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@', podir],
  install : true,
  install_dir : join_paths(datadir, 'applications')
)

