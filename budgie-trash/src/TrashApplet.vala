/*
 * This file is part of UbuntuBudgie
 * 
 * Copyright © 2015-2017 Budgie Desktop Developers
 * Copyright © 2018-2019 Ubuntu Budgie Developers
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

using TrashApplet.Widgets;
using TrashApplet.Helpers;
using TrashApplet.Models;

namespace TrashApplet{

public class Plugin : Budgie.Plugin, Peas.ExtensionBase{
    
    public Budgie.Applet get_panel_widget(string uuid){
    
        return new Applet();
    }

}

public class Applet : Budgie.Applet{

    Gtk.EventBox indicatorBox;
    TrashPopover popover = null;
    private unowned Budgie.PopoverManager? manager = null;

    public Applet(){

        initialiseLocaleLanguageSupport();

        // Indicator box on Panel
        indicatorBox = new Gtk.EventBox();
        add(indicatorBox);
       
        // Popover
        popover = new TrashPopover(indicatorBox);
        
        // On Press indicatorBox
        indicatorBox.button_press_event.connect((e)=> {
            popover.update();
            if (e.button != 1) {
                return Gdk.EVENT_PROPAGATE;
            }
            if (popover.get_visible()) {
                popover.hide();
            } else {
                this.manager.show_popover(indicatorBox);
            }
            return Gdk.EVENT_STOP;
        });

        // Finally show all
        popover.get_child().show_all();
        show_all();

    }

    /*Update popover*/
    public override void update_popovers(Budgie.PopoverManager? manager)
    {
        this.manager = manager;
        manager.register_popover(indicatorBox, popover);
    }

    public void initialiseLocaleLanguageSupport(){
        // Initialise gettext
        GLib.Intl.setlocale(GLib.LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain(Config.GETTEXT_PACKAGE);
    }
}

}

[ModuleInit]
public void peas_register_types(TypeModule module){

    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(TrashApplet.Plugin));
    

}