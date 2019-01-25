using Gtk;
using Gdk;
using GLib.Math;
using Json;
using Gee;

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


namespace WeatherShowFunctions {

    private GLib.Settings get_settings(string path) {
        var settings = new GLib.Settings(path);
        return settings;
    }

    private int escape_missingicon(
        string loglocation, string iconname, string[] iconnames
        ) {
        write_tofile(loglocation, "icon not found: ".concat(iconname));
        return get_stringindex("erro", iconnames);
    }

    private void write_tofile(string path, string data) {
        File datasrc = File.new_for_path(path);
        if (datasrc.query_exists ()) {
            datasrc.delete ();
        }
        var file_stream = datasrc.create (FileCreateFlags.NONE);
        var data_stream = new DataOutputStream (file_stream);
        data_stream.put_string (data);
    }

    private string get_langmatch () {
        // look up the language match from OWM, if it exists. default to EN if not
        string [] lang_names = GLib.Intl.get_language_names();
        string[] langcodes = {
            "ar", "bg", "ca", "cz", "de", "el", "en", "fa", "fi", "fr", "gl", "hr",
            "hu", "it", "ja", "kr", "la", "lt", "mk", "nl", "pl", "pt", "ro", "ru",
            "se", "sk", "sl", "es", "tr", "ua", "vi", "zh_cn", "zh_tw"
        };
        string default_lang = "en";
        foreach (string set_lang in lang_names) {
            foreach (string l in langcodes) {
                if (set_lang != "C" && (l == set_lang || l == set_lang.split("_")[0])) {
                    return l;
                }
            }
        }
        return default_lang;
    }

    private bool check_onwindow(string path) {
        string cmd_check = "pgrep -f " + path;
        string output;
        try {
            GLib.Process.spawn_command_line_sync(cmd_check, out output);
            if (output == "") {
                return false;
            }
        }
        catch (SpawnError e) {
            /* let's say it always works */
            return false;
        }
        return true;
    }

    private void close_window(string path) {
        bool win_exists = check_onwindow(path);
        if (win_exists) {
            try {
                Process.spawn_command_line_async(
                    "pkill -f ".concat(path));
            }
            catch (SpawnError e) {
                /* nothing to be done */
            }

        }
    }

    private void open_window(string path) {
        // call the set-color window
        bool win_exists = check_onwindow(path);
        if (!win_exists) {
            try {
                Process.spawn_command_line_async(path);
            }
            catch (SpawnError e) {
                /* nothing to be done */
            }
        }
    }

    private string find_mappedid (string icon_id) {

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
            {"302", "300"}, {"310", "300"}, {"312", "311"}, {"321", "314"},
            {"502", "501"}, {"503", "501"}, {"504", "501"}, {"522", "521"},
            {"531", "521"}, {"622", "621"}, {"711", "701"}, {"721", "701"},
            {"731", "701"}, {"741", "701"}, {"751", "701"}, {"761", "701"},
            {"762", "701"}
        };
        // 314 - 313 was removed from mapping on 25 january 2019.
        // It has its own icon! 321 -> 314 was added
        int lenrep = replacements.length[0];
        for (int i=0; i < lenrep; i++) {
            if (icon_id == replacements[i, 0]) {
                return replacements[i, 1];
            }
        }
        return icon_id;
    }

    private string weekday (int day) {
        // get weekday by index
        string[] days = {
            (_("Monday")), (_("Tuesday")), (_("Wednesday")), (_("Thursday")),
            (_("Friday")), (_("Saturday")), (_("Sunday"))
        };
        return days[day - 1];
    }

    private ArrayList<int> sort_timespan(HashMap<int, string> span) {
        // create a sorted key list
        var sortlist = new ArrayList<int>();
        foreach (var entry in span.entries) {
            sortlist.add(entry.key);
        }
        sortlist.sort();
        return sortlist;
    }

    private int get_stringindex (string s, string[] arr) {
        // get index of a string in an array
        for (int i=0; i < arr.length; i++) {
            if(s == arr[i]) return i;
        } return -1;
    }

    private string[] get_matches(string lookfor, string dir) {
        // find matching cities
        File datasrc = File.new_for_path(dir.concat("/cities"));
        string fixed = lookfor.down();
        try {
            var dis = new DataInputStream (datasrc.read ());
            string line;
            string[] matches = {};
            while ((line = dis.read_line (null)) != null) {
                if (line.down().contains(fixed)) {
                    matches += line;
                }
            }
            return matches;
        }
        catch (Error e) {
            /*
            * on each refresh, the file is deleted by the applet
            * just wait for next signal.
            */
            return {};
        }
    }
}


namespace WeatherShowApplet {
    private GLib.Settings ws_settings;
    private bool show_ondesktop;
    private bool dynamic_icon;
    private bool show_forecast;
    private string lang;
    private string tempunit;
    private string windunit;
    private string[] directions;
    private string key;
    private Gtk.Image indicatorIcon;
    private Gdk.Pixbuf[] iconpixbufs;
    private Gdk.Pixbuf[] iconpixbufs_large;
    private string[] iconnames;
    private string citycode;
    private Gtk.Box container;
    private Gtk.Label templabel;
    private Stack popoverstack;
    private int fc_stackindex;
    private string[] fc_stacknames;
    private Gtk.Grid[] popover_subgrids; // pages
    private Gtk.Grid popover_mastergrid; // real master
    private string default_icon;
    private string desktop_window;
    private string color_window;
    private string moduledir;
    private bool lasttime_failed;

    private string to_hrs (int t) {
        if (t < 10) {
            return "0" + t.to_string() + ":00";
        }
        return t.to_string() + ":00";
    }

