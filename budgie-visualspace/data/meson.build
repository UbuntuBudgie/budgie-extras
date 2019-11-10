
install_data(
    'visualspace-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

AUTOSTART_LOC=join_paths(sysconfdir, 'xdg', 'autostart')
substprog = find_program('subst.py')

mytarget = custom_target('autoworkspace',
  output : 'visualspace-autostart.desktop',
  input : 'visualspace-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : AUTOSTART_LOC
)
