/*
 * Copyright 2026 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

namespace Slingshot.Backend {
[DBus (name="org.buddiesofbudgie.BudgieScreenlock")]
public interface Screenlock : Object
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
public interface GnomeSessionManager : Object
{
    public abstract async void Logout (uint mode) throws Error;
    public abstract async void Reboot() throws Error;
    public abstract async void Shutdown() throws Error;
}

public const string UNABLE_CONTACT = "Unable to contact ";
public const string LOGIND_LOGIN = "org.freedesktop.login1";

    public class SessionManager : Object {
        private static SessionManager? instance = null;

        private Screenlock? saver = null;
        private GnomeSessionManager? session = null;
        private LogindInterface? logind_interface = null;

        construct {
            setup_dbus.begin ();
        }

        public static SessionManager get_default () {
            if (instance == null) {
                instance = new SessionManager ();
            }
            return instance;
        }

        private async void setup_dbus () {
            try {
                saver = yield Bus.get_proxy(BusType.SESSION, "org.buddiesofbudgie.BudgieScreenlock", "/org/buddiesofbudgie/Screenlock");
            } catch (Error e) {
                warning ("Unable to contact screen saver: %s", e.message);
            }

            try {
                session = yield Bus.get_proxy (BusType.SESSION, "org.gnome.SessionManager", "/org/gnome/SessionManager");
            } catch (Error e) {
                warning ("Unable to contact GNOME Session: %s", e.message);
            }

            try {
                logind_interface = yield Bus.get_proxy (BusType.SYSTEM, Synapse.SystemdObject.UNIQUE_NAME, Synapse.SystemdObject.OBJECT_PATH);
            } catch (Error e) {
                warning ("Unable to contact logind: %s", e.message);
            }
        }

        public void lock () {
            Idle.add (() => {
                if (saver != null) {
                    saver.lock.begin ();
                }
                return false;
            });
        }

        public void logout () {
            if (session == null) {
                return;
            }

            Idle.add (() => {
                try {
                    session.Logout.begin (0);
                } catch (Error e) {
                    warning ("Logout failed: %s", e.message);
                }
                return false;
            });        }

        public void suspend () {
            if (logind_interface == null) {
                return;
            }

            Idle.add (() => {
                // Lock screen first
                if (saver != null) {
                    saver.lock.begin ();
                }

                // Wait 2 seconds for lock to engage
                Timeout.add (2000, () => {
                    try {
                        logind_interface.suspend (false);
                    } catch (Error e) {
                        warning ("Cannot suspend: %s", e.message);
                    }
                    return false;
                });

                return false;
            });
        }

        public void restart () {
            if (session == null) {
                return;
            }

            Idle.add (() => {
                try {
                    session.Reboot.begin ();
                } catch (Error e) {
                    warning ("Restart failed: %s", e.message);
                }
                return false;
            });
        }

        public void shutdown () {
           if (session == null) {
               return;
            }

            Idle.add (() => {
                try {
                    session.Shutdown.begin ();
                } catch (Error e) {
                    warning ("Shutdown failed: %s", e.message);
                }
                return false;
            });
        }
    }
}
