namespace AutoWorkspace {

    Wnck.Screen wnckscr;
    GLib.Settings mutter_ws_settings;

    public static void main (string[] args) {
        Gtk.init(ref args);
        wnckscr = Wnck.Screen.get_default();
        wnckscr.force_update();
        mutter_ws_settings =  new GLib.Settings(
            "org.gnome.desktop.wm.preferences"
        );
        manage_nspace();
        wnckscr.window_closed.connect(manage_nspace);
        wnckscr.window_opened.connect(manage_nspace);
        Gtk.main();
    }

    private void manage_nspace () {
        int lastspace = -1;
        unowned GLib.List<Wnck.Window> wnckstack = wnckscr.get_windows ();
        unowned GLib.List<Wnck.Workspace> wnckspaces = wnckscr.get_workspaces ();
        foreach (Wnck.Window w in wnckstack) {
            bool normalwindow = w.get_window_type () == Wnck.WindowType.NORMAL;
            if (normalwindow) {
                int i = 0;
                Wnck.Workspace space = w.get_workspace ();
                foreach (Wnck.Workspace sp in wnckspaces) {
                    if (sp == space && i > lastspace) {
                        lastspace = i;

                    }
                    i += 1;
                }
            }
        }
        int n_currentworkspaces = mutter_ws_settings.get_int("num-workspaces");
        if (lastspace + 2 != n_currentworkspaces) {
            mutter_ws_settings.set_int("num-workspaces", lastspace + 2);
        }
        print(@"$lastspace\n");
    }
}