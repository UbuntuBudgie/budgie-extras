substprog = find_program('subst.py')

mytarget = custom_target('hotcorners_schema',
  output : 'org.ubuntubudgie.budgie-extras.HotCorners.gschema.xml',
  input : 'schema/org.ubuntubudgie.budgie-extras.HotCorners.gschema.xml.in',
  command : [substprog, '@INPUT@', libdir, '@OUTPUT@'],
  install : true,
  install_dir : '/usr/share/glib-2.0/schemas'
)

subdir('applet')

meson.add_install_script('meson_post_install.py')
