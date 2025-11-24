/*
* Copyright (c) 2010 Michal Hruby <michal.mhr@gmail.com>
*               2017 elementary LLC.
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Michal Hruby <michal.mhr@gmail.com>
*/

namespace Synapse {
    [DBus (name = "org.freedesktop.UPower")]
    public interface UPowerObject : Object {
        public const string UNIQUE_NAME = "org.freedesktop.UPower";
        public const string OBJECT_PATH = "/org/freedesktop/UPower";

        public abstract async void hibernate () throws GLib.Error;
        public abstract async void suspend () throws GLib.Error;
        public abstract async bool hibernate_allowed () throws GLib.Error;
        public abstract async bool suspend_allowed () throws GLib.Error;

        public abstract async void about_to_sleep () throws GLib.Error;
    }

    [DBus (name = "org.freedesktop.ConsoleKit.Manager")]
    public interface ConsoleKitObject : Object {
        public const string UNIQUE_NAME = "org.freedesktop.ConsoleKit";
        public const string OBJECT_PATH = "/org/freedesktop/ConsoleKit/Manager";

        public abstract void restart () throws GLib.Error;
        public abstract void stop () throws GLib.Error;
        public abstract async bool can_restart () throws GLib.Error;
        public abstract async bool can_stop () throws GLib.Error;
    }

    [DBus (name = "org.gnome.ScreenSaver")]
    public interface LockObject : Object {
        public const string UNIQUE_NAME = "org.gnome.ScreenSaver";
        public const string OBJECT_PATH = "/org/gnome/ScreenSaver";
        public abstract void lock () throws GLib.Error;
        public abstract bool get_active () throws GLib.Error;
    }

    [DBus (name = "org.freedesktop.login1.User")]
    interface LogOutObject : Object {
        public const string UNIQUE_NAME = "org.freedesktop.login1";
        public const string OBJECT_PATH = "/org/freedesktop/login1/user/self";

        public abstract void terminate () throws GLib.Error;
    }

    [DBus (name = "org.freedesktop.login1.Manager")]
    public interface SystemdObject : Object {
        public const string UNIQUE_NAME = "org.freedesktop.login1";
        public const string OBJECT_PATH = "/org/freedesktop/login1";

        public abstract void reboot (bool interactive) throws GLib.Error;
        public abstract void suspend (bool interactive) throws GLib.Error;
        public abstract void hibernate (bool interactive) throws GLib.Error;
        public abstract void power_off (bool interactive) throws GLib.Error;
        public abstract string can_suspend () throws GLib.Error;
        public abstract string can_hibernate () throws GLib.Error;
        public abstract string can_reboot () throws GLib.Error;
        public abstract string can_power_off () throws GLib.Error;
    }

