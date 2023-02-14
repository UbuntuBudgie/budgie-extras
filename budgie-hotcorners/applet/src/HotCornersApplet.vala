using Gtk;
using Json;

/*
* HotCornersIII
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


namespace HotCornersApplet {

    private void set_margins (
        Widget w, int l, int r, int t, int b
    ) {
        w.set_margin_start(l);
        w.set_margin_end(r);
        w.set_margin_top(t);
        w.set_margin_bottom(b);
    }

    GLib.Settings hotsettings;


    class SettingsGrid : Gtk.Grid {

        public SettingsGrid (Budgie.Popover? popover = null) {

            string css_data = """
            .justbold {
                font-weight: bold;
            }
            .justitalic {
                font-style: italic;
            }
            """;

            var css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(css_data);
                Gtk.StyleContext.add_provider_for_screen(
                    this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
                print("Could not load css\n");
            }
            Label masterswitchlabel = makelabel(_("Activate hotcorners"), {0, 40, 0, 0});
            this.attach(masterswitchlabel, 0, 0, 1, 1);
            Box masterswitchbox = new Gtk.Box(HORIZONTAL, 0);
            Switch masterswitch = new Gtk.Switch();
            hotsettings.bind(
                "active", masterswitch, "state", SettingsBindFlags.GET|SettingsBindFlags.SET
            );
            masterswitchbox.pack_end(masterswitch, false, false, 0);
            this.attach(masterswitchbox, 1, 0, 1, 1);
            this.attach(new Label(""), 0, 1, 1, 1);
            Label settingslabel = makelabel(_("Settings"), {0, 40, 0, 0});
            this.attach(settingslabel, 0, 2, 1, 1);
            Box settingsbox = new Gtk.Box(HORIZONTAL, 0);

            Button settingsbutton = new Gtk.Button();
            settingsbutton.clicked.connect(()=> {
                run_command(
                    "/usr/libexec/budgie-hotcorners/budgie-hotcorners-settingswindow" // replace
                );
                if (popover != null) {
                    popover.hide();
                }
            });

            settingsbutton.set_can_focus(false);
            Image settingsbuttonimage = new Gtk.Image.from_icon_name(
                "budgie-hotcorners-symbolic", Gtk.IconSize.BUTTON
            );
            settingsbuttonimage.set_pixel_size(24);
            settingsbutton.set_relief(Gtk.ReliefStyle.NONE);
            settingsbutton.image = settingsbuttonimage;
            settingsbox.pack_end(settingsbutton, false, false, 0);
            this.attach(settingsbox, 1, 2, 1, 1);
            this.show_all();
        }

        private void run_command (string cmd) {
            /* execute the command */
            try {
                Process.spawn_command_line_async(cmd);
            }
            catch (GLib.SpawnError err) {
                /*
                * in case an error occurs, the command most likely is
                * incorrect not much use for any action
                */
            }
        }

        private Label makelabel (
            string tekst, int[] mrg, string? style = null
        ) {
            Label newlabel = new Label(tekst);
            if (style != null) {
                newlabel.get_style_context().add_class(style);
            }
            newlabel.xalign = 0;
            set_margins(newlabel, mrg[0], mrg[1], mrg[2], mrg[3]);
            return newlabel;
        }
    }

    public class HotCornersSettings : Gtk.Grid {

        /* Budgie Settings -section */
        public HotCornersSettings () {
            Grid settingssection = new SettingsGrid();
            Label hint = new Label(
                _("Hotcorners settings is also available via the main menu")
            );
            hint.get_style_context().add_class("justitalic");
            set_margins(hint, 0, 0, 50, 0);
            hint.wrap = true;
            settingssection.attach(hint, 0, 10, 10, 10);

            set_margins(settingssection, 0, 0, 30, 0);
            this.attach (settingssection, 0, 0, 1, 1);
            //  this.settings = hotsettings;
            this.show_all();
        }
    }


    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {

        public Budgie.Applet get_panel_widget(string uuid) {
            return new Applet(uuid);
        }
    }


    public class HotCornersPopover : Budgie.Popover {

        private Gtk.EventBox indicatorBox;
        private Gtk.Image indicatorIcon;

        public HotCornersPopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);
            this.indicatorBox = indicatorBox;
            /* set icon */
            this.indicatorIcon = new Gtk.Image.from_icon_name(
                "budgie-hotcorners-symbolic", Gtk.IconSize.MENU
            );
            indicatorBox.add(this.indicatorIcon);
            Gtk.Grid popoversettings = new SettingsGrid(this);
            set_margins(popoversettings, 30, 30, 30, 30);
            this.add(popoversettings);
        }
    }


    public class Applet : Budgie.Applet {

        private Gtk.EventBox indicatorBox;
        private HotCornersPopover popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        public string uuid { public set; public get; }
        /* specifically to the settings section */
        public override bool supports_settings()
        {
            return true;
        }
        public override Gtk.Widget? get_settings_ui()
        {
            return new HotCornersSettings();
        }

        public Applet(string uuid) {
            hotsettings = new GLib.Settings(
                "org.ubuntubudgie.budgie-extras.HotCorners"
            );
            initialiseLocaleLanguageSupport();
            /* box */
            indicatorBox = new Gtk.EventBox();
            /* Popover */
            popover = new HotCornersPopover(indicatorBox);
            add(indicatorBox);
            /* On Press indicatorBox */
            set_action();
            popover.get_child().show_all();
            show_all();
        }

        private void set_action () {
            /* On Press indicatorBox */
            indicatorBox.button_press_event.connect((e)=> {
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
        }

        public override void update_popovers(Budgie.PopoverManager? manager)
        {
            this.manager = manager;
            manager.register_popover(indicatorBox, popover);
        }

        public void initialiseLocaleLanguageSupport(){
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
    }
}

[ModuleInit]
public void peas_register_types(TypeModule module){
    /* boilerplate - all modules need this */
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(HotCornersApplet.Plugin)
    );
}

// 273