    private void update_weathershow () {
        var weather_obj = new GetWeatherdata();
        WeatherShowApplet.get_weather(weather_obj);
    }

    private void get_weather (GetWeatherdata weather_obj) {
        /*
        * this is the comprehensive function to get the current weather
        * called sub sections are the forecast, which only runs if the popover
        * is set to show, and the current situation, only called if desktop
        * show is set.
        */

        // get forecast; conditional
        if (show_forecast == true) {
            // fetch forecast
            HashMap<int, string> result_forecast = weather_obj.get_forecast();
            // produce a sorted ArrayList to get sorted timestamps
            ArrayList<int> sorted_keys = WeatherShowFunctions.sort_timespan(
                result_forecast
            );
            // reset stack index
            fc_stackindex = 0;
            // here we go, recreate the subgrids
            int n_fc = 0;
            int curr_index = 0;
            Idle.add ( () => {
                // destroy existing forecast pages
                foreach (Grid gr in popover_subgrids) {
                    gr.destroy();
                }
                popoverstack.destroy();
                popover_subgrids = {};
                // create new ones
                for (int i = 0; i < 4; i++) {
                    var newpagegrid = new Gtk.Grid();
                    popover_subgrids += newpagegrid;
                }
                // recreate stack
                popoverstack = new Stack();
                popoverstack.set_transition_type(
                    Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
                );
                popoverstack.set_transition_duration(500);
                popoverstack.set_vexpand(true);
                popoverstack.set_hexpand(true);
                // make sure it exists
                Grid currgrid = popover_subgrids[0];
                foreach (int stamp in sorted_keys) {
                    // produces localtime per stamp
                    var time = new DateTime.from_unix_local(stamp);
                    string hour = to_hrs(time.get_hour());
                    string day = WeatherShowFunctions.weekday(
                        time.get_day_of_week()
                    );
                    // create one grid per four snapshots
                    currgrid = popover_subgrids[curr_index];
                    currgrid.set_column_spacing(40);
                    currgrid.attach(new Gtk.Label(""), 0, 0, 1, 1);
                    currgrid.attach(new Gtk.Label(""), 0, 10, 1, 1);
                    // initiate the image
                    var weather_image = new Gtk.Image();
                    currgrid.attach(weather_image, n_fc, 3, 1, 1);
                    // timelabel / daylabel
                    var timelabel = new Gtk.Label(hour);
                    currgrid.attach(timelabel, n_fc, 2, 1, 1);
                    var daylabel = new Gtk.Label(day);
                    currgrid.attach(daylabel, n_fc, 1, 1, 1);
                    // process the produced weather data (string), calc. icon
                    string[] labelsrc = result_forecast[stamp].split("\n");
                    string iconname = WeatherShowFunctions.find_mappedid(
                        labelsrc[0]
                        ).concat(labelsrc[1]
                    );
                    // here we need an exception handler!
                    int ic_index =  WeatherShowFunctions.get_stringindex(
                        iconname, iconnames
                    );
                    if (ic_index == -1) {
                        string loglocation = create_dirs_file(
                            ".config/budgie-extras", "icon_error"
                        );
                        ic_index = WeatherShowFunctions.escape_missingicon(
                            loglocation, iconname, iconnames
                        );
                    }
                    // add to subgrid, set snapshot icon
                    int line_index = 4;
                    foreach (string l in labelsrc[2:6]) {
                        currgrid.attach(new Label(l), n_fc, line_index, 1, 1);
                        line_index += 1;
                    }
                    weather_image.set_from_pixbuf(iconpixbufs_large[ic_index]);
                    n_fc += 1;
                    // if grid is ready, add grid to popover_subgrids (array)
                    // add to popoverstack (named from its index), set [0]
                    if (n_fc == 4) {
                        currgrid.set_column_homogeneous(true);
                        popover_subgrids += currgrid;
                        popoverstack.add_named(currgrid, "forecast" + curr_index.to_string());
                        curr_index += 1;
                        if (curr_index == 4) {
                            popover_mastergrid.attach(popoverstack, 1, 0, 1, 1);
                        }
                        popoverstack.set_visible_child_name("forecast0");
                        currgrid.show_all();
                        popover_mastergrid.show_all();
                        n_fc = 0;
                    }
                }
                return false;
            });
        }

        // get current weather; conditional
        if (show_ondesktop == true || dynamic_icon == true) {
            string result_current = weather_obj.get_current();
            // write to file only for desktop show
            if (show_ondesktop == true) {
                string username = Environment.get_user_name();
                string src = "/tmp/".concat(username, "_weatherdata");
                File datasrc = File.new_for_path(src);
                if (datasrc.query_exists ()) {
                    datasrc.delete ();
                }
                var file_stream = datasrc.create (FileCreateFlags.NONE);
                var data_stream = new DataOutputStream (file_stream);
                data_stream.put_string (result_current);
            }
        }
    }

    private string currtime() {
        // creates the timestamp for the log file
        var logtime = new DateTime.now_local();
        int hrs = logtime.get_hour();
        int mins = logtime.get_minute();
        string pre = "";
        if (mins < 10) {
            pre = "0";
        }
        return @"$hrs:$pre$mins";
    }

    public string create_dirs_file (string subpath, string filename) {
        // if needed, creates directory for logfile
        string homedir = Environment.get_home_dir();
        string fullpath = GLib.Path.build_path(
            GLib.Path.DIR_SEPARATOR_S, homedir, subpath, filename
        );
        GLib.File file = GLib.File.new_for_path(fullpath);
        try {
            file.make_directory_with_parents();
        }
        catch (Error e) {
            /* the directory exists, nothing to be done */
        }
        return GLib.Path.build_filename(fullpath, filename);
    }

