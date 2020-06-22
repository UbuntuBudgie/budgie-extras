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

PLUGIN='budgie-wswitcher'
LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

message('Installing applet...')

subdir('src')
subdir('data')

install_data('schema/org.ubuntubudgie.plugins.budgie-wswitcher.gschema.xml',
    install_dir: '/usr/share/glib-2.0/schemas'
)
meson.add_install_script('meson_post_install.py')
