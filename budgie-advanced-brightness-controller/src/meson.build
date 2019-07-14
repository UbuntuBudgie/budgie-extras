configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', 'budgie-extras')
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

install_data('advancedbrightnesscontroller.plugin', install_dir: LIB_INSTALL_DIR)

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

if DEPENDENCY_GNOME_SETTINGS_DAEMON.version().version_compare('>=3.32.0')
    BudgieWmStatusValaArgs += ['-D', 'HAVE_GNOME_SETTINGS_DAEMON_3_32_0']
endif

if DEPENDENCY_GNOME_SETTINGS_DAEMON.version().version_compare('<3.32.0')
    BudgieWmStatusValaArgs += ['-D', 'HAVE_GNOME_SETTINGS_DAEMON_OLDER_THAN_3_32_0']
endif

if DEPENDENCY_XRANDR.version().version_compare('>=1.5.0')
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
'-include', 
'config.h'
]

shared_library('advancedbrightnesscontroller', 
AppletSources, 
dependencies: AppletDependencies, 
vala_args: AppletValaArgs, 
c_args: AppletCArgs, 
install: true, 
install_dir: LIB_INSTALL_DIR)