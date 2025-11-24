HotcornersValaArgs = [
    '--pkg=config',
    '--vapidir=' + VAPI_DIR,
    '--target-glib=2.38',
]

# Global path variable
prefix = get_option('prefix')
libexec_hotcorners = join_paths(libexecdir, 'budgie-hotcorners')


HotcornersSources = [
    'budgie-hotcorners.vala'
]

HotcornersCArgs = [
    '-lm'
]

HotcornersDependencies = [
    dependency('gtk+-3.0'),
    meson.get_compiler('c').find_library('m', required: false)
]

executable(
    'budgie-hotcorners', HotcornersSources,
    dependencies: HotcornersDependencies,
    install: true,
    vala_args: HotcornersValaArgs,
    c_args: HotcornersCArgs,
    install_dir: libexec_hotcorners,
)

HotcornersSettingsSources = [
    'budgie-hotcorners-settingswindow.vala'
]

HotcornersSettingsCArgs = [
]

HotcornersSettingsDependencies = [
    dependency('gtk+-3.0'),
    dependency('json-glib-1.0'),
    meson.get_compiler('c').find_library('m', required: false)
]

executable(
    'budgie-hotcorners-settingswindow', HotcornersSettingsSources,
    dependencies: HotcornersSettingsDependencies,
    install: true,
    vala_args: HotcornersValaArgs,
    c_args: HotcornersSettingsCArgs,
    include_directories: config_inc_dir,
    install_dir: libexec_hotcorners,
)
