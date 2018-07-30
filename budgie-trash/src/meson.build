configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

install_data('Trash.plugin', install_dir: LIB_INSTALL_DIR)

trashSources = [ 
'TrashApplet.vala', 
'widgets/TrashPopover.vala',
'widgets/MenuRow.vala',
'widgets/MessageRevealer.vala',
'helpers/TrashHelper.vala',
'models/CustomFile.vala'
]

trashDependencies = [
dependency('gtk+-3.0', version: '>=3.18'), 
dependency('budgie-1.0', version: '>=2')
]

trashValaArgs = [
'--pkg=config', 
'--vapidir=' + VAPI_DIR, 
'--target-glib=2.38', 
'--enable-deprecated'
]

trashCArgs = [
'-include', 
'config.h'
]

shared_library('trash', trashSources, dependencies: trashDependencies, vala_args: trashValaArgs, c_args: trashCArgs, install: true, install_dir: LIB_INSTALL_DIR)
