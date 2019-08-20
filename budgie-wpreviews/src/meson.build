
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
'--target-glib=2.38'
]


BudgiePreviewCArgs = [
'-DWNCK_I_KNOW_THIS_IS_UNSTABLE'
]

LIB_INSTALL_DIR = join_paths(prefix, libdir, application_id)

executable(
    'previews_creator', BudgiePreviewCreatorSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    install_dir: LIB_INSTALL_DIR,
)

executable(
    'previews_controls', BudgiePreviewControlSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    install_dir: LIB_INSTALL_DIR,
)

executable(
    'previews_daemon', BudgiePreviewDaemonSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    install_dir: LIB_INSTALL_DIR,
)

executable(
    'previews_triggers', BudgiePreviewTriggerSources,
    dependencies: BudgiePreviewDependencies,
    install: true,
    vala_args: BudgiePreviewValaArgs,
    c_args: BudgiePreviewCArgs,
    install_dir: LIB_INSTALL_DIR,
)

install_data('pics/grey_x.png',
    'pics/prv_grey.png',
    'pics/prv_white.png',
    'pics/white2_x.png',
    'pics/white_x.png',
    install_dir: join_paths(libdir, application_id, 'pics')
)
