using Gtk;
using Gee;
using Math;

/*
* WeatherShowII
* Author: Jacob Vlijm
* Copyright © 2017-2019 Ubuntu Budgie Developers
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


public class ColorPicker : Gtk.Window {


    private Gtk.ColorChooserWidget color;
    double red1;
    double red2;
    double green1;
    double green2;
    double blue1;
    double blue2;

    GLib.Settings settings;
    Gtk.SpinButton redbutton;
    Gtk.SpinButton greenbutton;
    Gtk.SpinButton bluebutton;

    public ColorPicker () {
        initialiseLocaleLanguageSupport();

        settings = new GLib.Settings(
            "org.ubuntubudgie.plugins.weathershow"
        );
        // maingrid
        Grid maingrid = new Gtk.Grid();
        maingrid.set_border_width(20);
        this.add(maingrid);
        // window props
        this.set_focus_on_map(true);
        this.set_title((_("Set text color")));
        this.destroy.connect(Gtk.main_quit);
        this.set_skip_taskbar_hint(true);
        // colorchooser
        color = new Gtk.ColorChooserWidget();
        color.use_alpha = false;
        color.show_editor = true;
        maingrid.attach(color, 0, 0, 1, 10);
        // rgb spinbox grids
        var spinboxgrid = new Gtk.Grid();
        maingrid.attach(spinboxgrid, 1, 0, 1, 1);
        spinboxgrid.set_column_homogeneous(true);
        // spinbuttons - labels
        int index = 0;
        string[] rgblabels = {(_("Red")), (_("Green")), (_("Blue"))};
        foreach (string s in rgblabels) {
            Label l = new Gtk.Label(s + ":");
            l.set_xalign(0);
            spinboxgrid.attach(l, 0, index, 1, 1);
            index += 1;
        }
        // spinbuttons - buttons rgb
        redbutton = new Gtk.SpinButton.with_range (0, 255, 1);
        redbutton.value_changed.connect(get_fromrgbspins);
        spinboxgrid.attach(redbutton, 1, 0, 1, 1);
        greenbutton = new Gtk.SpinButton.with_range (0, 255, 1);
        greenbutton.value_changed.connect(get_fromrgbspins);
        spinboxgrid.attach(greenbutton, 1, 1, 1, 1);
        bluebutton = new Gtk.SpinButton.with_range (0, 255, 1);
        bluebutton.value_changed.connect(get_fromrgbspins);
        spinboxgrid.attach(bluebutton, 1, 2, 1, 1);
        // Choose / Cancel
        var buttonbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        maingrid.attach(buttonbox, 1, 11, 1, 1);
        var apply_button = new Gtk.Button.with_label((_("Choose")));
        apply_button.clicked.connect(update_gsettings);
        apply_button.set_size_request(100, 10);
        buttonbox.pack_end(apply_button, false, false, 0);
        var cancel_button = new Gtk.Button.with_label((_("Cancel")));
        cancel_button.clicked.connect( () => {
            Gtk.main_quit();
        });
        cancel_button.set_size_request(100, 10);
        buttonbox.pack_end(cancel_button, false, false, 0);
        // initiate to prevent nagging
        red1 = 0.0;
        green1 = 0.0;
        blue1 = 0.0;

        GLib.Timeout.add (40, () => {
            Gdk.RGBA newcolor = color.get_rgba();
            red2 = newcolor.red;
            green2 = newcolor.green;
            blue2 = newcolor.blue;
            bool test = !(red2 == red1 && green2 == green1 && blue2 == blue1);
            if (test == true) {
                // update rgb spinboxes
                redbutton.set_value((int)round((red2 * 255)));
                greenbutton.set_value((int) round((green2 * 255)));
                bluebutton.set_value((int)round((blue2 * 255)));
            }
            red1 = red2; green1 = green2; blue1 = blue2;
            return true;
        });
        get_currgsettings();
        this.show_all();
        Gtk.main();
    }

    private void update_gsettings (Button button) {
        string[] new_arr = {};
        int[] newcolor = get_newcolor();
        foreach (int c in newcolor) {
            new_arr += c.to_string();
        }
        settings.set_strv("textcolor", new_arr);
        Gtk.main_quit();
    }

    private void get_currgsettings() {
        // set initial gui according to gsettings
        int[] cvals = {};
        string[] rgbvals = settings.get_strv("textcolor");
        foreach (string s in rgbvals) {
            cvals += int.parse(s);
        }
        redbutton.set_value(cvals[0]);
        greenbutton.set_value(cvals[1]);
        bluebutton.set_value(cvals[2]);
    }

    private int[] get_newcolor () {
        int redval = (int) redbutton.get_value();
        int greenval = (int) greenbutton.get_value();
        int blueval = (int) bluebutton.get_value();
        return {redval, greenval, blueval};
    }

    private void get_fromrgbspins (SpinButton button) {
        int[] ncolor = get_newcolor();
        Gdk.RGBA setcolor = Gdk.RGBA () {
            red = ncolor[0]/255.0,
            green = ncolor[1]/255.0,
            blue = ncolor[2]/255.0,
            alpha = 1
        };
        color.set_rgba(setcolor);
    }

    public void initialiseLocaleLanguageSupport() {
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


public int main(string[] args) {
    Gtk.init(ref args);
    new ColorPicker();
    return 0;
}
