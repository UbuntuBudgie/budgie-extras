/*
 * This file is part of budgie-extras
 *
 * Copyright © 2019 Ubuntu Budgie Developers
 * Author: Adam Dyess
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

public class FuzzyClockPlugin : Budgie.Plugin, Peas.ExtensionBase
{
    public Budgie.Applet get_panel_widget(string uuid)
    {
        return new FuzzyClockApplet(uuid);
    }
}

enum ClockFormat {
    TWENTYFOUR = 0,
    TWELVE = 1;
}

public const string CALENDAR_MIME = "text/calendar";

public class FuzzyClockRule
{
    protected const string back_hour = "-1";
    protected const string fwd_hour = "+1";
    public string format = "";
    public int hour_offset = 0;
    /**
     * Format string rules
     *      one for each of 12 text formats
     */
    public FuzzyClockRule(string rule_text, int hour_offset)
    {
        this.format = rule_text.replace(fwd_hour, "").replace(back_hour, "");
        this.hour_offset = hour_offset;
        if (rule_text.contains(fwd_hour)) {
            this.hour_offset = hour_offset + 1;
        }
        else if (rule_text.contains(back_hour)) {
            this.hour_offset = hour_offset - 1;
        }
    }
}

public class FuzzyClockApplet : Budgie.Applet
{
    public string uuid { public set; public get; }
    GLib.Settings? panel_settings;
    GLib.Settings? currpanelsubject_settings;
    bool fuzzy_onpanel = true;

