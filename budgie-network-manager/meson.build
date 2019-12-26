PLUGIN = 'budgie-network-manager'

add_project_arguments(
    '--vapidir', join_paths(meson.current_source_dir(), 'budgie-network-applet', 'vapi'),
    language: 'vala'
)

lib_install_dir = join_paths(get_option('prefix'), get_option(
    'libdir'), 'budgie-desktop', 'plugins', PLUGIN)

subdir('budgie-network-applet/src')
subdir('budgie-network-applet/data')
#subdir('budgie-network-applet/po')
