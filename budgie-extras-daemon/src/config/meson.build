# libbudgieconfig is just a simple .a archive to fix linking in vala
# builds by restricting defines to one place.

# Create config.h
configurationData = configuration_data()
configurationData.set('DATADIR', join_paths(prefix, get_option('datadir'), daemon_name))
configurationData.set('SYSCONFDIR', join_paths(get_option('sysconfdir'), daemon_name))
configurationData.set('DAEMONNAME', daemon_name)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)


libconfig_sources = [
    'daemon.c',
]

libconfig = static_library(
    'config',
    libconfig_sources
    
)
#include_directories: extra_includes,

link_libconfig = declare_dependency(
    link_with: libconfig,
    include_directories: [
        include_directories('.'),
    ],
)

# Expose the current directory so that we can use vapidir
dir_libconfig = meson.current_source_dir()