    private void update_log (string wtype, string output) {
        // update log file
        string loglocation = create_dirs_file(".config/budgie-extras", "weatherlog");
        var logfile = File.new_for_path (loglocation);
        if (!logfile.query_exists ()) {
            var file_stream = logfile.create (FileCreateFlags.NONE);
        }
        var logtime = currtime();
        // read history
        string glue = "\n=\n";
        string file_contents;
        FileUtils.get_contents(loglocation, out file_contents);
        string[] records = file_contents.split(glue);
        int length = records.length;
        string[] keeprecords;
        if (length > 40) {
            keeprecords = records[length - 40:length];
        }
        else {keeprecords = records;}
        // add new record
        string log_output = wtype.concat(
            " time: ", logtime, "\n\n", output, glue
        );
        keeprecords += log_output;
        string newlog = string.joinv(glue, keeprecords);
        // delete previous version
        if (logfile.query_exists ()) {
            logfile.delete ();
        }
        var file_stream = logfile.create (FileCreateFlags.NONE);
        var data_stream = new DataOutputStream (file_stream);
        data_stream.put_string (newlog);
    }


    public class GetWeatherdata {

        private string fetch_fromsite (string wtype, string city) {
            /* fetch data from OWM */
            string website = "http://api.openweathermap.org/data/2.5/";
            string langstring = "&".concat("lang=", lang);
            string url = website.concat(
                wtype, "?id=", city, "&APPID=", key, "&", langstring
            );
            /* cup of libsoup */
            var session = new Soup.Session ();
            var message = new Soup.Message ("GET", url);
            session.send_message (message);
            string output = (string) message.response_body.flatten().data;
            update_log(wtype, output);
            // check valid input
            string forecast_ok = "cod\":\"200";
            string weather_ok = "cod\":200";

            if (
                output.contains(forecast_ok) || output.contains(weather_ok)
            ) {
                return output;
            }
            else {
                return "no data";
            }
        }

        private string check_stringvalue(Json.Object obj, string val) {
            /* check if the value exists, create the string- output if so */
            if (obj.has_member(val)) {
                return obj.get_string_member(val);
            }
            return "";
        }

        private float check_numvalue(Json.Object obj, string val) {
            /* check if the value exists, create the num- output if so */
            if (obj.has_member(val)) {
                float info = (float) obj.get_double_member(val);
                return info;
            }
            return 1000;
        }

        private HashMap get_categories(Json.Object rootobj) {
            var map = new HashMap<string, Json.Object> ();
            /* get cons. weatherdata, wind data and general data */
            map["weather"] = rootobj.get_array_member(
                "weather"
            ).get_object_element(0);
            map["wind"] = rootobj.get_object_member ("wind");
            map["main"] = rootobj.get_object_member ("main");
            map["sys"] = rootobj.get_object_member ("sys");
            return map;
        }

        private string getsnapshot (string data) {
            /*
            * single record; current situation. panel icon is updated
            * directly from within this function.
            * returned output is only used for the optionally written
            * textfile in /temp from get_weather, called by the loop in
            * Applet().
            */
            var parser = new Json.Parser ();
            parser.load_from_data(data);
            var root_object = parser.get_root ().get_object ();
            HashMap<string, Json.Object> map = get_categories(
                root_object
            );
            /* get icon id */
            string id = check_numvalue(map["weather"], "id").to_string();
            string daynight = check_stringvalue(map["weather"], "icon").to_string();
            string add_daytime = get_dayornight(daynight);
            /*
            * if (unlikely) the icon field does not exist, but the id does:
            * fallback to day version to prevent breaking
            */
            /* get cityline (exists anyway) */
            string city = check_stringvalue(root_object, "name");
            string country = check_stringvalue(map["sys"], "country");
            string citydisplay = city.concat(", ", country);
            /* get weatherline */
            string skydisplay = check_stringvalue(
                map["weather"], "description"
            );
            /* get info */
            string tempdisplay = get_temperature(map);
            string wspeeddisplay = get_windspeed(map);
            string wdirectiondisplay = get_winddirection(map);
            string humiddisplay = get_humidity(map);
            /* combined */
            string[] collected = {
                id, add_daytime, citydisplay, skydisplay, tempdisplay,
                wspeeddisplay.concat(" ", wdirectiondisplay), humiddisplay
            };
            /* optional dynamic panel icon is set from here directly */
            if (dynamic_icon == true && id != "") {
                string mapped_id = WeatherShowFunctions.find_mappedid(id);
                int icon_index = WeatherShowFunctions.get_stringindex(
                    mapped_id.concat(add_daytime) , iconnames
                );
                if (icon_index == -1) {
                    string loglocation = create_dirs_file(
                        ".config/budgie-extras", "icon_error"
                    );
                    icon_index = WeatherShowFunctions.escape_missingicon(
                        loglocation, add_daytime, iconnames
                    );
                }
                Idle.add ( () => {
                    Pixbuf pbuf = iconpixbufs[icon_index];
                    indicatorIcon.set_from_pixbuf(pbuf);
                    templabel.set_text(" " + tempdisplay + " ");
                    return false;
                  });
            }
            else {
                // set default icon!
                print("no icon\n");
            }
            string output = string.joinv("\n", collected);
            return output;
        }

        public string get_current () {
            /*
            * get "raw" data. if successful, create new data, else create
            * empty lines in the output array.
            */
            string data = fetch_fromsite("weather", citycode);
            if (data != "no data") {
                lasttime_failed = false;
                return getsnapshot(data);
            }
            else {
                lasttime_failed = true;
                return "";
            }
        }

