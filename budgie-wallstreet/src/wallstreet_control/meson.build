configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

WallstreetControlSources = [
'wallstreet_control.vala'
]

WallstreetControlDependencies = [
dependency('gtk+-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

WallstreetControlValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

WallstreetControlCArgs = [
'-include',
'config.h',
'-lm'
]

executable(
    'WallstreetControl', WallstreetControlSources,
    dependencies: WallstreetControlDependencies,
    install: true,
    vala_args: WallstreetControlValaArgs,
    c_args: WallstreetControlCArgs,
    install_dir: LIB_INSTALL_DIR,
)
