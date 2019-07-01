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

PLUGIN = 'budgie-fuzzyclock'

LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

message('Installing applet...')

subdir('fuzzyclock')

meson.add_install_script('meson_post_install')
