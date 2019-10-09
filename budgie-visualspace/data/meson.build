BDE_LOC=join_paths(datadir, 'budgie-extras-daemon')
substprog = find_program('subst.py')

mytarget1 = custom_target('vs-left',
  output : 'vs-left.bde',
  input : 'vs-left.bde.in',
  command : [substprog, '@INPUT@', pkgdatadir, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)

mytarget2 = custom_target('vs-right',
  output : 'vs-right.bde',
  input : 'vs-right.bde.in',
  command : [substprog, '@INPUT@', pkgdatadir, '@OUTPUT@'],
  install : true,
  install_dir : BDE_LOC
)
