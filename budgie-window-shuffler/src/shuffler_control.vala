using Gtk;
using Math;

// valac --pkg gtk+-3.0

/*
Budgie Window Shuffler II
Author: Jacob Vlijm
Copyright © 2017-2020 Ubuntu Budgie Developers
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


namespace ShufflerControls {

    //  GLib.Settings wallstreet_settings;
    GLib.Settings shuffler_settings;

    class ControlsWindow : Gtk.Window {

        SpinButton columns_spin;
        SpinButton rows_spin;
        ToggleButton toggle_gui;
        ToggleButton toggle_shuffler;
        ToggleButton toggle_swapgeo;
        //  string runinstruction;
        Label expl_label;
        Label warninglabel;
        Gtk.Grid supergrid;
        Stack controlwin_stack;

        public ControlsWindow () {

            // STRINGS & THINGS
            // settings
            string daemonexpl = (_("Enable tiling and window move shortcuts")) + ":";
            string guiexpl = (_("Enable grid tiling GUI shortcut"));
            string swapgeexpl = (_("When using move shortcuts, swap window geometry if a window moves to an existing window's position"));
            string default_expl = (_("Move the mouse over a button for an explanation"));
            string cols_expl = (_("Number of grid columns, used by GUI grid-, move- and tile-all shortcuts"));
            string rows_expl = (_("Number of grid rows, used by GUI grid, move- and tile-all shortcuts"));
            // tiling
            string qtiling_header = (_("Shortcuts for quarter and half tiling & tiling to grid")) +":";
            string topleft = "Ctrl + Alt + 7".concat("\t\t\t\t", (_("Top-left")));
            string topright = "Ctrl + Alt + 9".concat("\t\t\t\t", (_("Top-right")));
            string bottomright = "Ctrl + Alt + 3".concat("\t\t\t\t", (_("Bottom-right")));
            string bottomleft = "Ctrl + Alt + 1".concat("\t\t\t\t", (_("Top-left")));
            string lefthalf = "Ctrl + Alt + 4".concat("\t\t\t\t", (_("Left-half")));
            string tophalf = "Ctrl + Alt + 8".concat("\t\t\t\t", (_("Top-half")));
            string rightthalf = "Ctrl + Alt + 6".concat("\t\t\t\t", (_("Right-half")));
            string bottomhalf = "Ctrl + Alt + 2".concat("\t\t\t\t", (_("Bottom-half")));
            string tileall = "Control + Super + A".concat("\t\t", (_("Tile all windows to grid")));
            // Jump & resize
            string jump_header = (_("Shortcuts for moving to the nearest grid cell")) + ":";
            string jumpleft = "Super + Alt + ←".concat("\t\t", (_("Move left")));
            string jumpright = "Super + Alt + →".concat("\t\t", (_("Move right")));
            string jumpup = "Super + Alt + ↑".concat("\t\t", (_("Move up")));
            string jumpdown = "Super + Alt + ↓".concat("\t\t", (_("Move down")));

            string resize_header = (_("Shortcuts for resizing windows on grid")) + ":";
            string addhorizontally = "Control + Super + →".concat("\t\t", (_("Expand horizontally (to the right)")));
            string shrinkhorizontally = "Control + Super + ←".concat("\t\t", (_("Shrink horizontally (from the right)")));
            string addvertically = "Control + Super + ↓".concat("\t\t", (_("Expand vertically (down)")));
            string shrinkvertically = "Control + Super + ↑".concat("\t\t", (_("Shrink vertically (from the bottom)")));

            string addhorizontally_br = "Control + Super + Alt + ←".concat("\t", (_("Expand horizontally (to the left)")));
            string shrinkhorizontally_br = "Control + Super + Alt + →".concat("\t", (_("Shrink horizontally (from the left)")));
            string addvertically_br = "Control + Super + Alt + ↑".concat("\t", (_("Expand vertically (up)")));
            string shrinkvertically_br = "Control + Super + Alt + ↓".concat("\t", (_("Shrink vertically (from the top)")));
            // GUI grid
            string guigrid_header = (_("Shortcuts for the grid GUI")) + ":";
            string callgrid = "Ctrl + Alt + S".concat("\t", (_("Call the grid GUI")));
            string addcol = "→".concat("\t\t\t", (_("Add a column")));
            string addrow = "↓".concat("\t\t\t",(_("Add a row")));
            string remcol = "←".concat("\t\t\t", (_("Remove a column")));
            string remrow = "↑".concat("\t\t\t", (_("Remove a row")));
            string shift_click = (_("To select a range of tiles, use Shift + click"));
            string set_greyshade = (_("Set the shade of gray for the grid")) + ":";
            string lighter = (_("Press + or scroll up to lighten the grid shade"));
            string darker = (_("Press - or scroll down to darken the grid shade"));


            // WINDOW STUFF
            string shufflercontrols_stylecss = """
            .explanation {
                font-style: italic;
            }
            .stackbuttons {
                border-radius: 0px 0px 0px 0px;
            }
            .stackbuttonleft {
                border-radius: 8px 0px 0px 8px;
            }
            .stackbuttonright{
                border-radius: 0px 8px 8px 0px;
            }
            .header {
                font-weight: bold;
            }
            .warning {
                color: red;
            }
            """;

            // window basics
            this.set_default_size(10, 10);
            //this.set_resizable(false);
            initialiseLocaleLanguageSupport();
            this.set_position(Gtk.WindowPosition.CENTER);
            this.title = (_("Window Shuffler Control"));

            // lay out essential window elements
            supergrid = new Gtk.Grid();
            this.add(supergrid);
            controlwin_stack = new Stack();
            controlwin_stack.set_transition_type(
                Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
            );
            var settingsgrid = new Gtk.Grid();
            controlwin_stack.add_named(settingsgrid, "settings");
            var shortcutsgrid = new Gtk.Grid();
            controlwin_stack.add_named(shortcutsgrid, "qhshortcuts");
            var jumpgrid = new Gtk.Grid();
            controlwin_stack.add_named(jumpgrid, "jumpshortcuts");
            var guigrid = new Gtk.Grid();
            controlwin_stack.add_named(guigrid, "guigrid");

            // SUPERGRID
            supergrid.attach(new Label("\n"), 0, 2, 1, 1);
            set_margins(supergrid);
            make_headerbutton ((_("Settings")), "stackbuttonleft", 1, "settings");
            make_headerbutton ((_("Tiling")), "stackbuttons", 2, "qhshortcuts");
            make_headerbutton ((_("Move & resize")), "stackbuttons", 3, "jumpshortcuts");
            make_headerbutton ((_("GUI grid")), "stackbuttonright", 4, "guigrid");

            // STACK-PAGES
            // 1. settingsgrid - checkbuttons
            toggle_shuffler = new Gtk.CheckButton.with_label(
                (_("Enable Window Shuffler"))
            );
            settingsgrid.attach(toggle_shuffler, 1, 1, 1, 1);
            toggle_gui = new Gtk.CheckButton.with_label(
                (_("Enable Window Shuffler grid GUI"))
            );
            settingsgrid.attach(toggle_gui, 1, 2, 1, 1);
            var givemesomespace = new Gtk.Label("");
            settingsgrid.attach(givemesomespace, 1, 3, 1, 1);
            toggle_swapgeo = new Gtk.CheckButton.with_label(
                (_("Swap geometry"))
            );
            settingsgrid.attach(toggle_swapgeo, 1, 4, 1, 1);
            var empty = new Label("");
            settingsgrid.attach(empty, 1, 12, 1, 1);
            // settingsgrid - spinbuttonsection
            var colslabel = new Label("\n" + (_("Grid GUI: columns & rows")) + "\n");
            colslabel.set_xalign(0);
            settingsgrid.attach(colslabel, 1, 13, 1, 1);
            var geogrid = new Gtk.Grid();
            settingsgrid.attach(geogrid, 1, 14, 2, 3);
            var columns_label = new Label((_("Columns")) + "\t");
            columns_label.set_xalign(0);
            geogrid.attach(columns_label, 0, 0, 1, 1);
            columns_spin = new Gtk.SpinButton.with_range(1, 10, 1);
            geogrid.attach(columns_spin, 1, 0, 1, 1);
            var rows_label = new Label((_("Rows")) + "\t");
            rows_label.set_xalign(0);
            geogrid.attach(rows_label, 0, 1, 1, 1);
            rows_spin = new Gtk.SpinButton.with_range(1, 10, 1);
            geogrid.attach(rows_spin, 1, 1, 1, 1);
            // settingsgrid - explanation section
            var empty2 = new Label("");
            geogrid.attach(empty2, 1, 20, 1, 1);
            // Prevent window bottom section from jumping: reserve space
            Gtk.Label expl_vertspace = new Gtk.Label("\n\n\n\n");
            settingsgrid.attach(expl_vertspace, 0, 21, 1, 1);
            // settingsgrid - explanation section & css provider
            Gdk.Screen screen = this.get_screen();
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data(shufflercontrols_stylecss);
                Gtk.StyleContext.add_provider_for_screen(
                    screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
            }
            catch (Error e) {
            }

            expl_label = new Gtk.Label(default_expl);
            expl_label.set_xalign(0);
            expl_label.set_line_wrap(true);
            settingsgrid.attach(expl_label, 1, 21, 99, 1);
            set_textstyle(expl_label, {"explanation"});

            // settingsgrid - bottomsection
            var okbox = new Box(Gtk.Orientation.HORIZONTAL, 0);
            var ok_button = new Button.with_label((_("Close")));
            ok_button.set_size_request(100, 5);
            okbox.pack_end(ok_button, false, false, 0);
            warninglabel = new Label("");
            warninglabel.set_xalign(0);
            supergrid.attach(warninglabel, 1, 99, 2, 1);
            supergrid.attach(okbox, 2, 99, 4, 1);
            ok_button.clicked.connect(Gtk.main_quit);
            this.destroy.connect(Gtk.main_quit);

            toggle_shuffler.enter_notify_event.connect(() => {
                expl_label.set_text(daemonexpl);
                return false;
            });
            toggle_shuffler.leave_notify_event.connect(() => {
                expl_label.set_text(default_expl);
                return false;
            });
            toggle_gui.enter_notify_event.connect(() => {
                expl_label.set_text(guiexpl);
                return false;
            });
            toggle_gui.leave_notify_event.connect(() => {
                expl_label.set_text(default_expl);
                return false;
            });
            toggle_swapgeo.enter_notify_event.connect(() => {
                expl_label.set_text(swapgeexpl);
                return false;
            });
            toggle_swapgeo.leave_notify_event.connect(() => {
                expl_label.set_text(default_expl);
                return false;
            });
            columns_spin.enter_notify_event.connect(() => {
                expl_label.set_text(cols_expl);
                return false;
            });
            columns_spin.leave_notify_event.connect(() => {
                expl_label.set_text(default_expl);
                return false;
            });
            rows_spin.enter_notify_event.connect(() => {
                expl_label.set_text(rows_expl);
                return false;
            });
            rows_spin.leave_notify_event.connect(() => {
                expl_label.set_text(default_expl);
                return false;
            });

            // 2. shortcutsgrid
            var qhshortcutsheader = new Label(qtiling_header);
            set_textstyle(qhshortcutsheader, {"header"});
            var spacer = new Label("");
            var tl = new Label(topleft);
            var tr = new Label(topright);
            var br = new Label(bottomright);
            var bl = new Label(bottomleft);
            var lh = new Label(lefthalf);
            var th = new Label(tophalf);
            var rh = new Label(rightthalf);
            var bh = new Label(bottomhalf);
            var space4 = new Label("");
            var ta = new Label(tileall);
            Label[] qhshortc_labels = {
                qhshortcutsheader, spacer, tl, tr, br, bl, lh, th, rh, bh, space4, ta
            };
            int n = 1;
            foreach (Label l in qhshortc_labels) {
                l.set_xalign(0);
                shortcutsgrid.attach(l, 0, n, 1, 1);
                n += 1;
            }

            // 3. jumpgrid shortcuts
            var jumpshortcutsheader = new Label(jump_header);
            set_textstyle(jumpshortcutsheader, {"header"});
            var spacer2 = new Label("");
            var jump_left = new Label(jumpleft);
            var jump_right = new Label(jumpright);
            var jump_up = new Label(jumpup);
            var jump_down = new Label(jumpdown);
            Label[] jumpshortc_labels = {
                jumpshortcutsheader, spacer2, jump_left, jump_right, jump_up, jump_down
            };
            int n2 = 1;
            foreach (Label l in jumpshortc_labels) {
                l.set_xalign(0);
                jumpgrid.attach(l, 0, n2, 1, 1);
                n2 += 1;
            }
            jumpgrid.attach(new Label(""), 0, 9, 1, 1);
            var resizeheader = new Label(resize_header);
            set_textstyle(resizeheader, {"header"});
            var spacer4 = new Label("");
            var add_horizontally = new Label(addhorizontally);
            var shrink_horizontally = new Label(shrinkhorizontally);
            var add_vertically = new Label(addvertically);
            var shrink_vertically = new Label(shrinkvertically);

            var add_horizontally_br = new Label(addhorizontally_br);
            var shrink_horizontally_br = new Label(shrinkhorizontally_br);
            var add_vertically_br = new Label(addvertically_br);
            var shrink_vertically_br = new Label(shrinkvertically_br);

            Label[] resizeshortc_labels = {
                resizeheader, spacer4, add_horizontally, shrink_horizontally,
                add_vertically, shrink_vertically, add_horizontally_br,
                shrink_horizontally_br, add_vertically_br, shrink_vertically_br
            };
            n2 = 10;
            foreach (Label l in resizeshortc_labels) {
                l.set_xalign(0);
                jumpgrid.attach(l, 0, n2, 1, 1);
                n2 += 1;
            }
            // 4. guigrid
            var guigridheader = new Label(guigrid_header);
            set_textstyle(guigridheader, {"header"});
            var spacer3 = new Label("");
            var call_grid = new Label(callgrid);
            var add_col = new Label(addcol);
            var add_row = new Label(addrow);
            var rem_col = new Label(remcol);
            var rem_row = new Label(remrow);
            Label[] guigrid_labels = {
                guigridheader, spacer3, call_grid, add_col, add_row, rem_col, rem_row
            };
            int n3 = 1;
            foreach (Label l in guigrid_labels) {
                l.set_xalign(0);
                guigrid.attach(l, 0, n3, 1, 1);
                n3 += 1;
            }
            guigrid.attach(new Gtk.Label(""), 0, 20, 1, 1);
            var shiftclick = new Label(shift_click);
            shiftclick.set_xalign(0);
            guigrid.attach(shiftclick, 0, 21, 1, 1);
            guigrid.attach(new Gtk.Label(""), 0, 22, 1, 1);
            var greyshade_header = new Label(set_greyshade);
            greyshade_header.set_xalign(0);
            set_textstyle(greyshade_header, {"header"});
            guigrid.attach(greyshade_header, 0, 23, 1, 1);
            guigrid.attach(new Gtk.Label(""), 0, 24, 1, 1);
            var lighter_label = new Label(lighter);
            lighter_label.set_xalign(0);
            lighter_label.set_line_wrap(true);
            var darker_label = new Label(darker);
            darker_label.set_xalign(0);
            darker_label.set_line_wrap(true);
            guigrid.attach(lighter_label, 0, 25, 1, 1);
            guigrid.attach(darker_label, 0, 26, 1, 1);
            supergrid.attach(controlwin_stack, 1, 3, 4, 1);
            controlwin_stack.set_visible_child_name("settings");
            // get stuff
            get_currsettings();
            // connect stuff
            columns_spin.value_changed.connect(set_grid);
            rows_spin.value_changed.connect(set_grid);
            toggle_shuffler.toggled.connect(manage_boolean);
            toggle_gui.toggled.connect(manage_boolean);
            toggle_swapgeo.toggled.connect(manage_boolean);

            this.show_all();
        }

        private Gtk.Button make_headerbutton (string name, string style, int pos, string target) {
            var stackbutton = new Gtk.Button.with_label(name);
            set_buttonstyle(stackbutton, style);
            supergrid.attach(stackbutton, pos, 1, 1, 1);
            stackbutton.set_size_request(120, 10);
            stackbutton.clicked.connect(() => {
                controlwin_stack.set_visible_child_name(target);
            });
            return stackbutton;
        }

        private void set_buttonstyle (Gtk.Button b, string style) {
            var sct = b.get_style_context();
            sct.add_class(style);
        }

        private void set_textstyle (Gtk.Label l, string[] style) {
            var sct = l.get_style_context();
            string[] style_old = {"warning", "explanation", "header"};
            foreach (string s_old in style_old) {
                sct.remove_class(s_old);
            }
            foreach (string s in style) {
                sct.add_class(s);
            }
        }

        /**
        * Ensure translations are displayed correctly
        * according to the locale
        */

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

        private void get_currsettings () {
            bool currentlyactive = shuffler_settings.get_boolean("runshuffler");
            toggle_shuffler.set_active(currentlyactive);
            toggle_gui.set_sensitive(currentlyactive);
            toggle_swapgeo.set_sensitive(currentlyactive);
            toggle_gui.set_active(shuffler_settings.get_boolean("runshufflergui"));
            toggle_swapgeo.set_active(shuffler_settings.get_boolean("swapgeometry"));
            columns_spin.set_value(shuffler_settings.get_int("cols"));
            rows_spin.set_value(shuffler_settings.get_int("rows"));
        }

        private void manage_boolean (ToggleButton button) {
            int n = 0;
            string match = "";
            bool newval = button.get_active();
            ToggleButton[] toggles = {
                toggle_gui, toggle_shuffler, toggle_swapgeo
            };
            string[] vals = {
                "runshufflergui", "runshuffler", "swapgeometry"
            };
            foreach (ToggleButton b in toggles) {
                if (b == button) {
                    match = vals[n];
                    break;
                }
                n += 1;
            }
            shuffler_settings.set_boolean(match, newval);
            if (n == 1) {
                if (!newval) {
                    toggle_gui.set_active(newval);
                    warninglabel.set_label("");
                }
                else {
                    check_firstrunwarning();
                }
                toggle_gui.set_sensitive(newval);
                toggle_swapgeo.set_sensitive(newval);
            }
        }

        private void set_grid (SpinButton b) {
            SpinButton[] sp_buttons = {
                columns_spin, rows_spin
            };
            string[] vals = {
                "cols", "rows"
            };
            int newval = (int)b.get_value();
            string match = "";
            int n = 0;
            foreach (SpinButton sb in sp_buttons) {
                if (sb == b) {
                    match = vals[n];
                    break;
                }
                n += 1;
            }
            shuffler_settings.set_int(match, newval);
        }

        private void set_margins (Grid grid) {
            int[,] corners = {
                {0, 0}, {100, 0}, {2, 0}, {0, 100}, {100, 100}
            };
            int lencorners = corners.length[0];
            for (int i=0; i < lencorners; i++) {
                var spacelabel = new Label("\t");
                grid.attach(
                    spacelabel, corners[i, 0], corners[i, 1], 1, 1
                );
            }
        }

        private void check_firstrunwarning() {
            /*
            / 0.1 dec after gsettings change check if process is running
            / if not -> show message in label
            */
            GLib.Timeout.add(100, () => {
                bool daemonruns = procruns("windowshufflerdaemon");
                if (!daemonruns) {
                    warninglabel.set_label(_("Please log out/in to initialize"));
                    set_textstyle(warninglabel, {"warning", "explanation"});

                }
                return false;
            });
        }

        private bool procruns (string processname) {
            string cmd = @"pgrep -f $processname";
            string output;
            try {
                GLib.Process.spawn_command_line_sync(cmd, out output);
                if (output == "") {
                    return false;
                }
            }
            /* on an unlike to happen exception, return true */
            catch (SpawnError e) {
                return true;
            }
            return true;
        }
    }

    public static int main (string[] args) {
        Gtk.init(ref args);
        shuffler_settings = new GLib.Settings(
            "org.ubuntubudgie.windowshuffler"
        );
        new ControlsWindow();
        Gtk.main();
        return 0;
    }
}
