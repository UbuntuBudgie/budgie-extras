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
            return true;
        }
    }

    public class WallpaperSwitcherWidget : Budgie.RavenWidget {

        Gtk.Image icon;
        Gtk.Image stop_icon;
        Gtk.Image running_icon;
        Gtk.Box widget;
        Gtk.Label label;
        Gtk.Button action_button;
        GLib.Settings? settings;

        public WallpaperSwitcherWidget(string uuid, GLib.Settings? settings) {

            this.settings = settings;
            initialize(uuid, settings);

            widget = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            add(widget);
            widget.get_style_context().add_class("raven-header");

            icon = new Gtk.Image.from_icon_name("budgie-wsw-symbolic", Gtk.IconSize.MENU);
            stop_icon = new Gtk.Image.from_icon_name("media-playback-paused-symbolic", Gtk.IconSize.MENU);
            running_icon = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.MENU);

            // Values used by built-in widgets for consistency
            icon.margin = 4;
            icon.margin_start = 12;
            icon.margin_end = 10;
            widget.add(icon);

            label = new Gtk.Label("Wallpaper Workplace Switcher");
            widget.add(label);

            action_button = new Gtk.Button();
            action_button.set_image(stop_icon);
            action_button.get_style_context().add_class("flat");
            action_button.get_style_context().add_class("expander-button");
            action_button.margin = 4;
            action_button.valign = Gtk.Align.CENTER;
            widget.pack_end(action_button, false, false, 0);

            action_button.clicked.connect(() => {
                bool running = !settings.get_boolean("runwswitcher");
                set_action_button_image(running);
                settings.set_boolean("runwswitcher", running);
            });

            set_action_button_image(settings.get_boolean("runwswitcher"));

            show_all();
        }

        private void set_action_button_image(bool running) {
            if (running) {
                action_button.set_image(running_icon);
            } 
            else {
                action_button.set_image(stop_icon);
            }
        }

        public override Gtk.Widget build_settings_ui() {
            return new WallpaperSwitcherSettings(get_instance_settings());
        }
    }


    public class WallpaperSwitcherSettings : Gtk.Grid {

            // strings
            const string EXPLAIN = (_("Wallpaper Workspace Switcher automatically remembers which wallpaper was set per workspace"));

            public WallpaperSwitcherSettings(GLib.Settings? settings) {
                Gtk.Label explainlabel = new Gtk.Label(EXPLAIN);
                explainlabel.set_xalign(0);
                explainlabel.wrap = true;
                this.attach (new Gtk.Label(""), 0, 0, 2, 1);
                this.attach (explainlabel, 0, 1, 100, 1);
                this.show_all ();
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
