using Gtk;
using Wnck;

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
/ .windowtask. the folder needs to be located in
/ ~/.config/budgie-extras/shuffler/layouts. Inside the folder, dump multiple
/ files containing the following fields:
/ Exec=
/ WMClASS=
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

// todo: add SkipMinimized <- done

// valac --pkg gio-2.0 --pkg gtk+-3.0 --pkg libwnck-3.0 -X "-D WNCK_I_KNOW_THIS_IS_UNSTABLE"

namespace ShufflerLayouts {

    int[] existingwindows;
    Wnck.Screen wnck_scr;
    int remaining_jobs;
    LayoutElement[] layoutdata;
    int elementindex;
    /*
    / we need to keep record on passed elements (looking up
    / window match in data) as well as passed xids (looking up
    / data match on windows). this is for situations on mixed
    / TryExist settings on similar wm_classes.
    / yeah, complicated, complicated...
    */
    int[] indices_done;
    int[] xids_moved_windows;

    struct LayoutElement {
        int index;
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
        string tryexisting;
    }

    private LayoutElement extractlayout_fromfile (string path) {
        string[] fields = {
            "Exec", "XPosition", "YPosition", "Cols", "Rows",
            "XSpan", "YSpan", "WMClass", "WName", "Monitor",
            "TryExisting"
        };
        var newrecord = LayoutElement();
        // let's set some defaults
        newrecord.index = elementindex;
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
        newrecord.tryexisting = "false";
        DataInputStream? dis = null;
        try {
            var file = File.new_for_path (path);
            dis = new DataInputStream (file.read ());
            string line;
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
                            newrecord.wmclass = new_value.down();
                            break;
                        case 8:
                            newrecord.wname = new_value.down();
                            break;
                        case 9:
                            newrecord.monitor = new_value;
                            break;
                        case 10:
                            newrecord.tryexisting = new_value;
                            break;
                        }
                    }
                    fieldindex += 1;
                }
            }
        }
        catch (Error e) {
            error ("%s", e.message);
        }
        elementindex += 1;
        // test
        string com = newrecord.command;
        string cls = newrecord.wmclass;
        string colss = newrecord.cols;
        string rowss = newrecord.rows;
        string xp = newrecord.x_ongrid;
        string yp = newrecord.y_ongrid;
        return newrecord;
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

    private void get_layoutdata (string[] files) {
        LayoutElement[] generic_elements = {};
        foreach (string path in files) {
            /*
            / when looking up window match in layoutElements, we need to
            / give priority to elements that include a window -name-
            / ("WName=" field), to prevent "stealing" a match by a generic
            / match (no wname set) from a more specific match (window name
            / is set).
            / we'll keep the unnamed separated first, adding them afterwards
            */
            LayoutElement new_le = extractlayout_fromfile(path);
            if (new_le.wname != "") {
                layoutdata += new_le;
            }
            else {
                generic_elements += new_le;
            }
        }
        foreach (LayoutElement le in generic_elements) {
            layoutdata += le;
        }
    }

    private void create_busyfile (File busyfile) {
        // create triggerfile to temporarily disable possibly set windowrules
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
    }

    private bool check_intinlist (int intval, int[] arr) {
        // check if in in array
        for (int i=0; i<arr.length; i++) {
            if (intval == arr[i]) {
                return true;
            }
        }
        return false;
    }

    private bool element_matcheswindow (LayoutElement le, string wname, string wmclass) {
        // just comparing / checking strings (wname/wclass)
        string element_name = le.wname;
        string element_wmclass = le.wmclass;
        if (wname.contains(element_name) &&  element_wmclass == wmclass) {
            return true;
        }
        return false;
    }

    private void findmatch_andmove (string wname, string wmclass, int xid) {
        /*
        / find matching LayoutElement, check if job hasn't been done yet*
        / *the latter is to prevent the theoretical possiblity that, if
        / multiple windows are called with the same specs but different
        / target positions, windows repeatedly land on the position, defined
        / in the first matching window name/wmclass combination of a
        / LayoutElement.
        */
        // check window name & class for layoutmatch, move window

        foreach (LayoutElement lel in layoutdata) {
            int lel_index = lel.index;
            bool xid_isused = check_intinlist(xid, xids_moved_windows);
            if (!check_intinlist(lel_index, indices_done) && !xid_isused) {
                bool ismatch = element_matcheswindow(lel, wname, wmclass);
                if (ismatch) {
                    indices_done += lel_index;
                    remaining_jobs -= 1;
                    makeyourmove(lel, xid);
                    xids_moved_windows += xid;
                    if (remaining_jobs == 0) {
                        Gtk.main_quit();
                    }
                }
            }
        }
    }

    private bool on_this_workspace (Wnck.Window win) {
        Wnck.Workspace current = wnck_scr.get_active_workspace();
        if (win.get_workspace() == current) {
            return true;
        }
        return false;
    }

    private void act_onnewwindow(Wnck.Window new_win) {
        int? xid = (int)new_win.get_xid();
        string firstname = new_win.get_name();
        int i = 0;
        string lastname = "";
        /*
        / due to the fact that window names change after creation,
        / of some applications, we need a built-in timeout during which
        / we allow the name to change
        */

        Timeout.add(20, ()=> {
            lastname = new_win.get_name();
            if (firstname != lastname || i > 20) {
                bool existed = check_intinlist(xid, existingwindows);
                string newclass = new_win.get_class_group_name().down();
                bool window_isnormal = new_win.get_window_type() == Wnck.WindowType.NORMAL;
                if (!existed && window_isnormal) {
                    findmatch_andmove(lastname.down(), newclass, xid);
                }
                return false;
            }
            i += 1;
            return true;
        });
    }

    private void makeyourmove (LayoutElement le, int xid) {
        // perform move action. we're not using animation for now
        // see if we need to set monitor
        string addmonitor = le.monitor;
        if (addmonitor != "") {
            addmonitor = @"monitor=$addmonitor";
        }
        string cmd = "/usr/lib/budgie-window-shuffler" + "/tile_active ".concat(
        //  string cmd = Config.SHUFFLER_DIR + "/tile_active ".concat(
            le.x_ongrid, " ", le.y_ongrid, " ", le.cols, " ", le.rows,
            " ", le.xspan, " ", le.yspan, " ",   @"id=$xid", " ", addmonitor,
            " ", "nosoftmove"
        );
        run_command(cmd);
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
                    candidate.contains(".windowtask")
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

    public static void main(string[] args) {
        /*
        / in case we launch multiple exactly similar windows to different
        / positions, we need a unique identifier
        */
        elementindex = 0;
        indices_done = {};
        xids_moved_windows = {};
        // define & create triggerfile (putting rules on hold)
        string user = Environment.get_user_name();
        File busyfile = File.new_for_path (
            "/tmp/".concat(user, "_running_layout")
        );
        create_busyfile(busyfile);
        // get windowlist (xid) of windows that existed on launch
        Gtk.init(ref args);
        existingwindows = {};
        wnck_scr = Wnck.Screen.get_default();
        wnck_scr.force_update();
        foreach (Wnck.Window w in wnck_scr.get_windows()) {
        // using int - don't want to make extra method for ulong
            existingwindows += (int)w.get_xid();
        }
        // take action on new windows
        wnck_scr.window_opened.connect(act_onnewwindow);
        // get layout data
        string searchpath = create_dirs_file(
            ".config/budgie-extras/shuffler/layouts"
        );
        // subfolder and -> layoutpath
        string layoutfolder = args[1];
        string layoutpath = searchpath.concat("/", layoutfolder);
        string[] validpaths = {};
        // and if all is correct, go fetch data
        if (FileUtils.test (layoutpath, FileTest.IS_DIR)) {
        // create file list from dir
            validpaths = validpathlist(layoutpath);
        }
        get_layoutdata(validpaths);
        remaining_jobs = layoutdata.length;
        foreach (LayoutElement lel in layoutdata) {
            // first let's see if we need to grab an existing window
            bool trybeforeyoubuy = lel.tryexisting == "true";
            // if moving existing fails, we need to launch new window
            bool found_match = false;
            if (trybeforeyoubuy) {
                string lookforclass = lel.wmclass;
                string lookforwname = lel.wname;
                // see if any of the windows matches name + class
                foreach (
                    Wnck.Window w_exists in wnck_scr.get_windows()
                ) {
                    bool xid_isused = check_intinlist((int)w_exists.get_xid(), xids_moved_windows);
                    bool class_matches = w_exists.get_class_group_name().down() == lookforclass;
                    bool name_matches = w_exists.get_name().down().contains(lookforwname);
                    // check if job is already claimed to be done
                    int exclude = lel.index;
                    bool passed = check_intinlist(exclude, indices_done);
                    bool isvisible = !w_exists.is_minimized();
                    if (
                        name_matches && class_matches && !passed &&
                        on_this_workspace(w_exists) && !xid_isused &&
                        isvisible
                    ) {
                        // move existing
                        int xid = (int)w_exists.get_xid();
                        xids_moved_windows += xid;
                        /*
                        / nah, we could combine indices_done & remaining jobs
                        / since their length implies the same, but we're lazy
                        */
                        indices_done += exclude;
                        remaining_jobs -= 1;
                        makeyourmove(lel, xid);
                        found_match = true;
                    }
                }
            }
            // if no existing window was moved, launch new
            if (!found_match) {
                run_command(lel.command);
            }
        }
        Timeout.add_seconds(12, ()=> {
            // make sure to quit after x time anyway
            Gtk.main_quit();
            return false;
        });
        if (remaining_jobs != 0) {
            /*
            / if all jobs are done, no need to fire up connect & all
            / e.g. in case all jobs were move-only jobs
            */
            Gtk.main();
        }
        Thread.usleep(10000);
        try {
            busyfile.delete();
        }
        catch (Error e) {
            error ("%s", e.message);
        }
    }
}