        private string get_windspeed (
            HashMap<string, Json.Object> categories
            ) {
                /* get wind speed */
                float wspeed = check_numvalue(categories["wind"], "speed");
                string wspeeddisplay;
                if (wspeed != 1000) {
                    if (windunit == "Miles") {
                        wspeed = wspeed * (float) 2.237;
                        double rounded_wspeed = Math.round((double) wspeed);
                        wspeeddisplay = rounded_wspeed.to_string().concat(" MPH");
                    }
                    else {
                        wspeeddisplay = wspeed.to_string().concat(" m/sec");
                    }
                }
                else {
                    wspeeddisplay = "";
                }
                return wspeeddisplay;
            }

        private string get_temperature(
            HashMap<string, Json.Object> categories
        ) {
            /* get temp */
            string tempdisplay;
            float temp = check_numvalue(categories["main"], "temp");
            if (temp != 1000) {
                string dsp_unit;
                if (tempunit == "Celsius") {
                    temp = temp - (float) 273.15;
                    dsp_unit = "℃";
                }
                else {
                    temp = (temp * (float) 1.80) - (float) 459.67;
                    dsp_unit = "℉";
                }
                double rounded_temp = Math.round((double) temp);
                tempdisplay = rounded_temp.to_string().concat(dsp_unit);
            }
            else {
                tempdisplay = "";
            }
            return tempdisplay;
        }

        private string get_winddirection (
            HashMap<string, Json.Object> categories
        ) {
            /* get wind direction */
            float wdirection = check_numvalue(categories["wind"], "deg");
            string wdirectiondisplay;
            if (wdirection != 1000) {
                int iconindex = (int) Math.round(wdirection/45);
                wdirectiondisplay = directions[iconindex];
            }
            else {
                wdirectiondisplay = "";
            }
            return wdirectiondisplay;
        }

        private string get_humidity (
            HashMap<string, Json.Object> categories
        ) {
            /* get humidity */
            string humiddisplay;
            int humid = (int) check_numvalue(categories["main"], "humidity");
            if (humid != 1000) {
                humiddisplay = humid.to_string().concat("%");
            }
            else {
                humiddisplay = "";
            }
            return humiddisplay;
        }

        private HashMap getspan(string data) {
            // get the forecast
            var map = new HashMap<int, string> ();
            var parser = new Json.Parser ();
            parser.load_from_data (data);
            var root_object = parser.get_root ().get_object ();
            /* we need to parse each datasection from <list> */
            Json.Array newroot = root_object.get_array_member("list");
            /* get nodes */
            var nodes = newroot.get_elements();
            int n_snapshots = 0;
            foreach (Json.Node n in nodes) {
                var obj = n.get_object();
                HashMap<string, Json.Object> categories = get_categories(obj);
                /* get icon id */
                string id = check_numvalue(
                    categories["weather"], "id"
                ).to_string();
                string add_dn = check_stringvalue(
                    categories["weather"], "icon"
                );
                string dayornight = get_dayornight(add_dn);
                /* get timestamp */
                int timestamp = (int) obj.get_int_member("dt");
                /* get skystate */
                /* why no function? Ah, no numvalue, no editing, no unit*/
                string skydisplay = check_stringvalue(
                    categories["weather"], "description"
                );
                /* get temp */
                string temp = get_temperature(categories);
                /* get wind speed/direction */
                string wspeed = get_windspeed(categories);
                string wind = get_winddirection(categories).concat(" ", wspeed);
                /* get humidity */
                string humidity = get_humidity(categories);
                /* now combine the first 16 into a HashMap timestamp (int) /snapshot (str) */
                map[timestamp] = string.joinv(
                    "\n", {id, dayornight, skydisplay, temp, wind, humidity}
                );
                n_snapshots += 1;
                if (n_snapshots == 16) {
                    break;
                }
            }
            return map;
        }

        public HashMap get_forecast() {
            /* here we create a hashmap<time, string> */
            string data = fetch_fromsite("forecast", citycode);
            var map = new HashMap<int, string> ();
            if (data != "no data") {
                map = getspan(data);
                lasttime_failed = false;
            }
            else {
                lasttime_failed = true;
            }
            return map;
        }

        private string get_dayornight (string dn) {
            /* get the last char of the icon id, to set day/night icon*/
            if (dn != "") {
                int len = dn.length;
                return dn[len - 1 : len];
            }
            return "d";
        }
    }


    public class WeatherShowSettings : Gtk.Grid {

        /* Budgie Settings -section */
        private CheckButton[] cbuttons;
        private string[] add_args;
        private string css_template;
        private string css_data2;
        private Gtk.Scale transparency_slider;
        private Gtk.Button weathercbutton;
        private Gtk.Label colorlabel;
        private Gtk.CheckButton setposbutton;
        private Gtk.Entry xpos;
        private Gtk.Entry ypos;
        private Gtk.Label xpos_label;
        private Gtk.Label ypos_label;
        private Gtk.Button apply;
        private Gtk.Label transparency_label;
        private Stack stack;
        private Gtk.Button button_desktop;
        private Gtk.Button button_general;
        private Label currmarker_label1;
        private Label currmarker_label2;
        private Gtk.CssProvider css_provider;
        private Gtk.Entry cityentry;
        private Gtk.Menu citymenu;
        private Gdk.Screen screen;
        private MenuButton search_button;
        private string[] city_menurefs;
        private string[] city_menucodes;
        private bool edit_citymenu;

