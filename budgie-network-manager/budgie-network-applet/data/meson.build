custom_target('plugin-file-network',
    input : 'com.github.danielpinto8zz6.budgie-network-applet.plugin.in',
    output : 'com.github.danielpinto8zz6.budgie-network-applet.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : lib_install_dir)


#plugin_file = i18n.merge_file(
#  input: 'com.github.danielpinto8zz6.budgie-network-applet.plugin.in',
#  output: 'com.github.danielpinto8zz6.budgie-network-applet.plugin',
#  type: 'desktop',
#  po_dir: '../po',
#  install: true,
#  install_dir: lib_install_dir
#)

#plugin_utils = find_program('desktop-file-validate', required: false)
#if plugin_utils.found()
#  test('Validate plugin file', plugin_utils,
#    args: [plugin_file]
#  )
#endif
