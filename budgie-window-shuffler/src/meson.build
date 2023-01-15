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
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

RunRuleSources = [
    'run_rule.vala'
]

RunRuleDependencies = [
    dependency('gio-2.0'),
]

executable(
    'run_rule', RunRuleSources,
    dependencies: RunRuleDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    include_directories: config_inc_dir,
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
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

GridAllSources = [
    'grid_all.vala'
]

GridAllDependencies = [
    dependency('gtk+-3.0'),
    dependency('gio-2.0'),
    dependency('gdk-x11-3.0'),
    dependency('cairo'),
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
    include_directories: config_inc_dir,
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
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

LayoutsPopupSources = [
    'layouts_popup.vala'
]

LayoutsPopupDependencies = [
    dependency('gtk+-3.0'),
    dependency('gio-2.0'),
    dependency('gdk-x11-3.0'),
    dependency('gdk-3.0'),
    dependency('libwnck-3.0'),
]

LayoutsPopupCArgs = [
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
]

executable(
    'layouts_popup', LayoutsPopupSources,
    dependencies: LayoutsPopupDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: LayoutsPopupCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

ToggleLayoutsPopupSources = [
    'toggle_layouts_popup.vala'
]

ToggleLayoutsPopupDependencies = [
    dependency('gio-2.0'),
]

ToggleLayoutsPopupCArgs = [
]

executable(
    'toggle_layouts_popup', ToggleLayoutsPopupSources,
    dependencies: ToggleLayoutsPopupDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: ToggleLayoutsPopupCArgs,
    include_directories: config_inc_dir,
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
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

RunLayoutSources = [
    'run_layout.vala'
]

RunLayoutDependencies = [
    dependency('gtk+-3.0'),
    dependency('libwnck-3.0'),
]

RunLayoutCArgs = [
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    '-lm'
]

executable(
    'run_layout', RunLayoutSources,
    dependencies: RunLayoutDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: RunLayoutCArgs,
    include_directories: config_inc_dir,
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
    include_directories: config_inc_dir,
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
    include_directories: config_inc_dir,
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
    dependency('atspi-2'),
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
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

SizeExceedsWarningSources = [
    'sizeexceeds_warning.vala'
]

SizeExceedsWarningDependencies = [
    dependency('gtk+-3.0'),
    dependency('cairo')
]

executable(
    'sizeexceeds_warning', SizeExceedsWarningSources,
    dependencies: SizeExceedsWarningDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

ShufflerControlSources = [
    'shuffler_control.vala'
]

ShufflerControlDependencies = [
    dependency('gtk+-3.0'),
    dependency('libwnck-3.0'),
    dependency('gdk-3.0'),
    dependency('gio-2.0'),
    dependency('gdk-x11-3.0')
]

ShufflerControlCArgs = [
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    '-lm'
]

executable(
    'shuffler_control', ShufflerControlSources,
    dependencies: ShufflerControlDependencies,
    install: true,
    c_args: ShufflerControlCArgs,
    vala_args: ShufflerValaArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

DragSnapSources = [
    'dragsnap.vala'
]

DragSnapDependencies = [
    dependency('gtk+-3.0'),
    dependency('gdk-3.0'),
    dependency('cairo'),
    dependency('libwnck-3.0'),
]

DragSnapCArgs = [
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
]

executable(
    'dragsnap', DragSnapSources,
    dependencies: DragSnapDependencies,
    install: true,
    vala_args: ShufflerValaArgs,
    c_args: DragSnapCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)
