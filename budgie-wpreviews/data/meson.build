BDE_LOC=join_paths(datadir, 'budgie-extras-daemon')
substprog = find_program('subst.py')

mytarget1 = custom_target('preview_allbackward',
  output : 'preview_allbackward.bde',
  input : 'preview_allbackward.bde.in',
  command : [substprog, '@INPUT@', BDE_LOC, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget2 = custom_target('preview_allforward',
  output : 'preview_allforward.bde',
  input : 'preview_allforward.bde.in',
  command : [substprog, '@INPUT@', BDE_LOC, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget3 = custom_target('preview_currentbackward',
  output : 'preview_curentbackward.bde',
  input : 'preview_currentbackward.bde.in',
  command : [substprog, '@INPUT@', BDE_LOC, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget4 = custom_target('preview_currentforward',
  output : 'preview_currentforward.bde',
  input : 'preview_currentforward.bde.in',
  command : [substprog, '@INPUT@', BDE_LOC, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

AUTOSTART_LOC=join_paths(sysconfdir, 'xdg', 'autostart')

mytarget5 = custom_target('preview_creator',
  output : 'previews-creator-autostart.desktop',
  input : 'previews-creator-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : AUTOSTART_LOC
)

mytarget6 = custom_target('previews_daemon',
  output : 'previews-daemon-autostart.desktop',
  input : 'previews-daemon-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : AUTOSTART_LOC
)

APP_LOC=join_paths(datadir, 'applications')

mytarget7 = custom_target('previewscontrols',
  output : 'previewscontrols.desktop',
  input : 'previewscontrols.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : APP_LOC
)

PIXMAP=join_paths(datadir, 'pixmaps')
install_data('budgiewprviews.svg',
    install_dir: PIXMAP
)
