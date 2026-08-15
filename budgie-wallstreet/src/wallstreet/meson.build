
WallstreetSources = [
'wallstreet.vala'
]

wallstreet_soup_vala_args = []
dep_soup = dependency('libsoup-2.4', required: false)
if dep_soup.found()
    wallstreet_soup_vala_args += ['-D', 'HAVE_SOUP_2_4']
else
    dep_soup = dependency('libsoup-3.0')
        if dep_soup.found()
            wallstreet_soup_vala_args += ['-D', 'HAVE_SOUP_3']
        endif
endif

WallstreetDependencies = [
dependency('gtk+-3.0'),
dep_soup,
dependency('json-glib-1.0'),
meson.get_compiler('c').find_library('m', required: false)
]

WallstreetValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
wallstreet_soup_vala_args
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