        public WeatherShowSettings(GLib.Settings? settings) {
            // css
            css_template = """
            .weathercbutton {
              border-color: transparent;
              background-color: rgb(xxx, xxx, xxx);
              padding: 0px;
              border-width: 1px;
              border-radius: 4px;
            }
            .activebutton {
            }
            """;

            // settings stack/pages
            stack = new Stack();
            stack.set_transition_type(
                Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
            );
            stack.set_vexpand(true);
            stack.set_hexpand(true);
            this.attach(stack, 0, 10, 2, 1);
            var header_space = new Gtk.Label("\n");
            this.attach(header_space, 0, 2, 1, 1);
            button_general = new Button.with_label((_("General")));
            button_general.clicked.connect(on_button_general_clicked);
            button_general.set_size_request(100, 20);
            this.attach(button_general, 0, 0, 1, 1);
            currmarker_label1 = new Gtk.Label("⸻");
            this.attach(currmarker_label1, 0, 1, 1, 1);
            button_desktop = new Button.with_label((_("Desktop")));
            button_desktop.clicked.connect(on_button_desktop_clicked);
            button_desktop.set_size_request(100, 20);
            this.attach(button_desktop, 1, 0, 1, 1);
            currmarker_label2 = new Gtk.Label("");
            this.attach(currmarker_label2, 1, 1, 1, 1);
            var subgrid_general = new Grid();
            stack.add_named(subgrid_general, "Page1");
            var subgrid_desktop = new Grid();
            stack.add_named(subgrid_desktop, "Page2");
            // set city section
            edit_citymenu = true;
            var citylabel = new Label((_("City")));
            citylabel.set_xalign(0);
            subgrid_general.attach(citylabel, 0, 0, 1, 1);
            var citybox = new Box(Gtk.Orientation.HORIZONTAL, 0);
            subgrid_general.attach(citybox, 0, 1, 1, 1);
            cityentry = new Entry();
            string initialcity = set_initialcity();
            cityentry.set_text(initialcity);
            cityentry.changed.connect(update_citylist);
            citybox.pack_start(cityentry, false, false, 0);
            search_button = new MenuButton();
            var searchicon = new Gtk.Image.from_icon_name(
                "system-search-symbolic", Gtk.IconSize.DND);
            search_button.set_image(searchicon);
            citybox.pack_end(search_button, false, false, 0);
            citymenu = new Gtk.Menu();
            var spacelabel1 = new Gtk.Label("");
            subgrid_general.attach(spacelabel1, 0, 2, 1, 1);
            // set language
            var spacelabel2 = new Gtk.Label("");
            subgrid_general.attach(spacelabel2, 0, 5, 1, 1);
            // show on desktop
            var ondesktop_checkbox = new CheckButton.with_label(
                (_("Show on desktop"))
            );
            subgrid_general.attach(ondesktop_checkbox, 0, 10, 1, 1);
            ondesktop_checkbox.set_active(show_ondesktop);
            ondesktop_checkbox.toggled.connect(toggle_value);
            // dynamic icon
            var dynamicicon_checkbox = new CheckButton.with_label(
                (_("Show dynamic panel icon"))
            );
            subgrid_general.attach(dynamicicon_checkbox, 0, 11, 1, 1);
            dynamicicon_checkbox.set_active(dynamic_icon);
            dynamicicon_checkbox.toggled.connect(toggle_value);
            // forecast
            var forecast_checkbox = new CheckButton.with_label(
                (_("Show forecast in popover"))
            );
            subgrid_general.attach(forecast_checkbox, 0, 12, 1, 1);
            forecast_checkbox.set_active(show_forecast);
            forecast_checkbox.toggled.connect(toggle_value);
            var spacelabel3 = new Gtk.Label("");
            subgrid_general.attach(spacelabel3, 0, 13, 1, 1);
            // temp unit
            var tempunit_checkbox = new CheckButton.with_label("Fahrenheit");
            subgrid_general.attach(tempunit_checkbox, 0, 14, 1, 1);
            tempunit_checkbox.set_active(get_tempstate());
            tempunit_checkbox.toggled.connect(set_tempunit);
            // wind unit
            var windunit_checkbox = new CheckButton.with_label("Wind speed in MPH");
            subgrid_general.attach(windunit_checkbox, 0, 15, 1, 1);
            windunit_checkbox.set_active(get_windstate());
            windunit_checkbox.toggled.connect(set_windunit);
            var spacelabel5 = new Gtk.Label("");
            subgrid_general.attach(spacelabel5, 0, 17, 1, 1);
            // optional settings: show on desktop
            transparency_label = new Gtk.Label(
                (_("Transparency"))
            );
            transparency_label.set_xalign(0);
            subgrid_desktop.attach(transparency_label, 0, 22, 1, 1);

            transparency_slider = new Gtk.Scale.with_range(
                Gtk.Orientation.HORIZONTAL, 0, 100, 5
            );
            set_initialtransparency();
            subgrid_desktop.attach(transparency_slider, 0, 23, 1, 1);
            transparency_slider.value_changed.connect(
                update_transparencysettings
            );
            var spacelabel6 = new Gtk.Label("\n");
            subgrid_desktop.attach(spacelabel6, 0, 24, 1, 1);
            // text color
            var colorbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            subgrid_desktop.attach(colorbox, 0, 30, 1, 1);
            weathercbutton = new Gtk.Button();
            set_buttoncolor();
            weathercbutton.set_size_request(10, 10);
            // call set-color window
            weathercbutton.clicked.connect( () => {
                WeatherShowFunctions.open_window(color_window);
            });
            colorbox.pack_start(weathercbutton, false, false, 0);
            colorlabel = new Gtk.Label("\t" + (_("Set text color")));
            colorlabel.set_xalign(0);
            colorbox.pack_start(colorlabel, false, false, 0);
            var spacelabel7 = new Gtk.Label("\n");
            subgrid_desktop.attach(spacelabel7, 0, 31, 1, 1);
            // checkbox custom position
            setposbutton = new Gtk.CheckButton.with_label(
                (_("Set custom position (px)"))
            );
            subgrid_desktop.attach(setposbutton, 0, 50, 1, 1);
            setposbutton.toggled.connect(toggle_value);
            var posholder = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            xpos = new Gtk.Entry();
            xpos.set_width_chars(4);
            xpos_label = new Gtk.Label("x: ");
            ypos = new Gtk.Entry();
            ypos.set_width_chars(4);
            ypos_label = new Gtk.Label(" y: ");
            posholder.pack_start(xpos_label, false, false, 0);
            posholder.pack_start(xpos, false, false, 0);
            posholder.pack_start(ypos_label, false, false, 0);
            posholder.pack_start(ypos, false, false, 0);
            // wrap it up
            apply = new Gtk.Button.with_label("OK");
            apply.clicked.connect(update_xysetting);
            posholder.pack_end(apply, false, false, 0);
            subgrid_desktop.attach(posholder, 0, 51, 1, 1);
            button_desktop.set_sensitive(show_ondesktop);
            cbuttons = {
                ondesktop_checkbox, dynamicicon_checkbox,
                forecast_checkbox, setposbutton
            };
            add_args = {
                "desktopweather", "dynamicicon", "forecast",
                ""
            };
            set_initialpos();
            // update button color on gsettings change
            set_buttoncolor();
            ws_settings.changed["textcolor"].connect (() => {
                set_buttoncolor();
            });
            this.show_all();
        }

