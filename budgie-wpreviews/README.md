# Setup

- compile `previews_triggers.vala `
- compile `window_daemon.vala`
- compile `previews_creator.vala`
- copy folder `pics` to the same location as the executable `alttab_runner.vala`
- install the gschema

- Run both `window_daemon` and `previews_creator`
- Set previews to show windows from all workspaces or only current in the key `/org/ubuntubudgie/plugins/budgie-wpreviews/allworkspaces`


Create shortcuts
- all applications / browse forward: Alt + Tab -> `preview_triggers`
- all applications / browse backward: Alt + Shift + Tab -> `preview_triggers previous`
- current application / browse forward: Alt + above-Tab -> `preview_triggers current`
- all applications / browse backward: Alt + Shift + above-Tab -> `preview_triggers current previous`

*Alt_L is needed as modifier, to trigger closing previews

# Run from hotcorners
- `preview_triggers`

or 

- `preview_triggers current`

- Press Escape to close

- run the daemon `alttab_runner`

# Still to fix
- Let's find out

# Still to do.
- 

# Possible tweaks/improvements
- n-columns is currently taken from primary monitor, make it more sophisticated?
