using Wnck;
using Gtk;


/*
* ShufflerII
* Author: Jacob Vlijm
* Copyright © 2017-2020 Ubuntu Budgie Developers
* Website=https://ubuntubudgie.org
* This program is free software: you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the Free
* Software Foundation, either version 3 of the License, or any later version.
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
* more details. You should have received a copy of the GNU General Public
* License along with this program.  If not, see
* <https://www.gnu.org/licenses/>.
*/

/*
/ use this executable with a folder (named after an appropriate layoutname)
/ as argument. populate the folder with files with the extension
/ .windowlayout. the folder needs to be located in
/ ~/.config/budgie-extras/shuffler/layouts. Inside the folder, dump multiple
/ files containing the following fields:
/ Exec=
/ WMCLASS=
/ XPosition=0
/ YPosition=0
/ Cols=
/ Rows=
/ XSpan=
/ YSpan=
/ Monitor=
/ WName=
/ the last two are optional; WName is to define specifically named files, to
/ be launched to specific positions in case multiple windows of one and the
/ same application are opened.
*/


// valac --pkg gio-2.0 --pkg gtk+-3.0 --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE"


namespace RunLayout {

    LayoutElement[] layoutdata;
    int[] currwindows;
    Wnck.Screen wnck_scr;
    int remaining_jobs;

    struct LayoutElement {
        string command;
        string x_ongrid;
        string y_ongrid;
        string cols;
        string rows;
        string xspan;
        string yspan;
        string wmclass;
        string wname;
        string monitor;
    }

    private bool startswith (string str, string substr ) {
        // check if string startswith
        int str_len = str.length;
        int field_len = substr.length;
        if (field_len  <= str_len) {
            if (str[0:field_len] == substr) {
                return true;
            }
        }
        return false;
    }

    private LayoutElement[] find_data (string[] pathlist) {
        // fetch data from the set of files inside layoutfolder
        string[] fields = {
            "Exec", "XPosition", "YPosition", "Cols", "Rows",
            "XSpan", "YSpan", "WMCLASS", "WName", "Monitor"
        };

        LayoutElement[] tasklist = {};
        foreach (string p in pathlist) {
            var newrecord = LayoutElement();
            // let's set some defaults
            newrecord.command = "";
            newrecord.x_ongrid = "0";
            newrecord.y_ongrid = "0";
            newrecord.cols = "2";
            newrecord.rows = "2";
            newrecord.xspan = "1";
            newrecord.yspan = "1";
            newrecord.wmclass = "";
            newrecord.wname = "";
            newrecord.monitor = "";
            try {
                var file = File.new_for_path (p);
                var dis = new DataInputStream (file.read ());
                string line;
                // walk through lines, fetch arguments
                while ((line = dis.read_line (null)) != null) {
                    int fieldindex = 0;
                    foreach (string field in fields) {
                        if (startswith (line, field)) {
                            string new_value = line.split("=")[1];
                            switch (fieldindex) {
                                case 0:
                                newrecord.command = new_value;
                                break;
                                case 1:
                                newrecord.x_ongrid = new_value;
                                break;
                                case 2:
                                newrecord.y_ongrid = new_value;
                                break;
                                case 3:
                                newrecord.cols = new_value;
                                break;
                                case 4:
                                newrecord.rows = new_value;
                                break;
                                case 5:
                                newrecord.xspan = new_value;
                                break;
                                case 6:
                                newrecord.yspan = new_value;
                                break;
                                case 7:
                                newrecord.wmclass = new_value;
                                break;
                                case 8:
                                newrecord.wname = new_value;
                                break;
                                case 9:
                                newrecord.monitor = new_value;
                                break;
                            }
                        }
                        fieldindex += 1;
                    }
                }
                // now if content seems valid, add to database
                if (
                    newrecord.command != "" &&
                    newrecord.wmclass  != ""
                ) {
                    tasklist += newrecord;
                }
            }
            catch (Error e) {
                error ("%s", e.message);
            }
        }
        return tasklist;
    }

    private int get_intinlist (int intval, int[] arr) {
        // check if in in array
        for (int i=0; i<arr.length; i++) {
            if (intval == arr[i]) {
                return i;
            }
        }
        return -1;
    }

    private void run_command (string cmd) {
        // well, seems clear
        try {
            Process.spawn_command_line_async(cmd);
        }
        catch (GLib.SpawnError err) {
            /*
            * in case an error occurs, the command most likely is
            * incorrect not much use for any action
            */
        }
    }