        private string set_initialcity() {
            // on opening settings, set the gui to the current value
            string initial_citycode = citycode;
            string[] initline = WeatherShowFunctions.get_matches(
                initial_citycode, moduledir
            );
            // fix for change of cityfile (!)
            if (initline.length == 0) {
                citycode = "2643743";
                return "London, GB";
            }
            return initline[0].split(" ", 2)[1];
        }

        private void set_initialpos () {
            int set_xpos = ws_settings.get_int("xposition");
            int set_ypos = ws_settings.get_int("yposition");
            bool currcustom;
            if (set_xpos != 200 || set_ypos != 200){
                currcustom = true;
                xpos.set_text(set_xpos.to_string());
                ypos.set_text(set_ypos.to_string());
            }
            else {
                currcustom = false;
            }
            setposbutton.set_active(currcustom);
            xpos.set_sensitive(currcustom);
            ypos.set_sensitive(currcustom);
            apply.set_sensitive(currcustom);
            xpos_label.set_sensitive(currcustom);
            ypos_label.set_sensitive(currcustom);
        }

        private void update_xysetting (Button button) {
            string newxpos_str = xpos.get_text();
            int newx = int.parse(newxpos_str);
            string newypos_str = ypos.get_text();
            int newy = int.parse(newypos_str);
            if (newx != 0 && newy != 0) {
                ws_settings.set_int("xposition", newx);
                ws_settings.set_int("yposition", newy);
            }
            else {
                print("incorrect input: no integer");
            }
        }

        private void update_citysettings (Gtk.MenuItem m) {
            string newselect = m.get_label();
            int index = WeatherShowFunctions.get_stringindex(
                newselect, city_menurefs
            );
            string newcode = city_menucodes[index];
            ws_settings.set_string("citycode", newcode);
            edit_citymenu = false;
            cityentry.set_text(newselect);
            edit_citymenu = true;
            update_weathershow();
        }

        private void update_transparencysettings(Gtk.Range slider) {
            int newval = (int) slider.get_value();
            ws_settings.set_int("transparency", newval);
        }

        private void set_initialtransparency() {
            // on opening settings, set the gui to the current value
            int intialsetting = ws_settings.get_int("transparency");
            transparency_slider.set_value(intialsetting);
        }

        private void update_citylist(Gtk.Editable entry) {
            // on user edit of the lang entry, update the matches & menu
            city_menurefs = {};
            city_menucodes = {};
            string currentry = cityentry.get_text();
            citymenu.destroy();
            citymenu = new Gtk.Menu();
            if (
                currentry.char_count() > 2 &&
                edit_citymenu == true &&
                entry != null
                ) {
                string[] matches = WeatherShowFunctions.get_matches(
                    currentry, moduledir
                );
                int n_matches = matches.length;
                if (n_matches > 0) {
                    foreach (string s in matches) {
                        string[] new_ref = s.split(" ", 2);
                        string newref = new_ref[1];
                        var newitem = new Gtk.MenuItem.with_label(newref);
                        city_menurefs += newref;
                        city_menucodes += new_ref[0];
                        newitem.activate.connect(update_citysettings);
                        citymenu.add(newitem);
                    }
                }
                else {
                    var newitem = new Gtk.MenuItem.with_label(
                        "No matches found"
                    );
                    citymenu.add(newitem);
                }
            }
            else {
                var newitem = new Gtk.MenuItem.with_label(
                    (_("Please enter at least 3 characters"))
                );
                citymenu.add(newitem);
            }
            citymenu.show_all();
            search_button.set_popup(citymenu);
        }

