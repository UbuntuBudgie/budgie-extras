
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

    public static int main (string[] args) {
        /*
        Just throwing some random screensize. once applied, we'll get this
        from shuffler daemon.
        */
        int size = int.parse(args[1]);
        int pos = int.parse(args[2]);
        int scrsize = 1920;
        getbestgrid(size, pos, scrsize, 6);
        return 0;
    }

    int[] get_min_distance (
        int scrsize, int cellsize, int ncells, int wsize, int wpos
    ) {
        /*
        for given gridsize (ncells), calculate cellspan with smallest
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