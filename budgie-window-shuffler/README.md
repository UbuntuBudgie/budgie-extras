## Comment on latest development

note: GNOME 40 and later utilises the Shuffler super alt left/right keys. For Ubuntu Budgie we use a gsetting override to revert to wm keybindings prior to GNOME 40

----

Added WIndowRules; functionality to open specific WMCLASS windows to specific monitor & position. To use it, create a .windowrule file, named after the WMCLASS, in ~/.config/budgie-extras/shuffler. Possible fields are:

 - XPosition=int
 - XPosition=int
 - Cols=int
 - Rows=int
 - XSpan=int
 - YSpan=int
 - Monitor=string


The first four are obligatory and refer to to position on grid. Furthermore, we need to set dconf key `/org/ubuntubudgie/windowshuffler/windowrules` -> true.
