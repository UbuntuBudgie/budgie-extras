am_cflags = [
    '-fstack-protector',
    '-pedantic',
    '-Wstrict-prototypes',
    '-Wundef',
    '-Werror-implicit-function-declaration',
    '-Wformat',
    '-Wformat-security',
    '-Werror=format-security',
    '-Wconversion',
    '-Wunused-variable',
    '-Wunreachable-code',
    '-Wall',
    '-W',
]

add_global_arguments(am_cflags, language: 'c')

LOCALE_DIR = join_paths(prefix, get_option('localedir'))
PLUGIN = 'budgie-hotcorners'
VAPI_DIR = join_paths(meson.source_root(),
                      PLUGIN,
                      'vapi')

install_data('schema/org.ubuntubudgie.plugins.budgie-hotcorners.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)


LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

message('Installing applet...')

subdir('src')
subdir('po')
subdir('icons')

meson.add_install_script('meson_post_install')
