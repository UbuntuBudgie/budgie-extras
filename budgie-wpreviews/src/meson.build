BudgiePreviewSeparateShotSources = [
'separate_shot.vala'
]

BudgiePreviewCreatorSources = [
'previews_creator.vala'
]

BudgiePreviewDaemonSources = [
'previews_daemon.vala'
]

BudgiePreviewTriggerSources = [
'previews_triggers.vala'
]

BudgiePreviewControlSources = [
'previews_controls.vala'
]

BudgiePreviewDependencies = [
dependency('gtk+-3.0'),
dependency('gio-2.0'),
dependency('gdk-3.0'),
dependency('libwnck-3.0'),
dependency('gdk-x11-3.0')
]

BudgiePreviewValaArgs = [
'--target-glib=2.38',
'--pkg=config',
'--vapidir=' + VAPI_DIR
]

BudgiePreviewCArgs = [
'-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
]

LIB_INSTALL_DIR = join_paths(prefix, libdir, application_id)

executable(
    'separate_shot', BudgiePreviewSeparateShotSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

executable(
    'previews_creator', BudgiePreviewCreatorSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

executable(
    'previews_controls', BudgiePreviewControlSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

executable(
    'previews_daemon', BudgiePreviewDaemonSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

executable(
    'previews_triggers', BudgiePreviewTriggerSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

install_data('pics/budgie_wpreviews_grey_x.png',
    'pics/budgie_wpreviews_prv_grey.png',
    'pics/budgie_wpreviews_prv_white.png',
    'pics/budgie_wpreviews_white2_x.png',
    'pics/budgie_wpreviews_white_x.png',
    install_dir: PIXMAPS_DIR
)
