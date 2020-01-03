ShufflerValaArgs = [
    '--target-glib=2.38',
]

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
    'tileactive', TileActiveSources,
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
    'shufflerdaemon', ShufflerDaemonSources,
    dependencies: ShufflerDaemonDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: ShufflerDaemonCArgs,
    install_dir: LIB_INSTALL_DIR,
)
