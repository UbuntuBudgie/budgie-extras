using Gtk;
using Cairo;

/*
Budgie Window Shuffler III
Author: Jacob Vlijm
Copyright © 2017 Ubuntu Budgie Developers
Website=https://ubuntubudgie.org
This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or any later version. This
program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details. You
should have received a copy of the GNU General Public License along with this
program.  If not, see <https://www.gnu.org/licenses/>.
*/

namespace ShufflerExceedsWarning {

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        //  public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        public abstract int show_warningage () throws Error;
    }


    class SizeExceedsWarning : Gtk.Window {

        public SizeExceedsWarning () {
            initialiseLocaleLanguageSupport();
            string warning_css = """
                .header {
                    font-weight: bold;
                    color: white;
                }
                """;
            // transparency
            var screen = this.get_screen();
            this.set_app_paintable(true);
            var visual = screen.get_rgba_visual();
            this.set_visual(visual);
            this.draw.connect(on_draw);
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(warning_css);
                Gtk.StyleContext.add_provider_for_screen(
                    screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }

            this.title = "sizeexceedswarning";
            this.set_position (CENTER);
            this.set_decorated(false);
            this.set_accept_focus(false);

            var maingrid = new Gtk.Grid ();
            var label = new Label (_("Minimum window size exceeds target"));
            //  var label = new Label (_("Minimum window size exceeds target"));
            var sc = label.get_style_context ();
            sc.add_class ("header");
            label.xalign = (float)0.5;
            this.add (maingrid);
            string tmp = Environment.get_variable("XDG_RUNTIME_DIR") ?? Environment.get_variable("HOME");
            Gtk.Image img = new Gtk.Image.from_file (
                GLib.Path.build_path(GLib.Path.DIR_SEPARATOR_S, tmp, ".shuffler-warning.png")
            );
            maingrid.attach (label, 0, 0, 1, 1);
            maingrid.attach (img, 0, 0, 1, 1);
            this.destroy.connect (Gtk.main_quit);
            this.show_all ();
        }

        private bool on_draw (Widget da, Context ctx) {
            // needs to be connected to transparency settings change
            ctx.set_source_rgba(0, 0, 0, 0);
            ctx.set_operator(Cairo.Operator.SOURCE);
            ctx.paint();
            ctx.set_operator(Cairo.Operator.OVER);
            return false;
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
    }

    public static void main (string[] args) {


        try {
            ShufflerInfoClient client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );
            Gtk.init (ref args);
            var warn = new SizeExceedsWarning();
            int lifetime = client.show_warningage();
            GLib.Timeout.add (100, ()=> {
                if (lifetime <= 0) {
                    warn.destroy();
                    return false;
                }
                else {
                    try {
                        lifetime = client.show_warningage();
                    }
                    catch (Error e) {
                        // on fail, make sure window warning doesn't stick
                        warn.destroy();
                        return false;
                    }
                    return true;
                }
            });


            Gtk.main ();
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }

}
