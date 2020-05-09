
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
'-lm'
]

executable(
    'wallstreet_control', WallstreetControlSources,
    dependencies: WallstreetControlDependencies,
    install: true,
    vala_args: WallstreetControlValaArgs,
    c_args: WallstreetControlCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)
