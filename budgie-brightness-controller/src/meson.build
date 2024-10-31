
custom_target('plugin-brightness',
    input : 'brightnesscontroller.plugin.in',
    output : 'brightnesscontroller.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

AppletSources = [
'Applet.vala',
'widgets/IndicatorButton.vala',
'widgets/CustomMenuButton.vala',
'widgets/Popover.vala',
'widgets/CustomScale.vala',
'helpers/DimHelper.vala',
'helpers/LightHelper.vala',
'helpers/SubprocessHelper.vala',
'helpers/ConfigHelper.vala',
'models/Flame.vala',
'models/Dim.vala',
'models/Light.vala'
]

AppletDependencies = [
DEPENDENCY_GTK,
DEPENDENCY_BUDGIE
]

BudgieWmStatusValaArgs = []

if DEPENDENCY_GNOME_SETTINGS_DAEMON.version().version_compare('>=3.36.0')
    BudgieWmStatusValaArgs += ['-D', 'HAVE_GNOME_SETTINGS_DAEMON_3_36_0']
endif

if DEPENDENCY_GNOME_SETTINGS_DAEMON.version().version_compare('>=3.32.0')
    BudgieWmStatusValaArgs += ['-D', 'HAVE_GNOME_SETTINGS_DAEMON_3_32_0']
endif

if DEPENDENCY_GNOME_SETTINGS_DAEMON.version().version_compare('<3.32.0')
    BudgieWmStatusValaArgs += ['-D', 'HAVE_GNOME_SETTINGS_DAEMON_OLDER_THAN_3_32_0']
endif

if for_wayland == false and DEPENDENCY_XRANDR.version().version_compare('>=1.5.0')
    BudgieWmStatusValaArgs += ['-D', 'HAVE_XRANDR_1_5_0']
endif

AppletValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
'--enable-deprecated',
BudgieWmStatusValaArgs
]

AppletCArgs = [
]

shared_library('brightnesscontroller',
AppletSources,
dependencies: AppletDependencies,
vala_args: AppletValaArgs,
c_args: AppletCArgs,
include_directories: config_inc_dir,
install: true,
install_dir: LIB_INSTALL_DIR)