    private string create_dirs_file (string subpath) {
        // defines, and if needed, creates directory for layouts
        string homedir = Environment.get_home_dir();
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

    private string fix_wmclassname (Wnck.Window new_window) {
        /*
        / since libreoffice fools us by changing the wm_class after
        / creation of the window, make sure we have the final wm_class
        */
        int tries = 0;
        // we wouldn't wait forever
        while (tries < 10) {
            Thread.usleep(100000);
            string classname = new_window.get_class_group_name().down();
            if (classname != "soffice") {
                return classname;
            }
            tries += 1;
        }
        return "invalid";
    }

    private void act_onnewwindow (Wnck.Window new_window) {
        /*
        / on new window creation, look it up, move according to set
        / corresponding arguments.
        */
        // 1. check if window is new
        int xid = (int)new_window.get_xid();
        string name = new_window.get_name();
        string wm_class = new_window.get_class_group_name().down();
        // fix for loffice changing classname
        if (wm_class == "soffice") {
            wm_class = fix_wmclassname(new_window);
        }
        if (get_intinlist(xid, currwindows) == -1) {
            foreach (LayoutElement task in layoutdata) {
                // 2. check if wmclass and (possibly set) name matches
                bool winname_matches = true;
                bool wmclass_matches = task.wmclass == wm_class;
                string foundname = task.wname;
                if (foundname != "" && !name.contains(foundname)) {
                    winname_matches = false;
                }
                if (winname_matches && wmclass_matches) {
                    // 3. if match, move window, remaining -= 1.
                    string addmonitor = task.monitor;
                    if (addmonitor != "") {
                        addmonitor = @"monitor=$addmonitor";
                    }
                    // we're not using animation for now
                    // let's keep below abs path for quick compiling on maintanance tasks
                    //  string cmd = "/usr/lib/budgie-window-shuffler" + "/tile_active ".concat(
                    string cmd = Config.SHUFFLER_DIR + "/tile_active ".concat(
                        task.x_ongrid, " ", task.y_ongrid, " ", task.cols, " ", task.rows,
                        " ", task.xspan, " ", task.yspan, " ", addmonitor, " ",  @"id=$xid",
                        " ", "nosoftmove"
                    );
                    run_command(cmd);
                    remaining_jobs -= 1;
                    /*
                    / if we run out of jobs, get out. on failure of one or
                    / more jobs, we are bailing out after 12 seconds anyway
                    / (as set in main())
                    */
                    if (remaining_jobs == 0) {
                        Gtk.main_quit();
                    }
                }
            }

        }
    }

    private string[] validpathlist (string directory) {
        // fetch valid filepaths inside layout folder
        string[] found_valids = {};
        try {
            var dr = Dir.open(directory);
            string ? filename = null;
            while ((filename = dr.read_name()) != null) {
                string candidate = Path.build_filename(directory, filename);
                if (
                    (FileUtils.test (candidate, FileTest.IS_REGULAR)) &&
                    candidate.contains(".windowlayout")
                )
                {
                    found_valids += candidate;
                }
            }
            return found_valids;
        }
        catch (Error e) {
            error ("%s", e.message);
        }
    }

    public static void main (string[] args) {
        // creat triggerfile to temporarily disable possibly set windowrules
        string user = Environment.get_user_name();
        File busy = File.new_for_path ("/tmp/".concat(user, "_running_layout"));
        try {
            if (!busy.query_exists()) {
                busy.create(FileCreateFlags.REPLACE_DESTINATION);
            }
        }
        catch (Error e) {
            error ("%s", e.message);
        }
        // make sure directories exist, get full path to layout dir
        string layoutfolder = args[1];
        string searchpath = create_dirs_file(
            ".config/budgie-extras/shuffler/layouts"
        );
        string layoutpath = searchpath.concat("/", layoutfolder);
        // see if layoutname is valid, directory exists
        if (FileUtils.test (layoutpath, FileTest.IS_DIR)) {
            // create file list from dir
            string[] validpaths = validpathlist(layoutpath);
            // remaining jobs - to decide when to quit
            remaining_jobs = validpaths.length;
            // now run Gtk thread, read data, do the job
            layoutdata = find_data(validpaths);
            Gtk.init(ref args);
            // limit max lifetime, quit after 12 seconds in any case
            GLib.Timeout.add_seconds(12, ()=> {
                Gtk.main_quit();
                return false;
            });
            // ok, back to work
            wnck_scr = Wnck.Screen.get_default ();
            wnck_scr.force_update ();
            // get existing windows on initial situation first
            currwindows = {};
            unowned GLib.List<Wnck.Window> currwins = wnck_scr.get_windows ();
            // but store and check them as xid array, to prevent Wnck acting up
            foreach (Wnck.Window w in currwins) {
                int xid = (int)w.get_xid ();
                currwindows += xid;
            }
            wnck_scr.window_opened.connect(act_onnewwindow);
            // now we have all data we need, let's launch windows
            foreach (LayoutElement le in layoutdata) {
                run_command(le.command);
            }
            Gtk.main();
        }
        else {
            print ("layoutname is not valid\n");
        }
        try {
            busy.delete();
        }
        catch (Error e) {
            // file was deleted or not created at all
        }
    }
}