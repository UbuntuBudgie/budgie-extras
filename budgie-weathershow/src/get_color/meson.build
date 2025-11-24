GetColorSources = [
'get_color.vala'
]

GetColorDependencies = [
dependency('gtk+-3.0'),
dependency('gee-0.8'),
meson.get_compiler('c').find_library('m', required: false)
]

GetColorValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

GetColorCArgs = [
'-lm'
]

executable(
    'get_color', GetColorSources,
    dependencies: GetColorDependencies,
    install: true,
    vala_args: GetColorValaArgs,
    c_args: GetColorCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)
