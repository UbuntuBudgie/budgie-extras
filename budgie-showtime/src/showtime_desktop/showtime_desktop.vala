using Gtk;
using Math;
using Cairo;


namespace  ShowTime {

    private Label timelabel;
    private Label datelabel;
    GLib.Settings showtime_settings;
    private class ShowTimeappearance {
        private string css_template = """
        .timelabel {
            font-size: bigfontpx;
            color: xxx-xxx-xxx;
            font-family: "Timefont";
        }
        .datelabel {
            font-size: smallfontpx;
            color: yyy-yyy-yyy;
            font-family: "Datefont";
        }
        """;

        public void get_css (Gdk.Screen screen) {
            string[] tcolor = showtime_settings.get_strv("timecolor");
            string[] dcolor = showtime_settings.get_strv("datecolor");
            string bigfont = showtime_settings.get_int("timefontsize").to_string();
            string smallfont = showtime_settings.get_int("datefontsize").to_string();
            string fontfamily_time = showtime_settings.get_string("timefont");
            string fontfamily_date = showtime_settings.get_string("datefont");
            string showtime_css = css_template.replace(
                "xxx-xxx-xxx", "rgb(".concat(string.joinv(", ", tcolor), ")")
            ).replace(
                "yyy-yyy-yyy", "rgb(".concat(string.joinv(", ", dcolor), ")")
            ).replace(
                "bigfont", bigfont
            ).replace(
                "smallfont", smallfont
            ).replace(
                "Timefont", fontfamily_time
            ).replace(
                "Datefont", fontfamily_date
            );

            // set / update time label
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            timelabel.get_style_context().remove_class("timelabel");
            datelabel.get_style_context().remove_class("datelabel");

            try {
                css_provider.load_from_data(showtime_css);
                Gtk.StyleContext.add_provider_for_screen(
                    screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
                timelabel.get_style_context().add_class("timelabel");
                datelabel.get_style_context().add_class("datelabel");
            }
            catch (Error e) {
                // not much to be done
                print("Error loading css data\n");
            }
        }
    }


    public class TimeWindow : Gtk.Window {
        int next_time;
        bool twelvehrs;
        bool showdate;
        string dateformat;
        ShowTimeappearance appearance;
        bool skip_update = false;
        int root_x;
        int root_y;

        public TimeWindow () {
            // define stuff
            check_res();

            showtime_settings = new GLib.Settings(
                "org.ubuntubudgie.plugins.budgie-showtime"
            );
            dateformat = get_dateformat();
            appearance = new ShowTimeappearance();
            // window
            this.title = "desktop_showtime";
            this.set_type_hint(Gdk.WindowTypeHint.DESKTOP);
            //this.stick();
            this.destroy.connect(Gtk.main_quit);
            this.set_decorated(false);
            var screen = this.get_screen();
            var maingrid = new Grid();
            timelabel = new Label("");
            datelabel = new Label("");
            // position
            set_windowposition();
            //root_x = showtime_settings.get_int("xposition");
            //root_y = showtime_settings.get_int("yposition");
            //this.move(root_x, root_y);
            maingrid.attach(timelabel, 0, 0, 1, 1);
            maingrid.attach(datelabel, 0, 1, 1, 1);
            this.add(maingrid);
            string[] bind = {
                "datecolor", "datefont", "datefontsize", "leftalign",
                "showdate", "timecolor", "timefont", "timefontsize",
                "twelvehrs", "xposition", "yposition"
            };
            foreach (string s in bind) {
                showtime_settings.changed[s].connect(update_appearance);
            }
            showtime_settings.changed["draggable"].connect(update_positionsettings);
            update_appearance();
            appearance.get_css(screen);
            bool skip_update = true;
            //update_positionsettings ();
            skip_update = false;
            // transparency
            this.set_app_paintable(true);
            var visual = screen.get_rgba_visual();
            this.set_visual(visual);
            this.draw.connect(on_draw);
            this.show_all();
            new Thread<bool> ("oldtimer", run_time);
        }
        private void set_windowposition () {
            root_x = showtime_settings.get_int("xposition");
            root_y = showtime_settings.get_int("yposition");
            int[] geodata = check_res();
            if (root_x == 1 && root_y == -1) {
                root_x = geodata[2] + 150;
                root_y = geodata[3] + geodata[1] - 320;
            }
            else if (root_x == 2 && root_y == -1) {
                root_x = geodata[2] + geodata[0] - 400;
                root_y = geodata[3] + geodata[1] - 320;
            }
            this.move(root_x, root_y);
        }

        private int[] check_res() {
            /* see what is the resolution on the primary monitor */
            var prim = Gdk.Display.get_default().get_primary_monitor();
            var geo = prim.get_geometry();
            int width = geo.width;
            int height = geo.height;
            int screen_xpos = geo.x;
            int screen_ypos = geo.y;
            return {width, height, screen_xpos, screen_ypos};
        }

        private bool on_draw (Widget da, Context ctx) {
            // needs to be connected to transparency settings change
            ctx.set_source_rgba(0, 0, 0, 0);
            ctx.set_operator(Cairo.Operator.SOURCE);
            ctx.paint();
            ctx.set_operator(Cairo.Operator.OVER);
            return false;
        }

        private int get_stringindex (string[] arr, string lookfor) {
            // get index of string in list
            for (int i=0; i < arr.length; i++) {
                if(lookfor == arr[i]) return i;
            }
            return -1;
        }