    string general_path = "com.solus-project.budgie-panel";

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
        string[] applets;
        panel_settings = new GLib.Settings(general_path);
        string[] allpanels_list = panel_settings.get_strv("panels");
        foreach (string p in allpanels_list) {
            string panelpath = "/com/solus-project/budgie-panel/panels/".concat("{", p, "}/");
            currpanelsubject_settings = new GLib.Settings.with_path(
                general_path + ".panel", panelpath
            );

            applets = currpanelsubject_settings.get_strv("applets");
            if (find_applet(uuid, applets)) {
                currpanelsubject_settings.changed["applets"].connect(() => {
                    applets = currpanelsubject_settings.get_strv("applets");
                    if (!find_applet(uuid, applets)) {
                        fuzzy_onpanel = false;
                    }
                });
                break;
            }
        }
    }

    string date_format = "";

    protected string[] hours = {
        // TRANSLATORS: This is referring to the spoken time of day at 00:00:00
        _("midnight"),

        // TRANSLATORS: This is referring to the spoken time of day at 01:00:00
        _("one"),

        // TRANSLATORS: This is referring to the spoken time of day at 02:00:00
        _("two"),

        // TRANSLATORS: This is referring to the spoken time of day at 03:00:00
        _("three"),

        // TRANSLATORS: This is referring to the spoken time of day at 04:00:00
        _("four"),

        // TRANSLATORS: This is referring to the spoken time of day at 05:00:00
        _("five"),

        // TRANSLATORS: This is referring to the spoken time of day at 06:00:00
        _("six"),

        // TRANSLATORS: This is referring to the spoken time of day at 07:00:00
        _("seven"),

        // TRANSLATORS: This is referring to the spoken time of day at 08:00:00
        _("eight"),

        // TRANSLATORS: This is referring to the spoken time of day at 09:00:00
        _("nine"),

        // TRANSLATORS: This is referring to the spoken time of day at 10:00:00
        _("ten"),

        // TRANSLATORS: This is referring to the spoken time of day at 11:00:00
        _("eleven"),

        // TRANSLATORS: This is referring to the spoken time of day at 12:00:00
        _("noon"),

        // TRANSLATORS: This is referring to the spoken time of day at 13:00:00
        _("one"),

        // TRANSLATORS: This is referring to the spoken time of day at 14:00:00
        _("two"),

        // TRANSLATORS: This is referring to the spoken time of day at 15:00:00
        _("three"),

        // TRANSLATORS: This is referring to the spoken time of day at 16:00:00
        _("four"),

        // TRANSLATORS: This is referring to the spoken time of day at 17:00:00
        _("five"),

        // TRANSLATORS: This is referring to the spoken time of day at 18:00:00
        _("six"),

        // TRANSLATORS: This is referring to the spoken time of day at 19:00:00
        _("seven"),

        // TRANSLATORS: This is referring to the spoken time of day at 20:00:00
        _("eight"),

        // TRANSLATORS: This is referring to the spoken time of day at 21:00:00
        _("nine"),

        // TRANSLATORS: This is referring to the spoken time of day at 22:00:00
        _("ten"),

        // TRANSLATORS: This is referring to the spoken time of day at 23:00:00
        _("eleven"),
    };

    // TRANSLATORS: These format strings reference the above hour strings
    //              This is the fun part of fuzzy-clock, feel free to
    //              be inventive within your language
    // the format rules are divided into 12 buckets
    // each bucket contains a rule for displaying the time within an hour
    // This presents a problem for some languages, where it is more natural
    // to reference the future hour numeral
    // English Example:
    //       "quarter after one"  --> "1:15"
    //       "half-past one"      --> "1:30"
    //       "quarter til two"    --> "2:45"
    //  To satisfy the need for a languages there is an addition hour each rule can include a 'forward-hour offset'
    //  the english is provided as the default, but any language can change the offset to fit
    //  by using "<language-text> %s+1" to indicate this rule needs use a forward hour

    protected FuzzyClockRule[] rules = {
        // TRANSLATORS: times between (12:58:00 - 1:02:00) are 'one-ish'
        new FuzzyClockRule(_("%s-ish"), 0),

        // TRANSLATORS: times between (1:03:00 - 1:07:00) are 'a bit past one'
        new FuzzyClockRule(_("a bit past %s"), 0),

        // TRANSLATORS: times between (1:08:00 - 1:12:00) are 'ten past one'
        new FuzzyClockRule(_("ten past %s"), 0),

        // TRANSLATORS: times between (1:13:00 - 1:17:00) are 'quarter after one'
        new FuzzyClockRule(_("quarter after %s"), 0),

        // TRANSLATORS: times between (1:18:00 - 1:22:00) are 'twenty past one'
        // by adding the characters +1 you can add one hour to the current hour i.e. 'twenty past two'
        // by adding the characters -1 you can subtract one hour from the current hour i.e. 'twenty past twelve'
        new FuzzyClockRule(_("twenty past %s"), 0),

        // TRANSLATORS: times between (1:23:00 - 1:27:00) are 'almost half-past one'
        // by adding the characters +1 you can add one hour to the current hour i.e. 'almost half-past two'
        // by adding the characters -1 you can subtract one hour from the current hour i.e. 'almost half-past twelve'
        new FuzzyClockRule(_("almost half-past %s"), 0),

        // TRANSLATORS: times between (1:28:00 - 1:32:00) are 'half-past one'
        // by adding the characters +1 you can add one hour to the current hour i.e. 'half-past two'
        // by adding the characters -1 you can subtract one hour from the current hour i.e. 'half-past twelve'
        new FuzzyClockRule(_("half-past %s"), 0),

        // TRANSLATORS: times between (1:33:00 - 1:37:00) are 'twenty-five 'til two'
        // by adding the characters +1 you can add a further hour i.e. 'til three'
        // by adding the characters -1 you can subtract one hour i.e. 'til one'
        new FuzzyClockRule(_("twenty-five 'til %s"), 1),

        // TRANSLATORS: times between (1:38:00 - 1:42:00) are 'twenty 'til two'
        // by adding the characters +1 you can add a further hour i.e. 'til three'
        // by adding the characters -1 you can subtract one hour i.e. 'til one'
        new FuzzyClockRule(_("twenty 'til %s"), 1),

        // TRANSLATORS: times between (1:43:00 - 1:47:00) are 'quarter 'til two'
        // by adding the characters +1 you can add a further hour i.e. 'til three'
        // by adding the characters -1 you can subtract one hour i.e. 'til one'
        new FuzzyClockRule(_("quarter 'til %s"), 1),

        // TRANSLATORS: times between (1:48:00 - 1:52:00) are 'ten 'til two'
        // by adding the characters +1 you can add a further hour i.e. 'til three'
        // by adding the characters -1 you can subtract one hour i.e. 'til one'
        new FuzzyClockRule(_("ten 'til %s"), 1),

        // TRANSLATORS: times between (1:53:00 - 1:57:00) are 'almost two'
        // by adding the characters +1 you can add a further hour i.e. 'almost three'
        // by adding the characters -1 you can subtract one hour i.e. 'almost one'
        new FuzzyClockRule(_("almost %s"), 1),
    };

    protected Gtk.EventBox widget;
    protected Gtk.Box layout;
    protected Gtk.Label clock;
    protected Gtk.Label date_label;

    protected bool ampm = false;

    private DateTime time;

    protected Settings settings;

    Budgie.Popover? popover = null;
    AppInfo? calprov = null;
    Gtk.Button cal_button;
    Gtk.CheckButton clock_format;
    Gtk.CheckButton check_date;
    ulong check_id;

    Gtk.Orientation orient = Gtk.Orientation.HORIZONTAL;

    private unowned Budgie.PopoverManager? manager = null;

    /**
     * Helper to create fancy button with a direction indicator
     */
    Gtk.Button new_directional_button(string label_str, Gtk.PositionType arrow_direction)
    {
        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        box.halign = Gtk.Align.FILL;
        var label = new Gtk.Label(label_str);
        var button = new Gtk.Button();
        var image = new Gtk.Image();

        if (arrow_direction == Gtk.PositionType.RIGHT) {
            image.set_from_icon_name("go-next-symbolic", Gtk.IconSize.MENU);
            box.pack_start(label, true, true, 0);
            box.pack_end(image, false, false, 1);
            image.margin_start = 6;
            label.margin_start = 6;
        } else {
            image.set_from_icon_name("go-previous-symbolic", Gtk.IconSize.MENU);
            box.pack_start(image, false, false, 0);
            box.pack_start(label, true, true, 0);
            image.margin_end = 6;
        }

        label.halign = Gtk.Align.START;
        label.margin = 0;
        box.margin = 0;
        box.border_width = 0;
        button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
        button.add(box);
        return button;
    }

    /**
     * Helper to create new dropdown buttons
     */
    Gtk.Button new_plain_button(string label_str)
    {
        Gtk.Button ret = new Gtk.Button.with_label(label_str);
        ret.get_child().halign = Gtk.Align.START;
        ret.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

        return ret;
    }

    /**
     * Updates the orientation if the panel changes positions
     */
    public override void panel_position_changed(Budgie.PanelPosition position)
    {
        if (position == Budgie.PanelPosition.LEFT || position == Budgie.PanelPosition.RIGHT) {
            this.orient = Gtk.Orientation.VERTICAL;
            if (position == Budgie.PanelPosition.RIGHT) {
                clock.set_angle(270);
                date_label.set_angle(270);
            }
            else {
                clock.set_angle(90);
                date_label.set_angle(90);
            }
        } else {
            this.orient = Gtk.Orientation.HORIZONTAL;
            clock.set_angle(0);
            date_label.set_angle(0);
        }
        this.layout.set_orientation(this.orient);
        this.update_clock();
    }

    // get index of string in list
    private int get_containingindex (string[] arr, string lookfor) {
        for (int i=0; i < arr.length; i++) {
            if(lookfor.contains(arr[i])) return i;
        }
        return -1;
    }

    /**
     * Taken from showtime - calculate the locale dateformat
     */
    private string read_dateformat () {
        string[] monthvars = {
            "%B", "%-b", "%_b", "%h", "%-h", "%_h", "%b"
        };
        string[] daynamevars = {
            "%A", "%a", "%-a", "%-A", "%_a", "%_A"
        };
        string[] monthdayvars = {
            "%e", "%-e", "%_e", "%d", "%-d", "%_d"
        };
        string cmd = "locale date_fmt";
        string output = "";
        try {
            StringBuilder builder = new StringBuilder ();
            GLib.Process.spawn_command_line_sync(cmd, out output);
            string[] output_data = output.split(" ");
            foreach (string s in output_data) {
                // make it a function? nah, we're lazy
                if (get_containingindex(monthvars, s) != -1) {
                    builder.append (monthvars[0]).append (" ");
                }
                else if (get_containingindex(daynamevars, s) != -1) {
                    builder.append (daynamevars[0]).append (" ");
                }
                else if (get_containingindex(monthdayvars, s) != -1) {
                    builder.append (monthdayvars[0]).append (" ");
                }
            }
            return builder.str;
        }
        catch (Error e) {
            return "";
        }
    }

    /**
     * Main initialization of the Applet
     */
    public FuzzyClockApplet(string uuid)
    {

        GLib.Timeout.add_seconds(1, ()=> {
            watchapplet(uuid);
            return false;
        });


        initialiseLocaleLanguageSupport();
        widget = new Gtk.EventBox();
        layout = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);

        clock = new Gtk.Label("");
        time = new DateTime.now_local();
        widget.add(layout);

        layout.pack_start(clock, false, false, 0);
        layout.margin = 0;
        layout.border_width = 0;

        date_label = new Gtk.Label("");
        layout.pack_start(date_label, false, false, 0);
        date_label.no_show_all = true;
        date_label.hide();

        date_format = read_dateformat();

        clock.valign = Gtk.Align.CENTER;
        date_label.valign = Gtk.Align.CENTER;

        settings = new Settings("org.gnome.desktop.interface");

        get_style_context().add_class("budgie-fuzzy-clock-applet");

        // Create a submenu system
        popover = new Budgie.Popover(widget);

        var stack = new Gtk.Stack();
        stack.get_style_context().add_class("fuzzy-clock-applet-stack");

        popover.add(stack);
        stack.set_homogeneous(true);
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

        var menu = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        menu.border_width = 6;

        // TRANSLATORS: This Button Links to Gnome 'Settings' -> 'Details' -> 'Date and Time'
        var time_button = this.new_plain_button(_("Date and Time settings"));

        // TRANSLATORS: This Button Links to Gnome 'Calendar' application
        cal_button = this.new_plain_button(_("Calendar"));
        time_button.clicked.connect(on_date_activate);
        cal_button.clicked.connect(on_cal_activate);

        // menu page 1
        menu.pack_start(time_button, false, false, 0);
        menu.pack_start(cal_button, false, false, 0);

        // TRANSLATORS: This Button Links to FuzzyClock 'Preferences' Pane
        var sub_button = this.new_directional_button(_("Preferences"), Gtk.PositionType.RIGHT);
        sub_button.clicked.connect(()=> { stack.set_visible_child_name("prefs"); });
        menu.pack_end(sub_button, false, false, 2);

        stack.add_named(menu, "root");

        // page2
        menu = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
        menu.border_width = 6;

        // TRANSLATORS: When this checkbox is enabled the current date will be displayed
        check_date = new Gtk.CheckButton.with_label(_("Show date"));
        check_date.get_child().set_property("margin-start", 8);
        settings.bind("clock-show-date", check_date, "active", SettingsBindFlags.GET|SettingsBindFlags.SET);
        settings.bind("clock-show-date", date_label, "visible", SettingsBindFlags.DEFAULT);

        // TRANSLATORS: When this checkbox is disabled, fuzzy clock will name hours 'midnight' to 'noon', then repeat 'one', 'two', 'three' ...
        //              When enabled, fuzzy clock will use the hour names 'thirteen', 'fourteen' ...
        clock_format = new Gtk.CheckButton.with_label(_("Use 24 hour time"));
        clock_format.get_child().set_property("margin-start", 8);

        check_id = clock_format.toggled.connect_after(()=> {
            ClockFormat f = (ClockFormat)settings.get_enum("clock-format");
            ClockFormat newf = f == ClockFormat.TWELVE ? ClockFormat.TWENTYFOUR : ClockFormat.TWELVE;
            this.settings.set_enum("clock-format", newf);
        });

        // pack page2
        // TRANSLATORS: This Button Links to FuzzyClock 'Preferences' Pane
        sub_button = this.new_directional_button(_("Preferences"), Gtk.PositionType.LEFT);
        sub_button.clicked.connect(()=> { stack.set_visible_child_name("root"); });
        menu.pack_start(sub_button, false, false, 0);
        menu.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 2);
        menu.pack_start(check_date, false, false, 0);
        menu.pack_start(clock_format, false, false, 0);
        stack.add_named(menu, "prefs");


        // Always open to the root page
        popover.closed.connect(()=> {
            stack.set_visible_child_name("root");
        });

        widget.button_press_event.connect((e)=> {
            if (e.button != 1) {
                return Gdk.EVENT_PROPAGATE;
            }
            if (popover.get_visible()) {
                popover.hide();
            } else {
                this.manager.show_popover(widget);
            }
            return Gdk.EVENT_STOP;
        });

        Timeout.add_seconds_full(GLib.Priority.LOW, 30, update_clock);

        settings.changed.connect(on_settings_change);

        calprov = AppInfo.get_default_for_type(CALENDAR_MIME, false);

        var monitor = AppInfoMonitor.get();
        monitor.changed.connect(update_cal);

        cal_button.set_sensitive(calprov != null);
        cal_button.clicked.connect(on_cal_activate);

        update_cal();

        update_clock();
        add(widget);
        on_settings_change("clock-format");
        popover.get_child().show_all();

        show_all();
    }

    /**
     * Ensure translations are displayed correctly
     * according to the locale
     */
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

    /**
     * This is called to when the calendar app is updated/changed
     */
    void update_cal()
    {
        calprov = AppInfo.get_default_for_type(CALENDAR_MIME, false);
        cal_button.set_sensitive(calprov != null);
    }

    /**
     * This is called to launch Date and Time Settings app
     */
    void on_date_activate()
    {
        this.popover.hide();
        var app_info = new DesktopAppInfo("gnome-datetime-panel.desktop");

        if (app_info == null) {
            return;
        }
        try {
            app_info.launch(null, null);
        } catch (Error e) {
            message("Unable to launch gnome-datetime-panel.desktop: %s", e.message);
        }
    }

    /**
     * This is called to launch calendar app when user selects from drop-down
     */
    void on_cal_activate()
    {
        this.popover.hide();

        if (calprov == null) {
            return;
        }
        try {
            calprov.launch(null, null);
        } catch (Error e) {
            message("Unable to launch %s: %s", calprov.get_name(), e.message);
        }
    }

    public override void update_popovers(Budgie.PopoverManager? manager)
    {
        this.manager = manager;
        manager.register_popover(widget, popover);
    }

    /**
     * This is called when any of the preferences are changed
     */
    protected void on_settings_change(string key)
    {
        switch (key) {
            case "clock-format":
                SignalHandler.block((void*)this.clock_format, this.check_id);
                ClockFormat f = (ClockFormat)settings.get_enum(key);
                ampm = f == ClockFormat.TWELVE;
                clock_format.set_active(f == ClockFormat.TWENTYFOUR);
                this.update_clock();
                SignalHandler.unblock((void*)this.clock_format, this.check_id);
                break;
            case "clock-show-date":
                this.update_clock();
                break;
        }
    }

    /**
     * Update the date if necessary
     */
    protected void update_date()
    {
        if (!check_date.get_active()) {
            return;
        }
        string ftime;

        if (this.orient == Gtk.Orientation.HORIZONTAL) {
            ftime = date_format;
        } else {
            ftime = "<small>" + date_format + "</small>";
        }

        // Prevent unnecessary redraws
        var old = date_label.get_label();

        time = new DateTime.now_local();
        var ctime = time.format(ftime);

        if (old == ctime) {
            return;
        }

        date_label.set_markup(ctime);
    }

    /**
     * This is called once thirty-seconds, updating the displayed time
     */
    protected bool update_clock()
    {
        var now = new DateTime.now_local();
        int hour = now.get_hour();
        int minute = now.get_minute() + 2;           // Fuzz the minutes
        int rule = (int)Math.floor(minute / 5) % 12; // Round minutes so they fit into one of 12 rules

        // if the rounding of the minutes puts us in the next hour
        if (minute >= 60)
            hour += 1;

        // if the rule wants the next hour
        hour += rules[rule].hour_offset;

        if (hour < 0)                // Negative Hour
            hour += 24;
        else if (hour >= 24)         // End of Day hour-rollover
            hour -= 24;
        else if (ampm && hour >= 13) // AM|PM hour rollover
            hour -= 12;

        string ftime;
        if (this.orient == Gtk.Orientation.HORIZONTAL) {
            ftime = " %s ".printf(rules[rule].format);
        } else {
            ftime = " <small>%s</small> ".printf(rules[rule].format);
        }
        this.update_date();

        // Prevent unnecessary redraws
        var old = clock.get_label();
        var ctime = ftime.printf(hours[hour]);
        if (old == ctime) {
            if (!fuzzy_onpanel) {
                return false;
            }
            return true;

        }

        clock.set_markup(ctime);
        this.queue_draw();
        return fuzzy_onpanel;
    }
}


[ModuleInit]
public void peas_register_types(TypeModule module)
{
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(FuzzyClockPlugin));
}

/*
 * Editor modelines  -  https://www.wireshark.org/tools/modelines.html
 *
 * Local variables:
 * c-basic-offset: 4
 * tab-width: 4
 * indent-tabs-mode: nil
 * End:
 *
 * vi: set shiftwidth=4 tabstop=4 expandtab:
 * :indentSize=4:tabSize=4:noTabs=true:
 */