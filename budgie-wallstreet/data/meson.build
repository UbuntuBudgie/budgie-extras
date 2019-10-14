substprog = find_program('subst.py')

install_data('wallstreet-control.svg',
    install_dir: PIXMAPS_DIR
)

install_data('wallstreet-autostart.desktop',
    install_dir: join_paths(sysconfdir, 'xdg', 'autostart')
)

mytargetw = custom_target('wallstreetcontrols',
  output : 'wallstreet-control.desktop',
  input : 'wallstreet-control.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@', podir],
  install : true,
  install_dir : join_paths(datadir, 'applications')
)
