sassc = find_program('sassc', required: true)

style = custom_target('Style generation',
    input: ['main.scss'],
    output:'style.css',
    command: [
        sassc,
        [ '-a', '-M', '-t', 'compact' ],
        '@INPUT@', '@OUTPUT@',
    ],
    depend_files: files([
        '_file-box.scss',
        '_info-revealer.scss',
        '_item.scss',
        '_list.scss',
        '_settings.scss',
        '_store.scss',
        '_vars.scss',
    ]),
    build_by_default: true,
)
