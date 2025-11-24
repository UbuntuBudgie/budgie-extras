/*
 * This file is part of budgie-desktop
 *
 * Copyright © 2019 Ubuntu Budgie Developers,
 *             2015-2019 Budgie Desktop Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

namespace AppMenu
{

[DBus (name="org.gnome.ScreenSaver")]
public interface ScreenSaver : Object
{
    public abstract async void lock() throws Error;
}

/* logind */
[DBus (name = "org.freedesktop.login1.Manager")]
public interface LogindInterface : Object {
    public abstract void suspend(bool interactive) throws Error;
    public abstract void hibernate(bool interactive) throws Error;
}

[DBus (name="org.gnome.SessionManager")]
public interface SessionManager : Object
{
    public abstract async void Logout (uint mode) throws Error;
    public abstract async void Reboot() throws Error;
    public abstract async void Shutdown() throws Error;
}

public const string UNABLE_CONTACT = "Unable to contact ";
public const string LOGIND_LOGIN = "org.freedesktop.login1";


class PowerStrip : Gtk.Box
{
    private ScreenSaver? saver = null;
    private SessionManager? session = null;
    private LogindInterface? logind_interface = null;
    private Gtk.Button? lock_btn = null;
    private Gtk.Button? power_btn = null;
    public signal void invoke_action ();

    private static GLib.Settings settings { get; private set; default = null; }

    static construct {
        settings = new GLib.Settings ("org.ubuntubudgie.plugins.budgie-appmenu");
    }

    async void setup_dbus()
    {
        try {
            saver = yield Bus.get_proxy(BusType.SESSION, "org.gnome.ScreenSaver", "/org/gnome/ScreenSaver");
        } catch (Error e) {
            warning("Unable to contact login manager: %s", e.message);
            return;
        }
        try {
            session = yield Bus.get_proxy(BusType.SESSION, "org.gnome.SessionManager", "/org/gnome/SessionManager");
        } catch (Error e) {
            power_btn.sensitive = false;
            warning("Unable to contact GNOME Session: %s", e.message);
        }
        try {
            logind_interface = yield Bus.get_proxy(BusType.SYSTEM, LOGIND_LOGIN, "/org/freedesktop/login1");
        } catch (Error e) {
            warning(UNABLE_CONTACT + "logind: %s", e.message);
        }
    }

    construct
    {
        Gtk.Box? bottom = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 1);
        //margin_top = 10;
        //get_style_context().add_class("raven-header");
        get_style_context().add_class("powerstrip");
        get_style_context().add_class("bottom");
        bottom.halign = Gtk.Align.CENTER;
        //bottom.margin_top = 5;
        //bottom.margin_bottom = 5;
        add(bottom);

        get_style_context().add_class("primary-control");

        var btn = new Gtk.Button.from_icon_name("system-shutdown-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        btn.clicked.connect(()=> {
            shutdown();
        });
        btn.halign = Gtk.Align.START;
        btn.get_style_context().add_class("flat");
        btn.set_tooltip_text(_("Shutdown"));
        btn.set_can_focus(false);
        bottom.pack_start(btn, false, false, 0);

        btn = new Gtk.Button.from_icon_name("system-suspend-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        btn.clicked.connect(()=> {
            try {
                suspend();
            }
            catch (Error e) {
                warning("suspend: %s", e.message);
            }
            
        });
        btn.halign = Gtk.Align.START;
        btn.get_style_context().add_class("flat");
        btn.set_tooltip_text(_("Suspend"));
        btn.set_can_focus(false);
        bottom.pack_start(btn, false, false, 0);

        btn = new Gtk.Button.from_icon_name("system-restart-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        btn.clicked.connect(()=> {
            reboot();
        });
        btn.halign = Gtk.Align.START;
        btn.get_style_context().add_class("flat");
        btn.set_tooltip_text(_("Restart"));
        btn.set_can_focus(false);
        bottom.pack_start(btn, false, false, 0);

        btn = new Gtk.Button.from_icon_name("system-lock-screen-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        btn.clicked.connect(()=> {
            lock_screen();
        });
        lock_btn = btn;
        btn.halign = Gtk.Align.START;
        btn.get_style_context().add_class("flat");
        btn.set_tooltip_text(_("Lock"));
        btn.set_can_focus(false);
        bottom.pack_start(btn, false, false, 0);

        btn = new Gtk.Button.from_icon_name("system-log-out-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        power_btn = btn;
        btn.clicked.connect(()=> {
            try {
                if (session == null) {
                    return;
                }
                invoke_action();
                session.Logout.begin(0);
            } catch (Error e) {
                message("Error invoking end session dialog: %s", e.message);
            }
        });
        btn.halign = Gtk.Align.START;
        btn.get_style_context().add_class("flat");
        btn.set_tooltip_text(_("Logout"));
        btn.set_can_focus(false);
        bottom.pack_start(btn, false, false, 0);

        lock_btn.no_show_all = true;
        lock_btn.hide();
        setup_dbus.begin((obj,res)=> {
            if (saver != null) {
                lock_btn.no_show_all = false;
                lock_btn.show_all();
            }
        });

        settings.changed["enable-powerstrip"].connect( () => {
            set_visible(settings.get_boolean("enable-powerstrip"));
        });
    }

    private void reboot() {
        if (session == null) {
            return;
        }

        Idle.add(()=> {
            invoke_action();
            session.Reboot.begin();
            return false;
        });
    }

    private void shutdown() {
        if (session == null) {
            return;
        }

        Idle.add(()=> {
            invoke_action();
            session.Shutdown.begin();
            return false;
        });
    }

    private void suspend() {
        if (logind_interface == null) {
            return;
        }

        Idle.add(()=> {
            invoke_action();
            lock_screen();
            try {
                logind_interface.suspend(false);
            } catch (Error e) {
                warning("Cannot suspend: %s", e.message);
            }
            return false;
        });
    }

    void lock_screen() {
        Idle.add(()=> {
            //try {
                invoke_action();
                saver.lock.begin();
            //} catch (Error e) {
            //    warning("Cannot lock screen: %s", e.message);
           // }
            return false;
        });
    }
}

} /* End namespace */

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