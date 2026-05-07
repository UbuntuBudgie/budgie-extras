using Gtk;
using Cairo;
using Gdk;

/*
* WeatherShowII
* Author: Jacob Vlijm
* Copyright © 2017 Ubuntu Budgie Developers
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

    private bool find_applet (string uuid, string[] applets) {
        for (int i = 0; i < applets.length; i++) {
            if (applets[i] == uuid) {
                return true;
            }
        }
        return false;
    }

    void watchapplet (string uuid) {
        // make applet's loop end if applet is removed
        string general_path = "com.solus-project.budgie-panel";
        string[] applets;
        GLib.Settings? panel_settings = new GLib.Settings(general_path);
        string[] allpanels_list = panel_settings.get_strv("panels");
        foreach (string p in allpanels_list) {
            string panelpath = "/com/solus-project/budgie-panel/panels/".concat("{", p, "}/");
            GLib.Settings? currpanelsubject_settings = new GLib.Settings.with_path(
                general_path + ".panel", panelpath
            );
            applets = currpanelsubject_settings.get_strv("applets");
            if (find_applet(uuid, applets)) {
                currpanelsubject_settings.changed["applets"].connect(() => {
                    applets = currpanelsubject_settings.get_strv("applets");
                    if (!find_applet(uuid, applets)) {
                        Gtk.main_quit();
                    }
                });
                break;
            }
        }
    }

    public DesktopWeather (string uuid) {

        GLib.Timeout.add_seconds(1, ()=> {
            watchapplet(uuid);
            return false;
        });
#if FOR_WAYLAND
        GtkLayerShell.init_for_window(this);
        GtkLayerShell.set_layer(this, GtkLayerShell.Layer.BOTTOM);
#endif
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
        string tmpdir = Environment.get_variable("XDG_RUNTIME_DIR") ?? Environment.get_variable("HOME");
        string src = GLib.Path.build_path(GLib.Path.DIR_SEPARATOR_S, tmpdir, ".weatherdata");
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
        load_css(css_data);
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
        try {
            monitor = datasrc.monitor(FileMonitorFlags.NONE, null);
            monitor.changed.connect(update_content);
        }
        catch (Error e) {
            print("Error setting up monitor\n");
        }
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
#if FOR_WAYLAND
        var prim = libxfce4windowing.Screen.get_default().get_primary_monitor();
        var geo = prim.get_physical_geometry();
#else
        var prim = Gdk.Display.get_default().get_primary_monitor();
        var geo = prim.get_geometry();
#endif
        int height = geo.height;
        if (height < 1100) {currscale = 1;}
        else if (height < 1600) {currscale = 2;}
        else {currscale = 3;}
    }

    private void set_windowpos () {
#if FOR_WAYLAND
        var prim = libxfce4windowing.Screen.get_default().get_primary_monitor();
        int currscale = (int) prim.get_scale();
        int xpos = desktop_settings.get_int("xposition") / currscale;
        int ypos = desktop_settings.get_int("yposition") / currscale;
        GtkLayerShell.set_monitor(this, prim.gdk_monitor);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.LEFT, xpos);
        GtkLayerShell.set_margin(this, GtkLayerShell.Edge.TOP, ypos);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.LEFT, true);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.TOP, true);
#else
        var prim = Gdk.Display.get_default().get_primary_monitor();
        int currscale = prim.get_scale_factor();
        int xpos = desktop_settings.get_int("xposition") / currscale;
        int ypos = desktop_settings.get_int("yposition") / currscale;
        this.move(xpos, ypos);
#endif
    }

    private new GLib.Settings get_settings(string path) {
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

        /* check: icon arrays must be non-empty before we touch them */
        Pixbuf[] currimages = {};
        switch (currscale) {
            case(1): currimages = iconpixbufs_1; break;
            case(2): currimages = iconpixbufs_2; break;
            case(3): currimages = iconpixbufs_3; break;
        }
        if (currimages.length == 0) {
            /* Nothing we can safely display; log and bail.               */
            warning("update_content: icon array is empty - skipping update\n");
            return;
        }

        /* Resolve the fallback index once, before any early returns.
         * If even the error icon is absent we set a hard-coded 0 so we
         * never pass a negative or out-of-range value to set_from_pixbuf. */
        int fallback_index = get_stringindex("erro", iconnames);
        if (fallback_index < 0 || fallback_index >= currimages.length) {
            /* check 2: "erro" icon not installed; use first available */
            warning("update_content: fallback 'erro' icon not found; using index 0\n");
            fallback_index = 0;
        }

        try {
            var dis = new DataInputStream (datasrc.read ());
            string line;
            string[] weatherlines = {};
            while ((line = dis.read_line (null)) != null) {
                weatherlines += line;
            }

            int len_content = weatherlines.length;

            /* check: need at least lines[0] (id) and [1] (d/n)
             * A partial file written during a race may yield 0 or 1 lines.
             * Also require line[2] for the city name and line[3..] for body. */
            if (len_content < 4) {
                warning("update_content: incomplete data (%d lines); skipping\n",
                      len_content);
                return;
            }

            /* check: validate the icon-key components are non-empty */
            string raw_id     = weatherlines[0].strip();
            string raw_suffix = weatherlines[1].strip();

            if (raw_id == "" || raw_suffix == "") {
                warning("update_content: empty id ('%s') or suffix ('%s'); " +
                      "using fallback icon\n", raw_id, raw_suffix);
                weather_image.set_from_pixbuf(currimages[fallback_index]);
                /* Still update the text labels if city/weather are present. */
                locationlabel.set_label(weatherlines[2].strip());
                int n_lines = weatherlines.length;
                weatherlabel.set_label(
                    string.joinv("\n", weatherlines[3:n_lines])
                );
                return;
            }

            /* Normal path - build the icon key and look it up. */
            string newicon = find_mappedid(raw_id).concat(raw_suffix);
            int ic_index = get_stringindex(newicon, iconnames);

            /* check: (normal path) - unknown icon key falls back safely */
            if (ic_index < 0 || ic_index >= currimages.length) {
                warning("update_content: icon key '%s' not found; using fallback\n",
                      newicon);
                ic_index = fallback_index;
            }

            weather_image.set_from_pixbuf(currimages[ic_index]);

            int n_lines = weatherlines.length;
            string weathersection = string.joinv("\n", weatherlines[3:n_lines]);
            locationlabel.set_label(weatherlines[2].strip());
            weatherlabel.set_label(weathersection);
        }
        catch (Error e) {
            /*
             * File deleted by the applet between the monitor signal and our
             * read - this is expected on every refresh cycle.  Just wait for
             * the next signal.  We intentionally do NOT update the UI here so
             * the last good data remains visible rather than going blank.
             */
            warning("update_content: read error (file in transition): %s\n",
                  e.message);
        }
    }

    private void load_css (string css_data) {
        try {
            css_provider.load_from_data(css_data);
        }
        catch (Error e) {
            print("Error loading css\n");
        }
    }

    private void update_style() {
        // update the window if weather (file/datasrc) or settings changes
        // get/update textcolor
        css_data = get_css();
        weatherlabel.get_style_context().remove_class("label");
        locationlabel.get_style_context().remove_class("biglabel");
        load_css(css_data);
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
        string icondir = GLib.Path.build_filename(Config.WEATHERSHOW_DATADIR, "weather_icons");
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
                try {
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
                catch (Error e) {
                    print("Error loading images\n");
                }
            }
        } catch (FileError err) {
                // unlikely to occur, but:
                print("Something went wrong loading the icons\n");
        }
    }


    public static void main(string[] args) {
        Gtk.init(ref args);
        Gtk.Window win = new DesktopWeather(args[1]);
        win.set_decorated(false);
        win.show_all();
        win.destroy.connect(Gtk.main_quit);
        Gtk.main();
    }
}
