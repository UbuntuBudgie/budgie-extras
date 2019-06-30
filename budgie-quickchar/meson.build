application_id = 'quickchar'

prefix = get_option('prefix')
bindir = join_paths(prefix, get_option('bindir'))
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))
sysconfdir = join_paths(prefix, get_option('sysconfdir'))
pkgdatadir = join_paths(libdir, application_id)


subdir('quickchar/src')
subdir('quickchar/data')

install_data('quickchar/schema/org.ubuntubudgie.quickchar.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)
