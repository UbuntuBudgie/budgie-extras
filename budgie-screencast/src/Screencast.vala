/*
* Budgie Screencast
* Author: Sam Lane
* Copyright © 2026 Ubuntu Budgie Developers
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

using RecorderControl;

namespace ScreencastApplet {

    private string? default_path;

    public class ScreencastSettings : Gtk.Grid {
        GLib.Settings? settings = null;

        public ScreencastSettings(GLib.Settings? settings) {
            this.settings = settings;
            string? save_path = settings.get_string("save-path");
            if (!is_valid_folder(save_path)) {
                save_path = default_path;
            }

            set_column_spacing(10);

            Gtk.Label select_label = new Gtk.Label(_("Output folder:"));
            select_label.set_halign(Gtk.Align.START);
            attach(select_label, 0, 0, 2, 1);

            var folderbutton = new Gtk.Button.from_icon_name("folder", Gtk.IconSize.BUTTON);
            folderbutton.set_hexpand(false);
            attach(folderbutton, 0, 1, 1, 1);

            Gtk.Label path_label = new Gtk.Label(save_path);
            path_label.set_width_chars(30);
            path_label.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
            path_label.set_xalign(0.0f); 
            path_label.hexpand = true;
            attach(path_label, 1,1,1,1);


            folderbutton.clicked.connect(() => {
                var folder_chooser = new Gtk.FileChooserDialog(_("Select Recording Folder"),
                    null, Gtk.FileChooserAction.SELECT_FOLDER);
                folder_chooser.add_button(_("_Cancel"), Gtk.ResponseType.CANCEL);
                folder_chooser.add_button(_("_Select"), Gtk.ResponseType.ACCEPT);
                folder_chooser.set_modal(true);
                folder_chooser.set_current_folder(save_path);

                if (folder_chooser.run() == Gtk.ResponseType.ACCEPT) {
                    string? chosen = folder_chooser.get_filename();
                    if (chosen != null && is_valid_folder(chosen)) {
                        settings.set_string("save-path", chosen);
                        save_path = chosen;
                        path_label.set_text(save_path);
                    }
                }
                folder_chooser.destroy();
            });
            show_all();
        }
    }


    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget(string uuid) {
            default_path = Environment.get_user_special_dir(UserDirectory.VIDEOS);
                if (default_path == null) {
                    default_path = Environment.get_home_dir();
                }
            return new ScreencastApplet(uuid);
        }
    }


    public class ScreencastPopover : Budgie.Popover {
        private Gtk.Grid maingrid;
        private Gtk.Box output_box;
        private Gtk.Label select_label;
        public string active = "";
        private libxfce4windowing.Screen screen;
        
        public ScreencastPopover(Gtk.EventBox panel_widget) {
            GLib.Object(relative_to: panel_widget);
            screen = libxfce4windowing.Screen.get_default();
            
            // Need to watch for added or removed monitors and update the list
            screen.monitor_added.connect((monitor) => {
                generate_outputs();
            });
            screen.monitor_removed.connect((monitor) => {
                string removed = monitor.get_connector();
                if (removed == active) {
                    /*if we remove the currently selected display, need to clear this so
                      a new display can be selected when we regenerate the radio buttons
                    */
                    active = "";
                }
                generate_outputs();
            });

            maingrid = new Gtk.Grid();
            select_label = new Gtk.Label(_("Record Display:"));
            maingrid.attach(select_label, 0, 0, 1, 1);
            maingrid.attach(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), 0, 1, 1, 1);
            output_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            output_box.set_size_request(150, -1);
            maingrid.attach(output_box, 0, 2, 1, 1);
            this.add(this.maingrid);
            generate_outputs();
        }

        public void generate_outputs() {
            // rebuild the list of display outputs
            string[] current_outputs = get_output_list();
            foreach (Gtk.Widget child in output_box.get_children()) {
                output_box.remove(child);
                child.destroy();
            }
            
            Gtk.RadioButton? first = null;
            foreach (string output in current_outputs) {
                if (active == "") {
                    // no display has been selected or selected display was removed
                    active = output;
                }
                var radio = new Gtk.RadioButton.with_label_from_widget(first, output);
                if (first == null) {
                    first = radio;
                }
                if (output == active) {
                    // need to remember currently selected display when displays change
                    radio.set_active(true);
                }
                radio.toggled.connect (() => {
                    if (radio.active) {
                        active = radio.label;
                    }
                });
                output_box.pack_start(radio, false, false, 0);
                output_box.show_all();
            }
        }

        public string? get_selected_output() {
            return active;
        }

        private string[] get_output_list() {
            string[] current_outputs = {};
            if (screen == null) {
                warning("No displays found\n");
                return current_outputs;
            }
            unowned GLib.List<libxfce4windowing.Monitor> monitors = screen.get_monitors();
            for (unowned GLib.List<libxfce4windowing.Monitor>? m = monitors; m != null; m = m.next) {
                var monitor = m.data;
                if (monitor == null) continue;
                var connector = monitor.get_connector();
                current_outputs += connector;
            }
            return current_outputs;
        }
    }


    public class ScreencastApplet : Budgie.Applet {

        private ScreencastIcon panel_widget;
        private ScreencastPopover popover = null;
        private GLib.Settings? settings;
        private unowned Budgie.PopoverManager? manager = null;
        public string uuid { public set; public get; }
        private Recorder recorder_app;

        public ScreencastApplet(string uuid) {
            Object(uuid: uuid);

            initialiseLocaleLanguageSupport();
            recorder_app = new Recorder();

            this.settings_schema = "org.ubuntubudgie.budgie-screencast";
            this.settings_prefix = "/com/solus-project/budgie-panel/instance/budgie-screencast";
            this.settings = this.get_applet_settings(uuid);
            this.settings.changed["save-path"].connect (()=> {
                string save_path = this.settings.get_string("save-path");
                if (is_valid_folder(save_path)) {
                    recorder_app.set_save_path(save_path);
                }
            });

            string save_path = this.settings.get_string("save-path");
            if (!is_valid_folder(save_path)) {
                save_path = default_path;
            }
            recorder_app.set_save_path(save_path);
            show_all();

            panel_widget = new ScreencastIcon();
            add(panel_widget);

            recorder_app.recording_changed.connect((rec) => {
                panel_widget.set_recording(rec);
            });

            popover = new ScreencastPopover(panel_widget);
            panel_widget.button_press_event.connect((e)=> {
                if (e.button == 1) {
                    // We will start / stop recording on a left click
                    string selected_output = popover.get_selected_output();
                    if (selected_output != "")
                        recorder_app.toggle(selected_output);
                    return Gdk.EVENT_STOP;
                }
                if (popover.get_visible()) {
                    popover.hide();
                } else {
                    // We will show the display popover on right / middle click
                    this.manager.show_popover(panel_widget);
                }
                return Gdk.EVENT_STOP;
            });
            popover.get_child().show_all();

        }

        public override bool supports_settings() {
            return true;
        }

        public override Gtk.Widget? get_settings_ui() {
            return new ScreencastSettings(this.get_applet_settings(uuid));
        }

        public override void update_popovers(Budgie.PopoverManager? manager) {
            this.manager = manager;
            manager.register_popover(panel_widget, popover);
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

    private bool is_valid_folder(string path) {
        // we want to make sure there is a folder selected and it is real
        if (path == null || path.strip() == "") {
            return false;
        }
        File file = File.new_for_path(path);
        if (!file.query_exists()) {
            return false;
        }
        FileType type = file.query_file_type(FileQueryInfoFlags.NONE, null);
        return type == FileType.DIRECTORY;
    }
}


[ModuleInit]
public void peas_register_types(TypeModule module){
    /* boilerplate - all modules need this */
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(ScreencastApplet.Plugin)
    );
}
