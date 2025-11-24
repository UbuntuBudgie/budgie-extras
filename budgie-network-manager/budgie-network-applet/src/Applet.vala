/*
* Copyright (c) 2018-2020 Daniel Pinto (https://github.com/danielpinto8zz6/budgie-network-applet)
* Copyright (c) 2015-2018 elementary LLC (https://elementary.io)
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU Library General Public License as published by
* the Free Software Foundation, either version 2.1 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Library General Public License for more details.
*
* You should have received a copy of the GNU Library General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*/

namespace Network {
    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget (string uuid) {
            return new Applet ();
        }
    }

    public class Applet : Budgie.Applet {
        protected Gtk.EventBox widget;

        Budgie.Popover ? popover = null;

        private unowned Budgie.PopoverManager ? manager = null;

        Widgets.PopoverWidget? popover_widget = null;
        Widgets.DisplayWidget? display_widget = null;

        public Applet () {
            GLib.Intl.setlocale (GLib.LocaleCategory.ALL, "");
            GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
            GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
            GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

            widget = new Gtk.EventBox ();
            add(widget);

            get_style_context ().add_class ("budgie-network-applet");

            popover = new Budgie.Popover (widget);

            display_widget = new Widgets.DisplayWidget ();
            widget.add (display_widget);

            popover_widget = new Widgets.PopoverWidget ();
            popover_widget.width_request = 250;
            popover_widget.border_width = 6;
            popover.add (popover_widget);
            popover_widget.notify["state"].connect (on_state_changed);
            popover_widget.notify["secure"].connect (on_state_changed);
            popover_widget.notify["extra-info"].connect (on_state_changed);
            popover_widget.settings_shown.connect (() => { popover.hide(); });
                
            widget.button_press_event.connect ((e)=> {
                if (e.button != 1) {
                    return Gdk.EVENT_PROPAGATE;
                }
                if (popover.get_visible ()) {
                    popover.hide ();
                } else {
                    this.manager.show_popover (widget);
                }
                return Gdk.EVENT_STOP;
            });

            popover.get_child ().show_all ();

            show_all ();

            on_state_changed ();
        }

        public override void update_popovers (Budgie.PopoverManager ? manager) {
            this.manager = manager;
            manager.register_popover (widget, popover);
        }

        void on_state_changed () {
            assert (popover_widget != null);
            assert (display_widget != null);
    
            display_widget.update_state (popover_widget.state, popover_widget.secure, popover_widget.extra_info);
        }
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Budgie.Plugin), typeof (Network.Plugin));
}