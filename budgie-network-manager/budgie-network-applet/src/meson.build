project_name = meson.project_name()
project_version = meson.project_version()

prefix = get_option('prefix')
bindir = get_option('bindir')
datadir = get_option('datadir')
localedir = get_option('localedir')

conf_data = configuration_data()
conf_data.set_quoted('PACKAGE_NAME', project_name)
conf_data.set_quoted('PACKAGE_VERSION', project_version)
conf_data.set_quoted('GETTEXT_PACKAGE', project_name)
conf_data.set_quoted('DATA_DIR', join_paths(prefix, datadir))
conf_data.set_quoted('LOCALE_DIR', join_paths(prefix, localedir))

config_header = configure_file(
    input: 'config.vala.in',
    output: 'config.vala',
    configuration: conf_data
)

network_applet_sources = [
            'Applet.vala',
            'Utils.vala',
            'common/rfkill.vala',
            'common/Widgets/AbstractEtherInterface.vala',
            'common/Widgets/AbstractModemInterface.vala',
            'common/Widgets/AbstractVpnInterface.vala',
            'common/Widgets/AbstractWifiInterface.vala',
            'common/Widgets/AbstractBluetoothInterface.vala',
            'common/Widgets/NMVisualizer.vala',
            'common/Widgets/VpnMenuItem.vala',
            'common/Widgets/WidgetNMInterface.vala',
            'common/Widgets/WifiMenuItem.vala',
            'Widgets/DisplayWidget.vala',
            'Widgets/EtherInterface.vala',
            'Widgets/ModemInterface.vala',
            'Widgets/VpnInterface.vala',
            'Widgets/WifiInterface.vala',
            'Widgets/BluetoothInterface.vala',
            'Widgets/PopoverWidget.vala',
            'Widgets/Separator.vala',
            'Widgets/Switch.vala',
            'Widgets/OverlayIcon.vala'
            ]

network_applet_deps = [
            dependency('gtk+-3.0', version: '>=3.18'),
            budgie_dep,
            dependency('libnm'),
            dependency('libnma'),
            meson.get_compiler('vala').find_library('posix'),
            dependency('gee-0.8'),
            dependency('gobject-2.0'),
            ]

network_applet_vala_args = ['--target-glib=2.50', config_header, '--vapidir=' + VAPI_DIR]

shared_library('networkapplet', network_applet_sources,
               dependencies: network_applet_deps,
               vala_args: network_applet_vala_args,
               install: true,
               install_dir: lib_install_dir)