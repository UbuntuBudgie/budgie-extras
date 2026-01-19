using Gtk;

/*
* WallpaperSwitcher II - Raven Widget
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


namespace WallpaperSwitcherWidget {

    public class WallpaperSwitcherPlugin : Budgie.RavenPlugin, Peas.ExtensionBase {
        public Budgie.RavenWidget new_widget_instance(string uuid, GLib.Settings? settings) {
            Peas.PluginInfo plugin_info = get_plugin_info();
            string moduledir = plugin_info.get_module_dir();
            string cmd = moduledir + @"/wallpaperswitcher_runner $uuid";
                Idle.add(() => {
                    try {
                        Process.spawn_command_line_async(cmd);
                    }
                    catch (Error e) {
                    }
                    return false;
                });
            initialiseLocaleLanguageSupport();
            return new WallpaperSwitcherWidget(uuid, settings);
        }

        public void initialiseLocaleLanguageSupport() {
                GLib.Intl.setlocale(GLib.LocaleCategory.ALL, "");
                GLib.Intl.bindtextdomain(
                    Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR
                );
                GLib.Intl.bind_textdomain_codeset(
                    Config.GETTEXT_PACKAGE, "UTF-8"
                );
                GLib.Intl.textdomain(Config.GETTEXT_PACKAGE);
            }

        public bool supports_settings() {
            return false;
        }
    }

    public class WallpaperSwitcherWidget : Budgie.RavenWidget {

        Gtk.Image icon;
        Gtk.Image stop_icon;
        Gtk.Image start_icon;
        Gtk.Box widget;
        Gtk.Label label;
        Gtk.Button action_button;
        GLib.Settings? switchersettings;
        const string SETTRUE = (_("Stop"));
        const string SETFALSE = (_("Start"));
        const string EXPLAIN = (_("Wallpaper Workspace Switcher automatically remembers which wallpaper was set per workspace"));

        public WallpaperSwitcherWidget(string uuid, GLib.Settings? settings) {

            initialize(uuid, settings);
            switchersettings = new GLib.Settings("org.ubuntubudgie.plugins.budgie-wswitcher");

            widget = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            add(widget);
            widget.get_style_context().add_class("raven-header");

            icon = new Gtk.Image.from_icon_name("budgie-wsw-symbolic", Gtk.IconSize.MENU);
            icon.set_tooltip_text(EXPLAIN);
            stop_icon = new Gtk.Image.from_icon_name("media-playback-paused-symbolic", Gtk.IconSize.MENU);
            start_icon = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.MENU);

            // Values used by built-in widgets for consistency
            icon.margin = 4;
            icon.margin_start = 12;
            icon.margin_end = 10;
            widget.add(icon);

            label = new Gtk.Label("Wallpaper Workplace Switcher");
            widget.add(label);

            action_button = new Gtk.Button();
            action_button.get_style_context().add_class("flat");
            action_button.get_style_context().add_class("expander-button");
            action_button.margin = 4;
            action_button.valign = Gtk.Align.CENTER;
            widget.pack_end(action_button, false, false, 0);

            action_button.clicked.connect(() => {
                bool running = !switchersettings.get_boolean("runwswitcher");
                set_action_button_image(running);
                switchersettings.set_boolean("runwswitcher", running);
            });

            set_action_button_image(switchersettings.get_boolean("runwswitcher"));

            show_all();
        }

        private void set_action_button_image(bool running) {
            if (running) {
                action_button.set_image(stop_icon);
                action_button.set_tooltip_text(SETTRUE);
                label.get_style_context().remove_class ("dim-label");
                icon.get_style_context().remove_class ("dim-label");
            } 
            else {
                action_button.set_image(start_icon);
                action_button.set_tooltip_text(SETFALSE);
                icon.get_style_context().add_class ("dim-label");
                label.get_style_context().add_class ("dim-label");
            }
        }
    }
}

[ModuleInit]
public void peas_register_types(TypeModule module) {
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.RavenPlugin),
                                      typeof(WallpaperSwitcherWidget.WallpaperSwitcherPlugin));
}