    public class SystemManagementPlugin : Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }

        public void activate () { }

        public void deactivate () { }

        private abstract class SystemAction : Synapse.Match {
            public Gee.ArrayList<string> keywords { get; set; default = new Gee.ArrayList<string> (); }

            public abstract void do_action ();

            public abstract bool action_allowed ();

            protected void add_keywords (string keywords_list) {
                keywords.add_all_array (keywords_list.split (";"));
                keywords.add_all_array (dpgettext2 (
                    null,
                    "system_management_action_keyword",
                    keywords_list
                ).split (";"));
            }

            public override void execute (Match? match) {
                do_action ();
            }
        }

        private class LockAction : SystemAction {
            public LockAction () {
                Object (title: _("Lock"), match_type: MatchType.ACTION,
                        description: _("Lock this device"),
                        icon_name: "system-lock-screen", has_thumbnail: false);
                // ; seperated list of keywords
                add_keywords (NC_("system_management_action_keyword", "lock"));
            }

            public override bool action_allowed () {
                return true;
            }

            private async void do_lock () {
                try {
                    LockObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SESSION,
                        LockObject.UNIQUE_NAME,
                        LockObject.OBJECT_PATH
                    );

                    dbus_interface.lock ();
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }
            }

            public override void do_action () {
                Idle.add(()=> {
                    do_lock.begin ();
                    return false;
                });
            }
        }

        private class LogOutAction : SystemAction {
            public LogOutAction () {
                Object (title: _("Log Out"), match_type: MatchType.ACTION,
                        description: _("Close all open applications and quit"),
                        icon_name: "system-log-out", has_thumbnail: false);
                // ; seperated list of keywords
                add_keywords (NC_("system_management_action_keyword", "logout"));
            }

            public override bool action_allowed () {
                return true;
            }

            private async void do_log_out () {
                try {
                    LogOutObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        LogOutObject.UNIQUE_NAME,
                        LogOutObject.OBJECT_PATH
                    );

                    dbus_interface.terminate ();
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }
            }

            public override void do_action () {
                do_log_out.begin ();
            }
        }

        private class SuspendAction : SystemAction {
            public SuspendAction () {
                Object (title: _("Suspend"), match_type: MatchType.ACTION,
                        description: _("Put your computer into suspend mode"),
                        icon_name: "system-suspend", has_thumbnail: false);
                // ; seperated list of keywords
                add_keywords (NC_("system_management_action_keyword", "suspend"));
            }

            construct {
                check_allowed.begin ();
            }

            private async void check_allowed () {
                try {
                    SystemdObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        SystemdObject.UNIQUE_NAME,
                        SystemdObject.OBJECT_PATH
                    );

                    allowed = (dbus_interface.can_suspend () == "yes");
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                    allowed = false;
                }

                try {
                    UPowerObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        UPowerObject.UNIQUE_NAME,
                        UPowerObject.OBJECT_PATH
                    );

                    allowed = yield dbus_interface.suspend_allowed ();
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                    allowed = false;
                }
            }

            private bool allowed = false;

            public override bool action_allowed () {
                return allowed;
            }

            private async void do_suspend () {
                try {
                    SystemdObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        SystemdObject.UNIQUE_NAME,
                        SystemdObject.OBJECT_PATH
                    );

                    dbus_interface.suspend (true);
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }

                try {
                    UPowerObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        UPowerObject.UNIQUE_NAME,
                        UPowerObject.OBJECT_PATH
                    );

                    try {
                        yield dbus_interface.about_to_sleep ();
                    } catch (Error not_there_error) { }
                    // yea kinda nasty
                    //GnomeScreenSaverPlugin.lock_screen ();
                    // wait 2 seconds
                    Timeout.add (2000, do_suspend.callback);
                    yield;

                    yield dbus_interface.suspend ();
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }
            }

            public override void do_action () {
                do_suspend.begin ();
            }
        }

        private class HibernateAction : SystemAction {
            public HibernateAction () {
                Object (title: _("Hibernate"), match_type: MatchType.ACTION,
                        description: _("Put your computer into hibernation mode"),
                        icon_name: "system-hibernate", has_thumbnail: false);
                // ; seperated list of keywords
                add_keywords (NC_("system_management_action_keyword", "hibernate"));
            }

            construct {
                check_allowed.begin ();
            }

            private async void check_allowed () {
                try {
                    SystemdObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        SystemdObject.UNIQUE_NAME,
                        SystemdObject.OBJECT_PATH
                    );

                    allowed = (dbus_interface.can_hibernate () == "yes");
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                    allowed = false;
                }

                try {
                    UPowerObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        UPowerObject.UNIQUE_NAME,
                        UPowerObject.OBJECT_PATH
                    );

                    allowed = yield dbus_interface.hibernate_allowed ();
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                    allowed = false;
                }
            }

            private bool allowed = false;

            public override bool action_allowed () {
                return allowed;
            }

            private async void do_hibernate () {
                try {
                    SystemdObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        SystemdObject.UNIQUE_NAME,
                        SystemdObject.OBJECT_PATH
                    );

                    dbus_interface.hibernate (true);
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }

                try {
                    UPowerObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        UPowerObject.UNIQUE_NAME,
                        UPowerObject.OBJECT_PATH
                    );

                    try {
                        yield dbus_interface.about_to_sleep ();
                    } catch (Error not_there_error) { }
                    // yea kinda nasty
                    // GnomeScreenSaverPlugin.lock_screen ();
                    // wait 2 seconds
                    Timeout.add (2000, do_hibernate.callback);
                    yield;
                    dbus_interface.hibernate.begin ();
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }
            }

            public override void do_action () {
                do_hibernate.begin ();
            }
        }

        private class ShutdownAction : SystemAction {
            public ShutdownAction () {
                Object (title: _("Shut Down"), match_type: MatchType.ACTION,
                        description: _("Turn your computer off"),
                        icon_name: "system-shutdown", has_thumbnail: false);
                // ; seperated list of keywords
                add_keywords (NC_("system_management_action_keyword", "shutdown;turn off"));
            }

            construct {
                check_allowed.begin ();
            }

            private async void check_allowed () {
                try {
                    SystemdObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        SystemdObject.UNIQUE_NAME,
                        SystemdObject.OBJECT_PATH
                    );

                    allowed = (dbus_interface.can_power_off () == "yes");
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                    allowed = false;
                }

                try {
                    ConsoleKitObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        ConsoleKitObject.UNIQUE_NAME,
                        ConsoleKitObject.OBJECT_PATH
                    );

                    allowed = yield dbus_interface.can_stop ();
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                    allowed = false;
                }
            }

            private bool allowed = false;

            public override bool action_allowed () {
                return allowed;
            }

            public override void do_action () {
                try {
                    SystemdObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        SystemdObject.UNIQUE_NAME,
                        SystemdObject.OBJECT_PATH
                    );

                    dbus_interface.power_off (true);
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }

                try {
                    ConsoleKitObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        ConsoleKitObject.UNIQUE_NAME,
                        ConsoleKitObject.OBJECT_PATH
                    );

                    dbus_interface.stop ();
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }
            }
        }

        private class RestartAction : SystemAction {
            public RestartAction () {
                Object (title: _("Restart"), match_type: MatchType.ACTION,
                        description: _("Restart your computer"),
                        icon_name: "system-restart", has_thumbnail: false);
                // ; seperated list of keywords
                add_keywords (NC_("system_management_action_keyword", "restart;reboot"));
            }

            construct {
                check_allowed.begin ();
            }

            private async void check_allowed () {
                try {
                    SystemdObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        SystemdObject.UNIQUE_NAME,
                        SystemdObject.OBJECT_PATH
                    );

                    allowed = (dbus_interface.can_reboot () == "yes");
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                    allowed = false;
                }

                try {
                    ConsoleKitObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        ConsoleKitObject.UNIQUE_NAME,
                        ConsoleKitObject.OBJECT_PATH
                    );

                    allowed = yield dbus_interface.can_restart ();
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                    allowed = false;
                }
            }

            private bool allowed = false;

            public override bool action_allowed () {
                return allowed;
            }

            public override void do_action () {
                try {
                    SystemdObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        SystemdObject.UNIQUE_NAME,
                        SystemdObject.OBJECT_PATH
                    );

                    dbus_interface.reboot (true);
                    return;
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }

                try {
                    ConsoleKitObject dbus_interface = Bus.get_proxy_sync (
                        BusType.SYSTEM,
                        ConsoleKitObject.UNIQUE_NAME,
                        ConsoleKitObject.OBJECT_PATH
                    );

                    dbus_interface.restart ();
                } catch (GLib.Error err) {
                    warning ("%s", err.message);
                }
            }
        }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (
                typeof (SystemManagementPlugin),
                "System Management",
                _("Lock the session or Log Out from it. Suspend, hibernate, restart or shutdown your computer."),
                "system-restart",
                register_plugin,
                DBusService.get_default ().service_is_available (SystemdObject.UNIQUE_NAME) ||
                DBusService.get_default ().service_is_available (ConsoleKitObject.UNIQUE_NAME),
                _("ConsoleKit wasn't found")
            );
        }

        static construct {
            register_plugin ();
        }

        private Gee.List<SystemAction> actions;

        construct {
            actions = new Gee.LinkedList<SystemAction> ();
            actions.add (new LockAction ());
            actions.add (new LogOutAction ());
            actions.add (new SuspendAction ());
            actions.add (new HibernateAction ());
            actions.add (new ShutdownAction ());
            actions.add (new RestartAction ());
        }

        public async ResultSet? search (Query q) throws SearchError {
            // we only search for actions
            if (!(QueryFlags.ACTIONS in q.query_type)) {
                return null;
            }

            var result = new ResultSet ();

            var matchers = Query.get_matchers_for_query (
                q.query_string,
                0,
                RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS
            );

            foreach (var action in actions) {
                if (!action.action_allowed ()) {
                    continue;
                }

                foreach (var matcher in matchers) {
                    if (match (action, matcher)) {
                        result.add (action, matcher.value - Match.Score.INCREMENT_SMALL);
                        break;
                    }
                }
            }

            q.check_cancellable ();

            return result;
        }

        private bool match (SystemAction action, Gee.Map.Entry<Regex, int> matcher) {
            if (matcher.key.match (action.title)) {
                return true;
            }

            foreach (var keyword in action.keywords) {
                if (matcher.key.match (keyword)) {
                    return true;
                }
            }
            return false;
        }

    }
}
