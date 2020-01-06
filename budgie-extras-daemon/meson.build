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

DAEMON = 'budgie-extras-daemon'

LIB_INSTALL_DIR = join_paths(prefix, libdir, DAEMON)

message('Installing daemon...')

subdir('src')
subdir('data')