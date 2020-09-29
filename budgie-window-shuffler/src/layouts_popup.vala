using Gtk;
using Wnck;
using Gdk.X11;

namespace LayoutsPopup {

    // see what can be de-globalized from below please
    Gtk.Grid popupgrid;
    string searchpath;
    Gtk.Window? layouts;
    FileMonitor layoutschange_monitor;
    File popuptrigger;
    Gdk.X11.Window timestamp_window;
    Wnck.Screen wnck_scr;

    class PopupWindow : Gtk.Window {

        public PopupWindow() {
            this.title = "LayoutsPopup";
            this.set_position(Gtk.WindowPosition.CENTER_ALWAYS);
            popupgrid = new Grid();
            get_layoutgrid();
            this.add(popupgrid);
            this.destroy.connect(() => {;
                delete_trigger();
            });
            this.resize(300, 10);
            this.show_all();
        }

        private void get_layoutgrid() {
            string[] newlayouts = {};
            print(@"spath: $searchpath\n");
            try {
                var dr = Dir.open(searchpath);
                string? dirname = null;
                // walk through relevant files
                while ((dirname = dr.read_name()) != null) {
                    string layoutpath = searchpath.concat("/", dirname);
                    if (FileUtils.test (layoutpath, FileTest.IS_DIR)) {
                        newlayouts += dirname;
                    }
                }
            }
            catch (Error e) {
                error ("%s", e.message);
            }
            foreach (var widget in popupgrid.get_children()) {
                widget.destroy();
            }

            int row_int = 1;


            foreach (string s in newlayouts) {

                // optimize please
                Gtk.Button newlauyoutbutton = new Gtk.Button.with_label(s);
                newlauyoutbutton.set_relief(Gtk.ReliefStyle.NONE);
                Gtk.Button neweditbutton = new Button.from_icon_name(
                    "document-edit-symbolic", Gtk.IconSize.BUTTON
                );
                neweditbutton.set_relief(Gtk.ReliefStyle.NONE);
                Gtk.Button newdeletebutton = new Button.from_icon_name(
                    "user-trash-symbolic", Gtk.IconSize.BUTTON
                );

                newdeletebutton.set_relief(Gtk.ReliefStyle.NONE);
                popupgrid.attach(newlauyoutbutton, 1, row_int, 1, 1);
                popupgrid.attach(neweditbutton, 2, row_int, 1, 1);
                popupgrid.attach(newdeletebutton, 3, row_int, 1, 1);
                newlauyoutbutton.set_size_request(300, 10);
                newlauyoutbutton.clicked.connect(run_layout);
                print(@"$s\n");
                row_int += 1;
            }
            // lazy spacing
            int[,] corners = {{0, 0}, {100, 0}, {0, 100}, {100, 100}};
            for (int i=0; i<4; i++) {
                int first = corners[i, 0];
                int second = corners[i, 1];
                popupgrid.attach(new Label("\t"), corners[i, 0], corners[i, 1], 1, 1);
            }
            popupgrid.attach(new Label(""), 1, 50, 1, 1);
            Gtk.Box addbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            popupgrid.attach(addbox, 1, 51, 4, 1);
            Gtk.Button addbutton = new Gtk.Button();
            addbutton.label = "Add new layout" + "\t+";
            addbutton.set_relief(Gtk.ReliefStyle.NONE);
            addbox.pack_end(addbutton, false, false, 0);
            popupgrid.show_all();
        }
    }

    private void delete_trigger() {
        try {
            popuptrigger.delete();
        }
        catch (Error e) {
            /*
            / file doens't exist, not much use for any action
            */
        }
    }

    private void run_layout(Button button) {
        string buttontext = button.get_label();
        string cmd = "/usr/lib/budgie-window-shuffler/".concat(
            "run_layout '", buttontext, "'"
        );
        run_command(cmd);
        layouts.destroy();
        layouts = null;
    }

    private void run_command (string cmd) {
        // well, seems clear
        try {
            Process.spawn_command_line_async(cmd);
        }
        catch (GLib.SpawnError err) {
            /*
            / not much use for any action
            */
        }
    }

    private string create_dirs_file (string subpath, bool ishome = false) {
        // defines, and if needed, creates directory for layouts
        string homedir = "";
        if (ishome) {
            homedir = Environment.get_home_dir();
        }
        string fullpath = GLib.Path.build_path(
            GLib.Path.DIR_SEPARATOR_S, homedir, subpath
        );
        GLib.File file = GLib.File.new_for_path(fullpath);
        try {
            file.make_directory_with_parents();
        }
        catch (Error e) {
            /* the directory exists, nothing to be done */
        }
        return fullpath;
    }

    public void toggle_popup(File popuptrigger) {
        if (
            popuptrigger.query_exists() &&
            layouts == null
        ) {
            layouts = new PopupWindow();
            layouts.decorated = false;
        }
        else if (
            !popuptrigger.query_exists() &&
            layouts != null
        ) {
            layouts.destroy();
            layouts = null;
        }
    }

    private uint get_now() {
        // get timestamp
        return Gdk.X11.get_server_time(timestamp_window);
    }

    private void makesure_offocus () {
        foreach (Wnck.Window w in wnck_scr.get_windows()) {
            if (w.get_name() == "LayoutsPopup") {
                w.activate(get_now());
            }
        }
    }

    public static void main(string[] args) {
        Gtk.init(ref args);
        searchpath = create_dirs_file(
            ".config/budgie-extras/shuffler/layouts", true
        );
        string username = Environment.get_user_name();
        string triggerpath = create_dirs_file(
            "/tmp/".concat(username, "_shufflertriggers")
        );
        // watch triggerfile
        File triggerdir = File.new_for_path(triggerpath);
        popuptrigger = File.new_for_path(triggerpath.concat("/layoutspopup"));
        FileMonitor triggerpath_monitor = triggerdir.monitor(FileMonitorFlags.NONE, null);
        triggerpath_monitor.changed.connect(() => {
            toggle_popup(popuptrigger);
            Timeout.add(50, ()=> {
                makesure_offocus();
                return false;
            });
        });
        // X11 stuff
        unowned X.Window xwindow = Gdk.X11.get_default_root_xwindow();
        unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
        Gdk.X11.Display display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
        timestamp_window = new Gdk.X11.Window.foreign_for_display(display, xwindow);
        wnck_scr = Wnck.Screen.get_default();
        wnck_scr.active_window_changed.connect(makesure_offocus);
        Gtk.main();
    }
}