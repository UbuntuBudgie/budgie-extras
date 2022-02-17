substprog = find_program('subst.py')

install_data('wallstreet-control.svg',
    install_dir: join_paths(datadir, 'icons', 'hicolor', 'scalable', 'apps')
)

autostart_file = 'org.ubuntubudgie.wallstreet-autostart.desktop'
mytargeta = custom_target('wallstreetautostart',
  output : autostart_file,
  input : autostart_file + '.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@', podir],
  install : true,
  install_dir : xdg_appdir
)

desktop_file = 'org.ubuntubudgie.wallstreetcontrol.desktop'
mytargetw = custom_target('wallstreetcontrols',
  output : desktop_file,
  input : desktop_file + '.in',
  command : [substprog, '@INPUT@', LIB_INSTALL_DIR, '@OUTPUT@', podir],
  install : true,
  install_dir : join_paths(datadir, 'applications')
)

metainfo = 'org.ubuntubudgie.wallstreetcontrol.metainfo.xml'
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
