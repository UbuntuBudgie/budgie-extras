
application_id = 'budgie-previews'

pkgdatadir = join_paths(libdir, application_id)

subdir('src')
subdir('data')

install_data('schema/org.ubuntubudgie.plugins.budgie-wpreviews.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)

meson.add_install_script('meson_post_install')

