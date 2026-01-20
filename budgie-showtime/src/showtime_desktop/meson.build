
# Update dependencies
showtime_deps = [
    dependency('gtk+-3.0', version: '>= 3.22'),
    dependency('glib-2.0', version: '>= 2.50'),
    dependency('cairo'),
    dependency('pango'),
    meson.get_compiler('c').find_library('m', required: false)
]

budgie_display_vala_args = []
# Conditional dependencies
if for_wayland == true
    DESKTOP_INSTALL_DIR = RAVEN_INSTALL_DIR
    showtime_deps += [
        dependency('gtk-layer-shell-0', version: '>= 0.6.0'),
        dependency('libxfce4windowing-0', version: '>= 4.19.1'),
    ]
    budgie_display_vala_args += ['-D', 'FOR_WAYLAND']
    BudgieShowTimeCArgs = [
    '-lm',
    ]
else
    DESKTOP_INSTALL_DIR = LIB_INSTALL_DIR
    showtime_deps += [
        dependency('libwnck-3.0', version: '>= 3.20'),
    ]
    BudgieShowTimeCArgs = [
    '-lm',
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE'
    ]

endif

DesktopShowtimeValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
budgie_display_vala_args,
]


# Build target
showtime_desktop_sources = files(
    'showtime_desktop.vala',
)

executable(
    'showtime-desktop',
    showtime_desktop_sources,
    dependencies: showtime_deps,
    vala_args: DesktopShowtimeValaArgs,
    install: true,
    c_args: BudgieShowTimeCArgs,
    include_directories: config_inc_dir,
    install_dir: DESKTOP_INSTALL_DIR,
)
