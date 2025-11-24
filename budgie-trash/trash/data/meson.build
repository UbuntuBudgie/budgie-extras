install_data('TrashApplet.plugin', 
    install_dir: APPLET_INSTALL_DIR
)

install_data('com.github.ebonjaeger.budgie-trash-applet.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

appstream_file = 'com.github.ebonjaeger.budgie-trash-applet.appdata.xml'
install_data(appstream_file, install_dir: join_paths(get_option('datadir'), 'metainfo'))

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

# Validate MetaInfo file
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('validate metainfo file',
        appstream_util,
        args: ['validate', join_paths(meson.current_source_dir(), appstream_file)]
  )
endif
