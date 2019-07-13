/*
 * AdvancedBrightnessController 
 * This file is part of UbuntuBudgie
 * 
 * Author: Serdar ŞEN github.com/serdarsen
 * 
 * Copyright © 2015-2017 Budgie Desktop Developers
 * Copyright © 2018-2019 Ubuntu Budgie Developers
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

using AdvancedBrightnessController.Widgets;
using AdvancedBrightnessController.Helpers;

namespace AdvancedBrightnessController
{ 
public class Applet : Budgie.Applet
{
    private IndicatorButton indicatorButton;
    private Popover popover;
    private unowned Budgie.PopoverManager? manager = null;
    private GLib.Settings? settings = null;
    public string uuid { public set; public get; }
    private ConfigHelper gnomeSettingsDaemonsColorPluginConfigHelper;

    public Applet(string uuid)
    {
        Object(uuid: uuid);

        initialiseLocaleLanguageSupport();
        gnomeSettingsDaemonsColorPluginConfigHelper = new ConfigHelper("autostart", "org.gnome.SettingsDaemon.Color.desktop");
        settings = get_applet_settings(uuid);
        indicatorButton = new IndicatorButton();
        popover = new Popover(indicatorButton, 140, 300);        AddPressEventToIndicatorButton();
        add(indicatorButton);
        show_all();
    }

    public void AddPressEventToIndicatorButton()
    {
        indicatorButton.button_press_event.connect((e)=> 
        {
            if (e.button != 1) 
            {
                return Gdk.EVENT_PROPAGATE;
            }
            if (popover.get_visible()) 
            {
                popover.hide();
            } 
            else 
            {
                this.manager.show_popover(indicatorButton);
                popover.OnShow();
            }
            return Gdk.EVENT_STOP;
        });
    }

    /*Update popover*/
    public override void update_popovers(Budgie.PopoverManager? manager)
    {
        this.manager = manager;
        manager.register_popover(indicatorButton, popover);
    }

    public void initialiseLocaleLanguageSupport(){
        // Initialise gettext
        GLib.Intl.setlocale(GLib.LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain(Config.GETTEXT_PACKAGE);
    }

    public override Gtk.Widget? get_settings_ui()
    {
        var settingsLayout = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        var gnomeSettingsDaemonsColorPluginCheckButtonLabel = new Gtk.Label(_("Remove Gnome Settings Daemon's color plugin from autostart"));
        gnomeSettingsDaemonsColorPluginCheckButtonLabel.set_line_wrap(true);
        var gnomeSettingsDaemonsColorPluginCheckButton = new Gtk.CheckButton();

        if(gnomeSettingsDaemonsColorPluginConfigHelper.IsFileExist())
        {
            gnomeSettingsDaemonsColorPluginCheckButton.set_active(true);
        }
        else
        {
            gnomeSettingsDaemonsColorPluginCheckButton.set_active(false);
        }

        gnomeSettingsDaemonsColorPluginCheckButton.toggled.connect(OnGnomeSettingsDaemonsColorPluginCheckButtonToggled);
        settingsLayout.pack_start(gnomeSettingsDaemonsColorPluginCheckButton, false, false, 1);
        settingsLayout.pack_start(gnomeSettingsDaemonsColorPluginCheckButtonLabel, false, false, 2);
        settingsLayout.show();

        return settingsLayout;
    }

    public void OnGnomeSettingsDaemonsColorPluginCheckButtonToggled()
    {
        if(gnomeSettingsDaemonsColorPluginConfigHelper.IsFileExist())
        {
            gnomeSettingsDaemonsColorPluginConfigHelper.Delete();
        }
        else
        {
            gnomeSettingsDaemonsColorPluginConfigHelper.Write({
            "[Desktop Entry]",
            "Type=Application",
            "Name=GNOME Settings Daemon's color plugin",
            "Exec=/usr/lib/gnome-settings-daemon/gsd-color",
            "OnlyShowIn=GNOME;",
            "NoDisplay=false",
            "X-GNOME-Autostart-Phase=Initialization",
            "X-GNOME-Autostart-Notify=true",
            "X-GNOME-AutoRestart=true",
            "X-Ubuntu-Gettext-Domain=gnome-settings-daemon",
            "X-GNOME-Autostart-enabled=false"});
        }
    }

    public override bool supports_settings()
    {
        return true;
    }
}

public class Plugin : Budgie.Plugin, Peas.ExtensionBase
{
    public Budgie.Applet get_panel_widget(string uuid)
    {
        return new Applet(uuid);
    }
}
}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(AdvancedBrightnessController.Plugin));
}