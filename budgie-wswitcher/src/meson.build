
custom_target('plugin-file-wswitcher',
    input : 'WallpaperSwitcher.plugin.in',
    output : 'WallpaperSwitcher.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

#install_data('WallpaperSwitcher.plugin', install_dir: LIB_INSTALL_DIR)

WallpaperSwitcherSources = [
'wallpaperswitcher.vala'
]

WallpaperSwitcherDependencies = [
dependency('gtk+-3.0'),
dependency('budgie-1.0'),
dependency('libwnck-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

WallpaperSwitcherValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]

WallpaperSwitcherCArgs = [
'-DWNCK_I_KNOW_THIS_IS_UNSTABLE'
]

shared_library(
    'wallpaperswitcher',
    WallpaperSwitcherSources,
    dependencies: WallpaperSwitcherDependencies,
    vala_args: WallpaperSwitcherValaArgs,
    c_args: WallpaperSwitcherCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: LIB_INSTALL_DIR
)