        /* private string capitalize (string s) {
            string header = s.substring(0, 1).up();
            string remaining = s.substring(1, s.length - 1);
            return header.concat(remaining);
        } */

        private string fix_mins(int minutes) {
            // make sure the minutes are displayed in double digits
            string minsdisplay = minutes.to_string();
            if (minsdisplay.length == 1) {
                return "0".concat(minsdisplay);
            }
            return minsdisplay;
        }

        private string get_localtime (DateTime newtime) {
            int mins = newtime.get_minute();
            int hrs = newtime.get_hour();
            int newhrs = hrs;
            string add = "";
            string showmins = fix_mins(mins);
            // hrs to double digits
            if (twelvehrs) {
                add = " ".concat("AM"); //translate!!
                if (hrs > 12) {
                    newhrs = hrs - 12;
                }
                else if (hrs < 1) {
                    newhrs = hrs + 12;
                }
                if (12 <= hrs < 24) {
                    add = " ".concat("PM");
                }
            }
            string hrs_display = fix_mins(newhrs);
            return @"$hrs_display:$showmins$add";
        }

        private string get_dateformat () {
            string date_fmt = showtime_settings.get_string("dateformat");
            if (date_fmt == "") {
                return read_dateformat();
            }
            return date_fmt;
        }

        private string read_dateformat () {
            string[] date_data = {"%a", "%e", "%b"};
            string[] full_data = {"%A", "%e", "%B"};
            string cmd = "locale date_fmt";
            string output = "";
            string match = "";
            try {
                StringBuilder builder = new StringBuilder ();
                GLib.Process.spawn_command_line_sync(cmd, out output);
                string[] output_data = output.split(" ");
                foreach (string s in output_data) {
                    int index = get_stringindex(date_data, s);
                    if (index != -1) {
                        match = full_data[index];
                        builder.append (match).append (" ");
                    }
                }
                return builder.str;
            }
            catch (Error e) {
                return ""; // fallback to default (edit!!)
            }
        }

        private void update_positionsettings () {
            bool draggable = showtime_settings.get_boolean("draggable");
            if (draggable) {
                this.set_type_hint(Gdk.WindowTypeHint.NORMAL);
            }
            else if (!skip_update) {
                this.set_type_hint(Gdk.WindowTypeHint.DESKTOP);
                int newroot_x;
                int newroot_y;
                this.get_position (out newroot_x, out newroot_y);
                root_x = newroot_x;
                root_y = newroot_y;
                showtime_settings.set_int("xposition", newroot_x);
                showtime_settings.set_int("yposition", newroot_y);
            }
        }

        private void update_appearance () {
            // text align
            int al = 1;
            if (showtime_settings.get_boolean("leftalign")) {
                al = 0;
            }
            timelabel.xalign = al;
            datelabel.xalign = al;
            // showdate
            showdate = showtime_settings.get_boolean("showdate");
            twelvehrs = showtime_settings.get_boolean("twelvehrs");
            appearance.get_css(screen);
            update_interface();
        }

        private void update_interface () {
            var now = new DateTime.now_local();
            // get_localtime(now), now.format(dateformat)
            timelabel.set_label(get_localtime(now));
            string datestring = now.format(dateformat);
            if (!showdate) {
                datestring = "";
            }
            datelabel.set_label(datestring);
        }

        private bool check_onapplet () {
            /* check if the applet still runs */
            string cmd = "dconf dump /com/solus-project/budgie-panel/applets/";
            string output;
            try {
                GLib.Process.spawn_command_line_sync(cmd, out output);
            }
            /* on an occasional exception, don't break the loop */
            catch (SpawnError e) {
                return true;
            }
            bool check = output.contains("ShowTime");
            return check;
        }

        private int convert_remainder_topositive (double subj, double rem) {
            // Math.remainder possibly gives a negative output, seems silly
            if (rem < 0) {
                return (int)(subj + rem);
            }
            return (int)rem;
        }

        private int[] calibrate_time () {
            /*
            the cycle is double-layered: once per 6 seconds, there is a
            dconf check to see if the applet is still on the panel
            (kill the thread & window if not), once per minute fine-
            tune the minute-sync. On startup, we need to synchroonize
            the cycle so that time update is done exactly on minute-
            switch. additionally, once per minute we sync with real clock
             */
            var curr_time = new DateTime.now_local();
            int curr_sec = curr_time.get_second();
            int curr_remaining = convert_remainder_topositive(
                6, Math.remainder (60 - (double)curr_sec, 6)
            );
            int remaining_cycles = (int)((60 - curr_sec) / 6);
            return {curr_remaining, remaining_cycles};
        }

        private bool run_time () {
            // make sure time shows instantly
            update_interface();
            calibrate_time();
            // this is the main time-loop
            int[] calibrated_loopdata = calibrate_time();
            int loopcycle = 0;
            while (true) {
                if (!check_onapplet()) {
                    // exiting if applet is removed
                    Gtk.main_quit();
                    break;
                }
                if (loopcycle == 0){
                    next_time = calibrated_loopdata[0];
                }
                if (loopcycle >= calibrated_loopdata[1]) {
                    calibrated_loopdata = calibrate_time();
                    loopcycle = 0;
                    Idle.add ( () => {
                        update_interface();
                        return false;
                    });
                }
                loopcycle += 1;
                Thread.usleep(next_time * 1000000);
                next_time = 6;
            }
            return false;
        }
    }

    public static void main (string[] args) {
        Gtk.init(ref args);
        new TimeWindow();
        Gtk.main();
    }

}