        private void set_buttoncolor() {
            // set / update color button color
            screen = weathercbutton.get_screen();
            css_provider = new Gtk.CssProvider();


            string[] readcolor = ws_settings.get_strv("textcolor");
            string newcsscolor = string.joinv(", ", readcolor);
            css_data2 = css_template.replace("xxx, xxx, xxx", newcsscolor);
            weathercbutton.get_style_context().remove_class("weathercbutton");
            css_provider.load_from_data(css_data2);
            Gtk.StyleContext.add_provider_for_screen(
                screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
            );
            weathercbutton.get_style_context().add_class("weathercbutton");
            this.show_all();
        }

        private void on_button_general_clicked (Button button) {
            // update page underline
            stack.set_visible_child_name("Page1");
            currmarker_label1.set_text("⸻");
            currmarker_label2.set_text("");
        }

        private void on_button_desktop_clicked(Button button) {
            // update page underline
            stack.set_visible_child_name("Page2");
            currmarker_label2.set_text("⸻");
            currmarker_label1.set_text("");
        }

        private int get_buttonarg (ToggleButton button) {
            // fetch the additional arg from button / args arrays
            for (int i = 0; i < cbuttons.length; i++) {
                if (cbuttons[i] == button) {
                    return i;
                }
            } return -1;
        }

        private bool get_tempstate () {
            return (
                tempunit == "Fahrenheit"
            );
        }

        private bool get_windstate () {
            return (
                windunit == "Miles"
            );
        }

        private void set_tempunit (ToggleButton button) {
            // update gsettings
            bool newsetting = button.get_active();
            if (newsetting == true) {
                tempunit = "Fahrenheit";
            }
            else {
                tempunit = "Celsius";
            }
            update_weathershow();
            ws_settings.set_string("tempunit", tempunit);
        }

        private void set_windunit (ToggleButton button) {
            // update gsettings
            bool newsetting = button.get_active();
            if (newsetting == true) {
                windunit = "Miles";
            }
            else {
                windunit = "Meters";
            }
            update_weathershow();
            ws_settings.set_string("windunit", windunit);
        }

