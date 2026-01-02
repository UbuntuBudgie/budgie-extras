
custom_target('plugin-file-visualspace',
    input : 'VisualSpace.plugin.in',
    output : 'VisualSpace.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)


VisualSpaceSources = [
]

if for_wayland == true
    VisualSpaceSources += ['visualspace_wayland.vala']
else
    VisualSpaceSources += ['visualspace_x11.vala', 'auto_workspace.vala']
endif

VisualSpaceDependencies = [dependency('gtk+-3.0')]

if for_wayland == true
  VisualSpaceDependencies += [
    dependency('budgie-3.0'),
    dependency('gdk-3.0'),
    dependency('libxfce4windowing-0'),
    dependency('libpeas-2')
  ]
else
  VisualSpaceDependencies += [
    dependency('budgie-1.0'),
    dependency('gdk-x11-3.0'),
    dependency('libwnck-3.0'),
    dependency('libpeas-gtk-1.0')
  ]
endif

VisualSpaceArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

VisualSpaceCArgs = [
'-lm'
]

if for_wayland == false
  VisualSpaceCArgs += ['VisualSpaceCArgs']
endif

shared_library(
    'visualspace',
    VisualSpaceSources,
    dependencies: VisualSpaceDependencies,
    vala_args: VisualSpaceArgs,
    c_args: VisualSpaceCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: LIB_INSTALL_DIR
)

if for_wayland == false
    AutoWorkspaceSources = [
    'auto_workspace.vala'
    ]
    
    AutoWorkspaceDependencies = [
    dependency('gtk+-3.0'),
    dependency('libwnck-3.0'),
    ]
    
    AutoWorkspaceValaArgs = [
    '--target-glib=2.38',
    ]
    
    AutoWorkspaceCArgs = [
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    ]
    
    executable(
        'auto_workspace', AutoWorkspaceSources,
        dependencies: AutoWorkspaceDependencies,
        install: true,
        vala_args: AutoWorkspaceValaArgs,
        c_args: AutoWorkspaceCArgs,
        include_directories: config_inc_dir,
        install_dir: LIB_INSTALL_DIR,
    )
endif