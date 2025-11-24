project(
  'quickchar',
  version: '0.1',
  license: 'GPL3+',
  meson_version: '>= 0.40.0'
)


application_id = 'quickchar'

prefix = get_option('prefix')
bindir = join_paths(prefix, get_option('bindir'))
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))
sysconfdir = join_paths(prefix, get_option('sysconfdir'))
pkgdatadir = join_paths(libdir, application_id)
xdg_appdir = join_paths(get_option('sysconfdir'), 'xdg', 'autostart')
NEWS = meson.source_root() + '/NEWS'

subdir('src')
subdir('data')

install_data('schema/org.ubuntubudgie.quickchar.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)
