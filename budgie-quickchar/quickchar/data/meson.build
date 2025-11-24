install_data(
    'chardata',
    install_dir: join_paths(datadir, application_id)
)


install_data(
    'quickchar-autostart.desktop',
    install_dir: xdg_appdir
)

substprog = find_program('subst.py')
desktopfile = custom_target('desktopfile',
  output : 'org.ubuntubudgie.quickchar.desktop',
  input : 'org.ubuntubudgie.quickchar.desktop.in',
  command : [substprog, '@INPUT@', pkgdatadir, '@OUTPUT@'],
  install : true,
  install_dir : join_paths(datadir, 'applications')
)

metainfo = 'org.ubuntubudgie.quickchar.metainfo.xml'
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


install_data(
    'quickchar.bde',
    install_dir: join_paths(datadir, 'budgie-extras-daemon')
)

install_data(
    'org.ubuntubudgie.quickchar.svg',
    install_dir: join_paths(datadir, 'icons', 'hicolor', 'scalable', 'apps')
)

meson.add_install_script(
  'meson_post_install.py',
  datadir,
  bindir,
  pkgdatadir,
  application_id
)
