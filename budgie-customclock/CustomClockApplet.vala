/*
 * Copyright © 2014-2021 Budgie Desktop Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

public class CustomClockPlugin : Budgie.Plugin, Peas.ExtensionBase {
	public Budgie.Applet get_panel_widget(string uuid) {
		return new CustomClockApplet(uuid);
	}
}

public const string CALENDAR_MIME = "text/calendar";

public class CustomClockApplet : Budgie.Applet {
	protected Gtk.EventBox widget;
	protected Gtk.Label clock;

	private DateTime time;

	protected Settings settings;

	Budgie.Popover? popover = null;
	AppInfo? calprov = null;
	Gtk.Button cal_button;

	private unowned Budgie.PopoverManager? manager = null;

	private TimeZone clock_timezone;
	private string clock_format;

	public string uuid { public set; public get; }

	Gtk.Button new_plain_button(string label_str) {
		Gtk.Button ret = new Gtk.Button.with_label(label_str);
		ret.get_child().halign = Gtk.Align.START;
		ret.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

		return ret;
	}

	public CustomClockApplet(string uuid) {
		Object(uuid: uuid);

		settings_schema = "org.ubuntubudgie.budgie-customclock";
		settings_prefix = "/org/ubuntubudgie/budgie-customclock/instance/clock";


		settings = this.get_applet_settings(uuid);
		
		time = new DateTime.now_local();


		widget = new Gtk.EventBox();
		clock = new Gtk.Label("");
		widget.add(clock);

		clock.valign = Gtk.Align.CENTER;

		get_style_context().add_class("budgie-clock-applet");

		// Create a submenu system
		popover = new Budgie.Popover(widget);

		var stack = new Gtk.Stack();
		stack.get_style_context().add_class("clock-applet-stack");

		popover.add(stack);
		stack.set_homogeneous(true);
		stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

		var menu = new Gtk.Box(Gtk.Orientation.VERTICAL, 1);
		menu.border_width = 6;

		var time_button = this.new_plain_button(_("System time and date settings"));
		cal_button = this.new_plain_button(_("Calendar"));
		time_button.clicked.connect(on_date_activate);
		cal_button.clicked.connect(on_cal_activate);

		// menu page 1
		menu.pack_start(time_button, false, false, 0);
		menu.pack_start(cal_button, false, false, 0);

		stack.add_named(menu, "root");

		// Always open to the root page
		popover.closed.connect(() => {
			stack.set_visible_child_name("root");
		});

		widget.button_press_event.connect((e) => {
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

		Timeout.add_seconds_full(Priority.LOW, 1, update_clock);

		settings.changed.connect(on_settings_change);

		calprov = AppInfo.get_default_for_type(CALENDAR_MIME, false);

		var monitor = AppInfoMonitor.get();
		monitor.changed.connect(update_cal);

		cal_button.set_sensitive(calprov != null);
		cal_button.clicked.connect(on_cal_activate);

		update_cal();

		
		add(widget);

		this.clock_timezone = new TimeZone(settings.get_string("timezone"));
		this.clock_format = settings.get_string("format");
		update_clock();
		popover.get_child().show_all();

		show_all();
	}

	void update_cal() {
		calprov = AppInfo.get_default_for_type(CALENDAR_MIME, false);
		cal_button.set_sensitive(calprov != null);
	}

	void on_date_activate() {
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

	void on_cal_activate() {
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

	public override void update_popovers(Budgie.PopoverManager? manager) {
		this.manager = manager;
		manager.register_popover(widget, popover);
	}

	protected void on_settings_change(string key) {
		switch (key) {
			case "timezone":
				this.clock_timezone = new TimeZone(settings.get_string(key));
				this.update_clock();
				break;
			case "format":
				this.clock_format = settings.get_string(key);
				this.update_clock();
				break;
		}
	}


	/**
	 * This is called once every second, updating the time
	 */
	protected bool update_clock() {
		time = new DateTime.now(this.clock_timezone);

		// Prevent unnecessary redraws
		var old = clock.get_label();
		var ctime = time.format(this.clock_format);
		if (old == ctime) {
			return true;
		}

		clock.set_markup(ctime);
		this.queue_draw();

		return true;
	}

	public override bool supports_settings() {
		return true;
	}

	public override Gtk.Widget? get_settings_ui() {
		return new CustomClockSettings(this.get_applet_settings(uuid));
	}
}


[GtkTemplate (ui="/org/ubuntubudgie/budgie-customclock/settings.ui")]
public class CustomClockSettings : Gtk.Grid {

	[GtkChild]
	private Gtk.Entry? txtFormat;
	
	[GtkChild]
	private Gtk.Entry? txtTimezone;

	public CustomClockSettings(Settings? settings) {
		settings.bind("format", this.txtFormat, "text", SettingsBindFlags.DEFAULT);
		settings.bind("timezone", this.txtTimezone, "text", SettingsBindFlags.DEFAULT);
	}

}


[ModuleInit]
public void peas_register_types(TypeModule module) {
	// boilerplate - all modules need this
	var objmodule = module as Peas.ObjectModule;
	objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(CustomClockPlugin));
}
