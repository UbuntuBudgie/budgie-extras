i18n = import('i18n')

# for i in *.po; do echo "    '$i'," | sed 's/\.po//'; done
langs = [
    'ca',
    'da',
    'de_DE',
    'en_GB',
    'es',
    'fr',
    'hu',
    'it',
    'ms_MY',
    'nl_NL',
    'oc',
    'pl',
    'pt_BR',
    'pt_PT',
    'sr_RS',
    'tr',
]

# Stole this from gnome-twitch, ty TingPing
# https://github.com/vinszent/gnome-twitch/tree/master/po
i18n.gettext(meson.project_name(), languages : langs, args : [
    '--from-code=UTF-8',
    '--add-comments',
    '--package-name=' + meson.project_name(),
    '--package-version=' + meson.project_version(),
    '--keyword=_',
    '--keyword=N_',
    '--keyword=C_:1c,2',
    '--keyword=NC_:1c,2',
    '--keyword=g_dcgettext:2',
    '--keyword=g_dngettext:2,3',
    '--keyword=g_dpgettext2:2c,3',

    '--flag=N_:1:pass-c-format',
    '--flag=C_:2:pass-c-format',
    '--flag=NC_:2:pass-c-format',
    '--flag=g_dngettext:2:pass-c-format',
    '--flag=g_strdup_printf:1:c-format',
    '--flag=g_string_printf:2:c-format',
    '--flag=g_string_append_printf:2:c-format',
    '--flag=g_error_new:3:c-format',
    '--flag=g_set_error:4:c-format',
])