        private void toggle_value(ToggleButton button) {
            // generic toggle actions function
            bool newsetting = button.get_active();
            int val_index = get_buttonarg(button);
            string currsetting = add_args[val_index];
            /*
            * ok, not a beauty-queen, but a patch to prevent an extra
            * function:
            */
            if (val_index != 3) {
                ws_settings.set_boolean(currsetting, newsetting);
            }
            // possible additional actions, depending on the togglebutton
            if (val_index == 0) {
                button_desktop.set_sensitive(newsetting);
                if (newsetting == true) {
                    WeatherShowFunctions.open_window(desktop_window);
                }
            }
            else if (val_index == 3) {
                // ugly sumnation, but the alternative is more verbose
                xpos_label.set_sensitive(newsetting);
                ypos_label.set_sensitive(newsetting);
                xpos.set_sensitive(newsetting);
                ypos.set_sensitive(newsetting);
                apply.set_sensitive(newsetting);
                if (newsetting == false) {
                    xpos.set_text("");
                    ypos.set_text("");
                    ws_settings.set_int("xposition", 200);
                    ws_settings.set_int("yposition", 200);
                }
            }

            else if (val_index == 1 && newsetting == false) {
                indicatorIcon.set_from_icon_name(
                    default_icon, Gtk.IconSize.MENU
                );
                templabel.set_text("");
            }
            update_weathershow();
        }
    }


    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget(string uuid) {
            var info = this.get_plugin_info();
            moduledir = info.get_module_dir();
            return new Applet();
        }
    }


    public class WeatherShowPopover : Budgie.Popover {

        private Gtk.EventBox indicatorBox;

        public WeatherShowPopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);
            this.indicatorBox = indicatorBox;
            // set default (initial) icon
            indicatorIcon = new Gtk.Image();
            indicatorIcon.set_from_icon_name(
                default_icon, Gtk.IconSize.MENU
            );
            templabel = new Label("");
            container.pack_start(indicatorIcon, false, false, 0);
            container.pack_end(templabel, false, false, 0);
            // build up the popover to contain the pages,
            // created in get_weather
            popover_mastergrid = new Gtk.Grid();
            popover_mastergrid.set_column_spacing(30);
            // left button
            var leftbox = new Box(Gtk.Orientation.VERTICAL, 0);
            var browseleft = new Button.from_icon_name (
                "go-previous-symbolic", IconSize.BUTTON
            );
            browseleft.set_size_request(10, 10);
            browseleft.set_relief(Gtk.ReliefStyle.NONE);
            browseleft.clicked.connect(previous_stack);
            leftbox.pack_end (browseleft, false, false, 0);
            // right button
            var rightbox = new Box(Gtk.Orientation.VERTICAL, 0);
            var browseright = new Button.from_icon_name (
                "go-next-symbolic", IconSize.BUTTON
            );
            browseright.set_size_request(10, 10);
            browseright.set_relief(Gtk.ReliefStyle.NONE);
            browseright.clicked.connect(next_stack);
            rightbox.pack_end (browseright, false, false, 0);

            popover_mastergrid.attach(leftbox, 0, 0, 1, 1);
            popover_mastergrid.attach(rightbox, 2, 0, 1, 1);

            this.add(popover_mastergrid);
        }

        private void next_stack(Button button) {
            if (fc_stackindex != 3) {
                int newindex = fc_stackindex + 1;
                popoverstack.set_visible_child_name(fc_stacknames[newindex]);
                fc_stackindex = newindex;
            }
        }

        private void previous_stack(Button button) {
            if (fc_stackindex != 0) {
                int newindex = fc_stackindex - 1;
                popoverstack.set_visible_child_name(fc_stacknames[newindex]);
                fc_stackindex = newindex;
            }
        }
    }


    public class Applet : Budgie.Applet {

        private Gtk.EventBox indicatorBox;
        private WeatherShowPopover popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        public string uuid { public set; public get; }
        Thread<bool> update_thread;


        public override bool supports_settings() {
            return true;
        }

        public override Gtk.Widget? get_settings_ui() {
            return new WeatherShowSettings(this.get_applet_settings(uuid));
        }

        public Applet() {

            desktop_window = moduledir.concat("/desktop_weather");
            color_window = moduledir.concat("/get_color");

            // arrows, for wind string
            directions = {"↓", "↙", "←", "↖", "↑", "↗", "→", "↘", "↓"};
            fc_stacknames = {
                "forecast0", "forecast1", "forecast2", "forecast3"
            };
            // list icons from the applet's directory
            get_icondata();
            default_icon = "budgie-wticon-symbolic";
            // get current settings, connect to possible changes
            ws_settings = WeatherShowFunctions.get_settings(
                "org.ubuntubudgie.plugins.weathershow"
            );
            tempunit = ws_settings.get_string("tempunit");
            ws_settings.changed["tempunit"].connect (() => {
                tempunit = ws_settings.get_string("tempunit");
            });
            windunit = ws_settings.get_string("windunit");
            ws_settings.changed["windunit"].connect (() => {
                windunit = ws_settings.get_string("windunit");
            });
            lang = WeatherShowFunctions.get_langmatch();
            key = ws_settings.get_string("key");
            show_ondesktop = ws_settings.get_boolean("desktopweather");
            ws_settings.changed["desktopweather"].connect (() => {
                show_ondesktop = ws_settings.get_boolean("desktopweather");
            });

            citycode = ws_settings.get_string("citycode");
            ws_settings.changed["citycode"].connect (() => {
                citycode = ws_settings.get_string("citycode");
            });
            dynamic_icon = ws_settings.get_boolean("dynamicicon");
            ws_settings.changed["dynamicicon"].connect (() => {
                dynamic_icon = ws_settings.get_boolean("dynamicicon");
            });
            show_forecast = ws_settings.get_boolean("forecast");
            ws_settings.changed["forecast"].connect (() => {
                show_forecast = ws_settings.get_boolean("forecast");
            });

            if (show_ondesktop == true) {
                WeatherShowFunctions.open_window(desktop_window);
            }

            initialiseLocaleLanguageSupport();
            // box
            indicatorBox = new Gtk.EventBox();
            container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            indicatorBox.add(container);
            add(indicatorBox);
            // Popover
            popover = new WeatherShowPopover(indicatorBox);
            // On Press indicatorBox
            indicatorBox.button_press_event.connect((e)=> {
                // only popu if settings say so
                if (show_forecast == true) {
                    if (e.button != 1) {
                        return Gdk.EVENT_PROPAGATE;
                    }
                    if (popover.get_visible()) {
                        popover.hide();
                    } else {
                        this.manager.show_popover(indicatorBox);
                    }
                    return Gdk.EVENT_STOP;
                }
                return false;
            });
            popover.get_child().show_all();
            show_all();
            // start immediately
            update_weathershow();
            update_thread = new Thread<bool>.try ("oldtimer", run_periodiccheck);
        }

        private bool run_periodiccheck () {
            var currtime1 = new DateTime.now_utc();
            while (true) {
                var currtime2 = new DateTime.now_utc();
                var diff = currtime2.difference(currtime1);
                // refresh if last update was more than 10 minutes ago
                if (diff > 600000000 || lasttime_failed == true) {
                    update_weathershow();
                    currtime1 = currtime2;
                }
                if (!check_onapplet(
                    "/com/solus-project/budgie-panel/applets/",
                    "WeatherShow"
                )) {
                    WeatherShowFunctions.close_window(desktop_window);
                    update_thread.exit(true);
                }
                Thread.usleep(15 * 1000000);
            }
        }

        private bool check_onapplet(string path, string applet_name) {
            // check if the applet still runs
            string cmd = "dconf dump " + path;
            string output;
            try {
                GLib.Process.spawn_command_line_sync(cmd, out output);
            }
            // on an occasional exception, don't break the loop
            catch (SpawnError e) {
                return true;
            }
            bool check = output.contains(applet_name);
            return check;
        }

        private void get_icondata () {
            // fetch the icon list
            string icondir = moduledir.concat("/weather_icons");
            iconnames = {}; iconpixbufs = {}; iconpixbufs_large = {};
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
                    iconpixbufs += new Pixbuf.from_file_at_size (
                        iconpath, 22, 22
                    );
                    iconpixbufs_large += new Pixbuf.from_file_at_size (
                        iconpath, 65, 65
                    );
                }
            } catch (FileError err) {
                    // unlikely to occur, but:
                    print("Something went wrong loading the icons");
            }
        }

        public override void update_popovers(Budgie.PopoverManager? manager) {
            this.manager = manager;
            manager.register_popover(indicatorBox, popover);
        }

        public void initialiseLocaleLanguageSupport() {
            // Initialize gettext
            GLib.Intl.setlocale(GLib.LocaleCategory.ALL, "");
            GLib.Intl.bindtextdomain(
                Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR
            );
            GLib.Intl.bind_textdomain_codeset(
                Config.GETTEXT_PACKAGE, "UTF-8"
            );
            GLib.Intl.textdomain(Config.GETTEXT_PACKAGE);
        }
    }
}


[ModuleInit]
public void peas_register_types(TypeModule module){
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(
        typeof(
        Budgie.Plugin
        ), typeof(
            WeatherShowApplet.Plugin
            )
    );
}
