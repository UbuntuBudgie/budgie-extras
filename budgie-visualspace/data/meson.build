
install_data(
    'visualspace-symbolic.svg',
    install_dir: PIXMAPS_DIR
)

install_data('org.ubuntubudgie.visualspace.metainfo.xml',
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

substprog = find_program('subst.py')

mytarget = custom_target('autoworkspace',
  output : 'visualspace-autostart.desktop',
  input : 'visualspace-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : xdg_appdir
)
