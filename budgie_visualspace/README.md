This is the test version of the dynamic workspaces- and the visualizer script. All files should be in one and the same directory.

# Preparation
- Copy all files into one and the same directory
- Copy `org.ubuntubudgie.visualspace.gschema.xml` to `/usr/share/glib-2.0/schemas/`
- Run `sudo glib-compile-schemas /usr/share/glib-2.0/schemas/`

Edit the shortcuts Control_L + Alt + left/right to run the visualspace with the arguments next or prev (= next/previous). 

`/path/to/visualspace next`

and

`/path/to/visualspace prev`

Alternatively, for testing, you could of course create a few other temporary shortcuts.

# Behaviour
When space_switcher is called with a keypress, immediately released, the navigator shows on the new workspace and immediately terminates itself (within 0.4 sec) (more or less similar to how Unity behaves)

If called, keeping Ctrl + Alt pressed, the navigator terminates on key release Ctrl/Alt event. While keeping pressed left/right, clicking arrows will browse through the workspaces. While doing so, on moving to the left will clean up unused workspaces.

![screenshot-1](https://github.com/UbuntuBudgie/budgie-extras/blob/development/budgie_visualspace/visualspace.png)

