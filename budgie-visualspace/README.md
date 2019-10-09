This implements dynamic workspaces- and the visualizer script


This requires budgie-extras-daemon as a runtime dependency


# Behaviour
When space_switcher is called with a keypress, immediately released, the navigator shows on the new workspace and immediately terminates itself (within 0.4 sec) (more or less similar to how Unity behaves)

If called, keeping Ctrl + Alt pressed, the navigator terminates on key release Ctrl/Alt event. While keeping pressed left/right, clicking arrows will browse through the workspaces. While doing so, on moving to the left will clean up unused workspaces.

![screenshot-1](https://github.com/UbuntuBudgie/budgie-extras/blob/development/budgie_visualspace/visualspace.png)

