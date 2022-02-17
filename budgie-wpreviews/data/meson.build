BDE_LOC=join_paths(datadir, 'budgie-extras-daemon')
substprog = find_program('subst.py')

mytarget1 = custom_target('preview_allbackward',
  output : 'preview_allbackward.bde',
  input : 'preview_allbackward.bde.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget2 = custom_target('preview_allforward',
  output : 'preview_allforward.bde',
  input : 'preview_allforward.bde.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget3 = custom_target('preview_currentbackward',
  output : 'preview_currentbackward.bde',
  input : 'preview_currentbackward.bde.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget4 = custom_target('preview_currentforward',
  output : 'preview_currentforward.bde',
  input : 'preview_currentforward.bde.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget3a = custom_target('preview_currentbackward_grave',
  output : 'preview_currentbackward_grave.bde',
  input : 'preview_currentbackward_grave.bde.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget4a = custom_target('preview_currentforward_grave',
  output : 'preview_currentforward_grave.bde',
  input : 'preview_currentforward_grave.bde.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)


mytarget5 = custom_target('preview_creator',
  output : 'org.ubuntubudgie.previews-creator-autostart.desktop',
  input : 'org.ubuntubudgie.previews-creator-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : xdg_appdir
)

mytarget6 = custom_target('previews_daemon',
  output : 'org.ubuntubudgie.previews-daemon-autostart.desktop',
  input : 'org.ubuntubudgie.previews-daemon-autostart.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@'],
  install : true,
  install_dir : xdg_appdir
)

APP_LOC=join_paths(datadir, 'applications')

mytarget7 = custom_target('previewscontrols',
  output : 'org.ubuntubudgie.previewscontrols.desktop',
  input : 'org.ubuntubudgie.previewscontrols.desktop.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@', podir],
  install : true,
  install_dir : APP_LOC
)

metainfo = 'org.ubuntubudgie.previewscontrols.metainfo.xml'
ascli_exe = find_program('appstreamcli')
metainfo_with_relinfo = custom_target('gen-metainfo-rel',
    input : [NEWS, metainfo + '.in'],
    output : [metainfo],
    install : true,
    install_dir: join_paths(datadir, 'metainfo'),
    command : [ascli_exe, 'news-to-metainfo', '--limit=6', '@INPUT0@', '@INPUT1@', '@OUTPUT@']
)

# Validate MetaInfo file
test('validate metainfo file',
      ascli_exe,
      args: ['validate',
              '--no-net',
              '--pedantic',
              metainfo_with_relinfo]
)

PIXMAP=join_paths(datadir, 'pixmaps')
install_data('budgiewprviews.svg',
    install_dir: join_paths(datadir, 'icons', 'hicolor', 'scalable', 'apps'),
)
