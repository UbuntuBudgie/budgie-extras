using Gtk;
using Cairo;
using Gdk;

/*
* WeatherShowII
* Author: Jacob Vlijm
* Copyright © 2017-2019 Ubuntu Budgie Developers
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


public class DesktopWeather : Gtk.Window {

    private File datasrc;
    private FileMonitor monitor;
    private Gtk.Grid maingrid;
    Label locationlabel;
    Label weatherlabel;
    GLib.Settings desktop_settings;
    private string css_data;
    private string css_template;
    Gtk.CssProvider css_provider;
    double new_transp;
    private Gdk.Pixbuf[] iconpixbufs_1;
    private Gdk.Pixbuf[] iconpixbufs_2;
    private Gdk.Pixbuf[] iconpixbufs_3;
    int currscale;
    string[] iconnames = {};
    Image weather_image;


    public DesktopWeather () {
        // this window monitors the datafile, maintained by the applet.
        this.set_decorated(false);
        this.set_type_hint(Gdk.WindowTypeHint.DESKTOP);
        currscale = 1;
        // get icon data
        get_icondata();
        check_res();
        // template. x-es are replaced on color set
        css_template = """
            .biglabel {
                font-size: bigfontpx;
                color: xxx-xxx-xxx;

            }
            .label {
                font-size: smallfontpx;
                color: xxx-xxx-xxx;
            }
            """;
        // gsettings stuff
        desktop_settings = get_settings(
            "org.ubuntubudgie.plugins.weathershow"
        );

        set_windowpos();
        desktop_settings.changed["xposition"].connect(set_windowpos);
        desktop_settings.changed["yposition"].connect(set_windowpos);
        desktop_settings.changed["desktopweather"].connect (() => {
            bool newval = desktop_settings.get_boolean("desktopweather");
            if (newval == false) {
                Gtk.main_quit();
            }
        });
        desktop_settings.changed["textcolor"].connect (() => {
            update_style();
        });
        desktop_settings.changed["transparency"].connect (() => {
            int transparency = 100 - desktop_settings.get_int("transparency");
            new_transp = transparency/100.0;
            this.queue_draw();
        });
        desktop_settings.changed["desktopweather"].connect (() => {
            bool newval = desktop_settings.get_boolean("desktopweather");
            if (newval == false) {
                Gtk.main_quit();
            }
        });
        css_data = get_css();
        int transparency = 100 - desktop_settings.get_int("transparency");
        new_transp = transparency/100.0;
        // transparency
        var screen = this.get_screen();
        this.set_app_paintable(true);
        var visual = screen.get_rgba_visual();
        this.set_visual(visual);
        this.draw.connect(on_draw);
        // monitored datafile
        string username = Environment.get_user_name();
        string src = "/tmp/".concat(username, "_weatherdata");
        datasrc = File.new_for_path(src);
        // report
        maingrid = new Gtk.Grid();
        maingrid.set_column_spacing(20);
        maingrid.attach(new Label(" "), 0, 0, 1, 1);
        maingrid.attach(new Label(" "), 10, 10, 1, 1);
        this.add(maingrid);
        locationlabel = new Label("");
        weatherlabel = new Label("");
        weatherlabel.set_xalign(0);
        locationlabel.set_xalign(0);
        // css (needs a separate function to update)
        css_provider = new Gtk.CssProvider();
        css_provider.load_from_data(css_data);
        Gtk.StyleContext.add_provider_for_screen(
            screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
        );
        weatherlabel.get_style_context().add_class("label");
        locationlabel.get_style_context().add_class("biglabel");
        maingrid.attach(locationlabel, 2, 1, 1, 1);
        maingrid.attach(weatherlabel, 2, 2, 1, 1);
        weather_image = new Gtk.Image();
        maingrid.attach(weather_image, 1, 1, 1, 5);
        // monitor
        monitor = datasrc.monitor(FileMonitorFlags.NONE, null);
        monitor.changed.connect(update_content);
        update_content();
    }

    private bool on_draw (Widget da, Context ctx) {
        // needs to be connected to transparency settings change
        ctx.set_source_rgba(0, 0, 0, new_transp);
        ctx.set_operator(Cairo.Operator.SOURCE);
        ctx.paint();
        ctx.set_operator(Cairo.Operator.OVER);
        return false;
    }

    private void check_res() {
        /* see what is the resolution on the primary monitor */
        var prim = Gdk.Display.get_default().get_primary_monitor();
        var geo = prim.get_geometry();
        int height = geo.height;
        if (height < 1100) {currscale = 1;}
        else if (height < 1600) {currscale = 2;}
        else {currscale = 3;}
    }

    private void set_windowpos () {
        int xpos = desktop_settings.get_int("xposition");
        int ypos = desktop_settings.get_int("yposition");
        this.move(xpos, ypos);
    }

    private GLib.Settings get_settings(string path) {
        var settings = new GLib.Settings(path);
        return settings;
    }

    private string get_css() {
        string[] currcolor = desktop_settings.get_strv("textcolor");
        string temp_css = css_template.replace(
            "xxx-xxx-xxx", "rgb(".concat(string.joinv(", ", currcolor), ")")
        );
        string bigfont = "20"; string smallfont = "15";
        switch(currscale) {
            case(1): bigfont = "25"; smallfont = "17"; break;
            case(2): bigfont = "37"; smallfont = "22"; break;
            case(3): bigfont = "50"; smallfont = "32"; break;
        }
        return temp_css.replace("bigfont", bigfont).replace("smallfont", smallfont);
    }

    private int get_stringindex (string s, string[] arr) {
        // get index of a string in an array
        for (int i=0; i < arr.length; i++) {
            if(s == arr[i]) return i;
        } return -1;
    }

    private void update_content () {
        Pixbuf[] currimages = {};
        // just for fun: let's use switch for a change
        switch(currscale) {
            case(1): currimages = iconpixbufs_1; break;
            case(2): currimages = iconpixbufs_2; break;
            case(3): currimages = iconpixbufs_3; break;
        }
        try {
            var dis = new DataInputStream (datasrc.read ());
            string line;
            string[] weatherlines = {};
            while ((line = dis.read_line (null)) != null) {
                weatherlines += line;
            }
            int len_content = weatherlines.length;
            if (len_content != 0) {
                string newicon = find_mappedid(
                    weatherlines[0]
                ).concat(weatherlines[1]);
                int ic_index = get_stringindex(newicon, iconnames);
                weather_image.set_from_pixbuf(currimages[ic_index]);
                int n_lines = weatherlines.length;
                string weathersection = string.joinv("\n", weatherlines[3:n_lines]);
                locationlabel.set_label(weatherlines[2].strip());
                weatherlabel.set_label(weathersection);
            }
        }
        catch (Error e) {
            /*
            * on each refresh, the file is deleted by the applet
            * just wait for next signal.
            */
        }
    }

    private void update_style() {
        // update the window if weather (file/datasrc) or settings changes
        // get/update textcolor
        css_data = get_css();
        weatherlabel.get_style_context().remove_class("label");
        locationlabel.get_style_context().remove_class("biglabel");
        css_provider.load_from_data(css_data);
        locationlabel.get_style_context().add_class("biglabel");
        weatherlabel.get_style_context().add_class("label");
    }

    private string find_mappedid (string ? icon_id = null) {
        /*
        * OWM's icon codes are a bit oversimplified; different weather
        * types are pushed into one icon. the data ("id") however offers a
        * much more detailed set of weather types/codes, which can be used to
        * set an improved icon mapping. below my own (again) simplification
        * of the extended set of weather codes, which is kind of the middle
        * between the two.
        */
        string[,] replacements = {
            {"221", "212"}, {"231", "230"}, {"232", "230"}, {"301", "300"},
            {"302", "300"}, {"310", "300"}, {"312", "311"}, {"314", "313"},
            {"502", "501"}, {"503", "501"}, {"504", "501"}, {"522", "521"},
            {"531", "521"}, {"622", "621"}, {"711", "701"}, {"721", "701"},
            {"731", "701"}, {"741", "701"}, {"751", "701"}, {"761", "701"},
            {"762", "701"}
        };
        int lenrep = replacements.length[0];
        for (int i=0; i < lenrep; i++) {
            if (icon_id == replacements[i, 0]) {
                return replacements[i, 1];
            }
        }
        return icon_id;
    }

    private void get_icondata () {
        // fetch the icon list
        string icondir = "/".concat(
            "usr/lib/budgie-desktop/plugins",
            "/budgie-weathershow/weather_icons"
        );
        iconnames = {};
        iconpixbufs_1 = {};
        iconpixbufs_2 = {};
        iconpixbufs_3 = {};
        try {
            var dr = Dir.open(icondir);
            string ? filename = null;
            while ((filename = dr.read_name()) != null) {
                // add to icon names
                iconnames += filename[0:4];
                // add to pixbufs
                string iconpath = GLib.Path.build_filename(
                    icondir, filename
                );
                iconpixbufs_1 += new Pixbuf.from_file_at_size (
                    iconpath, 150, 150
                );
                iconpixbufs_2 += new Pixbuf.from_file_at_size (
                    iconpath, 220, 220
                );
                iconpixbufs_3 += new Pixbuf.from_file_at_size (
                    iconpath, 320, 320
                );
            }
        } catch (FileError err) {
                // unlikely to occur, but:
                print("Something went wrong loading the icons");
        }
    }


    public static void main(string[] ? args = null) {
        Gtk.init(ref args);
        Gtk.Window win = new DesktopWeather();
        win.set_decorated(false);
        win.show_all();
        win.destroy.connect(Gtk.main_quit);
        Gtk.main();
    }
}
