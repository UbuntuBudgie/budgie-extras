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

PLUGIN = 'budgie-hotcorners'

# substprog = find_program('subst.py')

# n.b. libdir comes from the top level meson.build

#mytarget = custom_target('hotcorners_schema',
#  output : 'org.ubuntubudgie.plugins.budgie-hotcorners.gschema.xml',
#  input : 'schema/org.ubuntubudgie.plugins.budgie-hotcorners.gschema.xml.in',
#  command : [substprog, '@INPUT@', libdir, '@OUTPUT@'],
#  install : true,
#  install_dir : '/usr/share/glib-2.0/schemas'
#)

LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', PLUGIN)

message('Installing applet...')

subdir('src')
subdir('icons')

meson.add_install_script('meson_post_install.py')
