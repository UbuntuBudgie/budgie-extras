configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configurationData.set('LIB_DIR', LIB_INSTALL_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

ShufflerValaArgs = [
    '--pkg=config',
    '--vapidir=' + VAPI_DIR,
    '--target-glib=2.38',
]

ResizeSources = [
    'resize.vala'
]

ResizeDependencies = [
    dependency('gio-2.0'),
    meson.get_compiler('c').find_library('m', required: false)
]

ResizeCArgs = [
    '-lm'
]

executable(
    'resize', ResizeSources,
    dependencies: ResizeDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: ResizeCArgs,
    install_dir: LIB_INSTALL_DIR,
)

SoftMoveSources = [
    'softmove.vala'
]

SoftMoveDependencies = [
    dependency('gio-2.0'),
    meson.get_compiler('c').find_library('m', required: false)
]

SoftMoveCArgs = [
    '-lm'
]

executable(
    'softmove', SoftMoveSources,
    dependencies: SoftMoveDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: SoftMoveCArgs,
    install_dir: LIB_INSTALL_DIR,
)

GridAllSources = [
    'grid_all.vala'
]

GridAllDependencies = [
    dependency('gtk+-3.0'),
    dependency('gio-2.0'),
    dependency('gdk-x11-3.0'),
    meson.get_compiler('c').find_library('m', required: false)
]

GridAllCArgs = [
    '-lm',
]

executable(
    'grid_all', GridAllSources,
    dependencies: GridAllDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: GridAllCArgs,
    install_dir: LIB_INSTALL_DIR,
)

GridWindowSources = [
    'gridwindow.vala'
]

GridWindowDependencies = [
    dependency('gtk+-3.0'),
    dependency('gio-2.0'),
    dependency('gdk-x11-3.0'),
    dependency('gdk-3.0'),
    dependency('cairo'),
    dependency('libwnck-3.0'),
]

GridWindowCArgs = [
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
]

executable(
    'gridwindow', GridWindowSources,
    dependencies: GridWindowDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: GridWindowCArgs,
    install_dir: LIB_INSTALL_DIR,
)

JumpSources = [
    'jump.vala'
]

JumpDependencies = [
    dependency('gtk+-3.0'),
    dependency('gio-2.0'),
]

executable(
    'jump', JumpSources,
    dependencies: JumpDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    install_dir: LIB_INSTALL_DIR,
)

TileActiveSources = [
    'tile_active.vala'
]

TileActiveDependencies = [
    dependency('gtk+-3.0'),
    dependency('gio-2.0'),
]

executable(
    'tile_active', TileActiveSources,
    dependencies: TileActiveDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    install_dir: LIB_INSTALL_DIR,
)

ToggleGUISources = [
    'togglegui.vala'
]

ToggleGUIDependencies = [
    dependency('gio-2.0'),
]

executable(
    'togglegui', ToggleGUISources,
    dependencies: ToggleGUIDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    install_dir: LIB_INSTALL_DIR,
)

ShufflerDaemonSources = [
    'windowshufflerdaemon.vala'
]

ShufflerDaemonDependencies = [
    dependency('gtk+-3.0'),
    dependency('gio-2.0'),
    dependency('gdk-x11-3.0'),
    dependency('libwnck-3.0'),
    meson.get_compiler('c').find_library('m', required: false),
]

ShufflerDaemonCArgs = [
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    '-lm'
]

executable(
    'windowshufflerdaemon', ShufflerDaemonSources,
    dependencies: ShufflerDaemonDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: ShufflerDaemonCArgs,
    install_dir: LIB_INSTALL_DIR,
)

ShufflerControlSources = [
    'shuffler_control.vala'
]

ShufflerControlDependencies = [
    dependency('gtk+-3.0'),
]

executable(
    'shuffler_control', ShufflerControlSources,
    dependencies: ShufflerControlDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    install_dir: LIB_INSTALL_DIR,
)
