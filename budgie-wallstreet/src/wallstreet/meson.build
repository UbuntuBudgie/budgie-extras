
WallstreetSources = [
'wallstreet.vala'
]

WallstreetDependencies = [
dependency('gtk+-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

WallstreetValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

WallstreetCArgs = [
'-lm'
]

executable(
    'wallstreet', WallstreetSources,
    dependencies: WallstreetDependencies,
    install: true,
    vala_args: WallstreetValaArgs,
    install_dir: LIB_INSTALL_DIR,
)
