application_id = 'budgie-visualspace'

prefix = get_option('prefix')
#bindir = join_paths(prefix, get_option('bindir'))
libdir = join_paths(prefix, get_option('libdir'))
#datadir = join_paths(prefix, get_option('datadir'))
#sysconfdir = join_paths(prefix, get_option('sysconfdir'))
pkgdatadir = join_paths(libdir, application_id)

install_data(
    'navtrigger.sh',
    'shownav',
    'shownav_tools.py',
    'space_switcher',
    'visualspace',
    install_dir: pkgdatadir
)

install_data(
    'vs-left.bde',
    'vs-right.bde',
    install_dir: join_paths(datadir, 'budgie-extras-daemon')
)

install_data('schema/org.ubuntubudgie.budgie-visualspace.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

meson.add_install_script('meson_post_install.py')