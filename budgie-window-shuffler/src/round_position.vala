
namespace GetClosest {

    /*
    This snippet is to be used as a building block in shuffler. its
    purpose is to evaluate how a window, roughly placed, possibly
    manually, would fit in a grid. Since we don't know what gridsize
    would be the best fit, grids up to an arbitrary n-cells (either colls
    or rows) will be evaluated.
    In shuffler, this will give us the option to add the active window's
    position as a rule, or to add it to a layout, without having to define
    the position manually in the rules or layouts dialogue window. Fine tuning
    will still be possible though for those who want or need to, e.g. to set
    target workspace or monitor, or to call the window by a specific command.
    */

    /*
    how we decide:
    to make an educated guess about the best fit in a grid of x colls or rows,
    we are looking at two things: the distance to the targeted grid-position,
    and the necessary resize to fit into n-cellspan. the algorithm used is
    simply to sum up these two, and evaluate what gives us the smallest,
    considering all cellspans and gridsizes up to a max gridsize.

    screensize/windowsize, position will be retrieved from shuffler daemon
    (obviously)
    */

    ShufflerInfoClient client;
    int activewin;
    HashTable<string, Variant> windata;
    HashTable<string, Variant> mondata;

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        //  public abstract HashTable<string, Variant> get_tiles (string mon, int cols, int rows) throws Error;
        public abstract string getactivemon_name () throws Error;
        public abstract GLib.HashTable<string, Variant> get_monitorgeometry () throws Error;
        //  public abstract int[] get_grid () throws Error;
        public abstract int getactivewin () throws Error;
        //  public abstract void activate_window (int curr_active) throws Error;
        //  public abstract bool get_stickyneighbors () throws Error;
    }



    public static int main (string[] args) {
        try {
            client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );

//// all below in a separate method on success
            // get data on current monitor
            int monwidth = -1;
            int monheight = -1;
            string monname = client.getactivemon_name();
            mondata = client.get_monitorgeometry();
            foreach (string monkey in mondata.get_keys()) {
                if (monname == monkey) {
                    Variant currmon = mondata[monname];
                    monwidth = (int)currmon.get_child_value(2);
                    monheight = (int)currmon.get_child_value(3);
                    print("monwidth = %d\n", monwidth);
                    print("monheight = %d\n", monheight);
                    print(@"Yay! $monkey\n");
                }
            }
            activewin = client.getactivewin();
            print("%d\n", activewin);
            int xpos = -1;
            int ypos = -1;
            int xsize = -1;
            int ysize = -1;
            // get data on (normal) windows, look up active
            windata = client.get_winsdata();
            foreach (string winkey in windata.get_keys()) {
                /*
                / get data on all windows here? more efficient, but nah,
                / let's keep it simple, get data on adjacent windows separated,
                / dbus is fast. long live dbus.
                */
                if (winkey == @"$activewin") {
                    Variant winvar = windata[winkey];
                    xpos = (int)winvar.get_child_value(3);
                    ypos = (int)winvar.get_child_value(4);
                    xsize = (int)winvar.get_child_value(5);
                    ysize = (int)winvar.get_child_value(6);
                    // now we have these, calc best size/pos on grid
                    // move to target
                    print("move this one to target %s %d %d %d %d\n",  winkey, xpos, ypos, xsize, ysize);
                    break;
                }
            }
            int[] targetposx = getbestgrid(xsize, xpos, monwidth, 6);
            int[] targetposy = getbestgrid(ysize, ypos, monheight, 2);
            int cellx = targetposx[1];
            int celly = targetposy[1];
            int cols = targetposx[0];
            int rows = targetposy[0];
            int spanx = targetposx[2];
            int spany = targetposy[2];


            print("xtarget: %d cols, pos: %d, span: %d\n", targetposx[0], targetposx[1], targetposx[2]);
            print("ytarget: %d rows, pos: %d, span: %d\n", targetposy[0], targetposy[1], targetposy[2]);

            string cmd = "/usr/lib/budgie-window-shuffler" + "/tile_active ".concat(
            " ", @"$cellx ", @"$celly ", @"$cols ", @"$rows ", @"$spanx ", @"$spany");
            print(@"$cmd\n");
            run_command(cmd);

        }

        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
        return 0;
    }

    void run_command (string command) {
        try {
            Process.spawn_command_line_async(command);
        }
        catch (SpawnError e) {
        }
    }

    int[] get_min_distance (
        int scrsize, int cellsize, int ncells, int wsize, int wpos
    ) {
        /*
        for given gridsize (ncells), calculate cellposition with smallest
        difference.
        */
        int diff = 100000;
        int foundpos = -1;

        for (int n=0; n<ncells; n++) {
            int spansize = n*cellsize;
            int currdiff = (wpos - spansize).abs();
            if (currdiff < diff) {
                diff = currdiff;
                /* update best cellspan */
                foundpos = n;
            }
            else {break;}
        }
        return {diff, foundpos};
    }

    int[] get_min_celldiff (
        int scrsize, int cellsize, int ncells, int wsize, int start=1
    ) {
        /*
        for given gridsize (ncells), calculate cellspan with smallest difference.
        */
        int diff = 100000;
        int foundspan = -1;
        for (int n=start; n<=ncells; n++) {
            int spansize = n*cellsize;
            int currdiff = (wsize - spansize).abs();
            if (currdiff < diff) {
                diff = currdiff;
                /* update best cellspan */
                foundspan = n;
            }
        }
        return {diff, foundspan};
    }

    int[] getbestgrid (int size, int pos, int screensize, int maxcells) {
        /*
        per gridsize, find optimal (so minimal) diff is best gridsize.
        */
        int gridsize = -1;
        int span = -1;
        int position = -1;
        int sum_divergence = 100000;
        for (int i=1; i<=maxcells; i++) {
            /* get cellsize for current gridsize (=i) */
            int cellsize = (int)((float)screensize/(float)i);
            /* get data on current 'suggested gridsize' */
            int[] min_celldiff = get_min_celldiff(screensize, cellsize, i, size);
            int[] min_psdif = get_min_distance(screensize, cellsize, i, size, pos);
            int curr_divergence = min_celldiff[0] + min_psdif[0];
            if (curr_divergence < sum_divergence) {
                sum_divergence = curr_divergence;
                gridsize = i;
                position = min_psdif[1];
                span = min_celldiff[1];
            }
        }
        print("found combined divergence: %d px\n\n", sum_divergence);
        print("gridsize: %d, target_position: %d, span: %d\n", gridsize, position, span);
        return {gridsize, position, span};
    }
}