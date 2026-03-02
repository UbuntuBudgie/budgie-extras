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

    // ── Delay presets ─────────────────────────────────────────────────────────
    // Values in seconds; 0 means no delay (immediate start).
    // Labels are compact numeric strings — not user-prose — so they are
    // intentionally left untranslated. "Off" is the sole exception and is
    // handled inline where the label is used.
    private const int[]    DELAY_PRESETS = { 0, 5, 10, 20, 30 };
    private const string[] DELAY_LABELS  = { "Off", "5s", "10s", "20s", "30s" };

    // ── Duration presets ──────────────────────────────────────────────────────
    // Values in seconds; 0 means unlimited (manual stop).
    // Cut-off points are chosen to match the practical upload limits of common
    // social media platforms:
    //   TikTok:           15 s, 60 s, 3 min, 10 min
    //   Instagram Reels:  15 s, 30 s, 60 s, 90 s
    //   YouTube Shorts:   60 s
    //   LinkedIn/Facebook 3 min

    private const int[]    DURATION_PRESETS = {  0,  15,  30,  60,  90, 180,  600 };
    private const string[] DURATION_LABELS  = { "∞", "15s", "30s", "1m", "90s", "3m", "10m" };

    // Returns a freshly-translated copy of the duration tooltip strings.
    private string[] get_duration_tips () {
        return {
            // translators: tooltip for the "no time limit" duration button
            _("No limit"),
            // translators: tooltip for the 15-second duration button; shown alongside social platform names
            _("TikTok / Reels short"),
            // translators: tooltip for the 30-second duration button
            _("Reels / Shorts standard"),
            // translators: tooltip for the 60-second duration button
            _("TikTok / YouTube Shorts / Reels"),
            // translators: tooltip for the 90-second duration button; Instagram's maximum Reel length
            _("Instagram max"),
            // translators: tooltip for the 3-minute duration button
            _("LinkedIn / Facebook"),
            // translators: tooltip for the 10-minute duration button; TikTok's current maximum
            _("TikTok max")
        };
    }


    // ── Settings UI ───────────────────────────────────────────────────────────
    // Shown in the Budgie panel settings dialog when the user clicks the
    // applet's gear icon. Currently only exposes the save-path preference;
    // all recording options live in the panel popover instead.

    public class ScreencastSettings : Gtk.Grid {
        GLib.Settings? settings = null;

        public ScreencastSettings (GLib.Settings? settings) {
            this.settings = settings;
            string? save_path = settings.get_string ("save-path");
            if (!is_valid_folder (save_path)) {
                save_path = default_path;
            }

            set_column_spacing (10);

            // translators: label for the output folder row in the settings panel
            Gtk.Label select_label = new Gtk.Label (_("Output folder:"));
            select_label.set_halign (Gtk.Align.START);
            attach (select_label, 0, 0, 2, 1);

            var folderbutton = new Gtk.Button.from_icon_name ("folder", Gtk.IconSize.BUTTON);
            folderbutton.set_hexpand (false);
            attach (folderbutton, 0, 1, 1, 1);

            Gtk.Label path_label = new Gtk.Label (save_path);
            path_label.set_width_chars (30);
            path_label.set_ellipsize (Pango.EllipsizeMode.MIDDLE);
            path_label.set_xalign (0.0f);
            path_label.hexpand = true;
            attach (path_label, 1, 1, 1, 1);

            folderbutton.clicked.connect (() => {
                // translators: title of the folder-chooser dialog
                var folder_chooser = new Gtk.FileChooserDialog (_("Select Recording Folder"),
                    null, Gtk.FileChooserAction.SELECT_FOLDER);
                // translators: cancel button in the folder-chooser dialog (underscore = keyboard accelerator)
                folder_chooser.add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
                // translators: confirm button in the folder-chooser dialog (underscore = keyboard accelerator)
                folder_chooser.add_button (_("_Select"), Gtk.ResponseType.ACCEPT);
                folder_chooser.set_modal (true);
                folder_chooser.set_current_folder (save_path);

                if (folder_chooser.run () == Gtk.ResponseType.ACCEPT) {
                    string? chosen = folder_chooser.get_filename ();
                    if (chosen != null && is_valid_folder (chosen)) {
                        settings.set_string ("save-path", chosen);
                        save_path = chosen;
                        path_label.set_text (save_path);
                    }
                }
                folder_chooser.destroy ();
            });
            show_all ();
        }
    }


    // ── Plugin ────────────────────────────────────────────────────────────────
    // Boilerplate entry point required by the Budgie/Peas plugin system.
    // Resolves the default save path once at load time so it is available to
    // both ScreencastSettings and ScreencastApplet without re-querying.

    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget (string uuid) {
            // Prefer the XDG Videos directory; fall back to $HOME if unset
            default_path = Environment.get_user_special_dir (UserDirectory.VIDEOS);
            if (default_path == null) {
                default_path = Environment.get_home_dir ();
            }
            return new ScreencastApplet (uuid);
        }
    }


    // ── Popover ───────────────────────────────────────────────────────────────
    // The right-click / middle-click popover that lets the user configure all
    // recording options before starting. All settings are saved to GSettings
    // immediately on change.
    //
    // Tooltips are implemented as polling Gtk.Popovers rather than set_tooltip_text()
    // because on Wayland the compositor cannot position system tooltips correctly
    // relative to layer-shell surfaces, and all event-driven hover approaches
    // (enter/leave/motion) cause feedback loops when the popover surface opens.
    // See attach_hover_popover().

    public class ScreencastPopover : Budgie.Popover {

        // ── Capture mode widgets ───────────────────────────────────────────
        private Gtk.ToggleButton screen_button;
        private Gtk.ToggleButton area_button;
        // Revealer slides the display list in/out when the mode changes
        private Gtk.Revealer     output_revealer;
        private Gtk.Box          output_box;

        // ── Preset button arrays ───────────────────────────────────────────
        // Kept as fields so the mutual-exclusion handler in make_preset_buttons
        // can iterate over sibling buttons by index.
        private Gtk.ToggleButton[] delay_buttons;
        private Gtk.ToggleButton[] duration_buttons;

        // ── Audio widgets ──────────────────────────────────────────────────
        private Gtk.ToggleButton audio_button;
        private Gtk.ComboBoxText  device_combo;
        // Revealer slides the device combo in/out when audio is toggled
        private Gtk.Revealer      audio_device_revealer;

        // ── Public state ───────────────────────────────────────────────────
        // Read by ScreencastApplet on each left-click to pass to the Recorder.
        public string      active           { get; private set; default = ""; }
        public CaptureMode capture_mode     { get; private set; default = CaptureMode.SCREEN; }
        public int         delay_seconds    { get; private set; default = 0; }
        public int         duration_seconds { get; private set; default = 0; }
        public bool        audio_enabled    { get; private set; default = false; }
        public string      audio_device     { get; private set; default = ""; }

        private libxfce4windowing.Screen screen;
        private GLib.Settings settings;

        public ScreencastPopover (Gtk.EventBox panel_widget, GLib.Settings settings) {
            GLib.Object (relative_to: panel_widget);
            this.settings = settings;
            screen = libxfce4windowing.Screen.get_default ();

            // Keep the display radio-button list in sync with hotplug events
            screen.monitor_added.connect   ((m) => { generate_outputs (); });
            screen.monitor_removed.connect ((m) => {
                // If the active display was removed, clear the selection so
                // generate_outputs() can pick a new default
                if (m.get_connector () == active) active = "";
                generate_outputs ();
            });

            var grid = new Gtk.Grid ();
            grid.set_row_spacing (6);
            grid.set_column_spacing (6);
            grid.set_margin_top (8);
            grid.set_margin_bottom (8);
            grid.set_margin_start (8);
            grid.set_margin_end (8);
            // Incremented each time a widget row is attached, keeping layout
            // changes local to the relevant section rather than requiring
            // renumbering of every subsequent row.
            int row = 0;

            // ── Capture mode ───────────────────────────────────────────────

            // translators: section label above the screen/area capture toggle buttons
            var mode_label = new Gtk.Label (_("Capture Mode:"));
            mode_label.set_halign (Gtk.Align.START);
            grid.attach (mode_label, 0, row++, 1, 1);

            // "linked" style class renders the two buttons as a single segmented control.
            // Centred in the popover with 32×32 buttons; DND-size icons (32 px) fill
            // the face without overwhelming the surrounding controls.
            var mode_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            mode_box.get_style_context ().add_class ("linked");
            mode_box.set_halign (Gtk.Align.CENTER);

            screen_button = new Gtk.ToggleButton ();
            screen_button.set_size_request (32, 32);
            screen_button.add (new Gtk.Image.from_icon_name ("video-display-symbolic", Gtk.IconSize.DND));
            // translators: tooltip for the "record entire display" capture mode button
            attach_hover_popover (screen_button, _("Record entire display"));

            area_button = new Gtk.ToggleButton ();
            area_button.set_size_request (32, 32);
            area_button.add (new Gtk.Image.from_icon_name ("object-select-symbolic", Gtk.IconSize.DND));
            // translators: tooltip for the "record selected area" capture mode button
            attach_hover_popover (area_button, _("Record selected area"));

            // Restore saved mode BEFORE connecting toggled signals to
            // prevent a spurious settings write during initialisation
            int saved_mode = settings.get_enum ("capture-mode");
            capture_mode = (saved_mode == 1) ? CaptureMode.AREA : CaptureMode.SCREEN;
            screen_button.set_active (capture_mode == CaptureMode.SCREEN);
            area_button.set_active   (capture_mode == CaptureMode.AREA);

            mode_box.pack_start (screen_button, false, false, 0);
            mode_box.pack_start (area_button,   false, false, 0);
            grid.attach (mode_box, 0, row++, 1, 1);

            // Mutual exclusion: activating one button deactivates the other.
            // The "else if" guards prevent both buttons ending up inactive if
            // the user clicks the already-active button.
            screen_button.toggled.connect (() => {
                if (screen_button.get_active ()) {
                    area_button.set_active (false);
                    capture_mode = CaptureMode.SCREEN;
                    settings.set_enum ("capture-mode", 0);
                    output_revealer.set_reveal_child (true);
                } else if (!area_button.get_active ()) {
                    screen_button.set_active (true);
                }
            });

            area_button.toggled.connect (() => {
                if (area_button.get_active ()) {
                    screen_button.set_active (false);
                    capture_mode = CaptureMode.AREA;
                    settings.set_enum ("capture-mode", 1);
                    output_revealer.set_reveal_child (false);
                } else if (!screen_button.get_active ()) {
                    area_button.set_active (true);
                }
            });

            // ── Display list ───────────────────────────────────────────────
            // Only meaningful in SCREEN mode; hidden via Revealer in AREA mode.

            // translators: label above the list of connected display outputs to record
            var display_label = new Gtk.Label (_("Record Display:"));
            display_label.set_halign (Gtk.Align.START);

            output_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            output_box.set_size_request (180, -1);

            var output_inner = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            output_inner.pack_start (display_label, false, false, 0);
            output_inner.pack_start (output_box,    false, false, 0);

            output_revealer = new Gtk.Revealer ();
            output_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
            output_revealer.set_transition_duration (200);
            // Initial state must match the restored capture mode; no animation at startup
            output_revealer.set_reveal_child (capture_mode == CaptureMode.SCREEN);
            output_revealer.add (output_inner);
            grid.attach (output_revealer, 0, row++, 1, 1);

            // ── Audio ──────────────────────────────────────────────────────

            // The audio row places the icon button immediately beside the label,
            // both left-aligned, so they read together as a unit.
            var audio_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            audio_button = new Gtk.ToggleButton ();
            audio_button.add (new Gtk.Image.from_icon_name ("audio-input-microphone-symbolic",
                                                             Gtk.IconSize.BUTTON));
            // translators: tooltip for the microphone toggle button that enables/disables audio capture
            attach_hover_popover (audio_button, _("Toggle audio capture"));

            // translators: label for the audio capture toggle row
            var audio_label = new Gtk.Label (_("Record Audio:"));
            audio_label.set_halign (Gtk.Align.START);

            audio_row.pack_start (audio_button, false, false, 0);
            audio_row.pack_start (audio_label,  false, false, 0);
            grid.attach (audio_row, 0, row++, 1, 1);

            // Device selector slides in below the toggle when audio is enabled
            device_combo = new Gtk.ComboBoxText ();
            // translators: tooltip for the dropdown that selects the audio input device to record from
            attach_hover_popover (device_combo, _("Audio source device"));

            audio_device_revealer = new Gtk.Revealer ();
            audio_device_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
            audio_device_revealer.set_transition_duration (200);
            audio_device_revealer.add (device_combo);
            grid.attach (audio_device_revealer, 0, row++, 1, 1);

            // Restore saved audio state BEFORE wiring signals (same reason
            // as the capture mode restore above)
            audio_enabled = settings.get_boolean ("audio-enabled");
            audio_device  = settings.get_string  ("audio-device");
            audio_button.set_active (audio_enabled);
            audio_device_revealer.set_reveal_child (audio_enabled);

            // Pre-populate the combo if audio is already on so the saved device
            // is selected immediately without the user having to toggle
            if (audio_enabled) {
                populate_device_combo ();
            }

            audio_button.toggled.connect (() => {
                audio_enabled = audio_button.get_active ();
                settings.set_boolean ("audio-enabled", audio_enabled);
                audio_device_revealer.set_reveal_child (audio_enabled);
                // Re-enumerate sources each time the panel opens so newly
                // connected devices (e.g. USB headsets) appear without a restart
                if (audio_enabled) {
                    populate_device_combo ();
                }
            });

            device_combo.changed.connect (() => {
                string? chosen = device_combo.get_active_id ();
                // The "System default" entry has an empty-string ID; treat null
                // the same way in case the combo has no active item
                audio_device = (chosen != null) ? chosen : "";
                settings.set_string ("audio-device", audio_device);
            });

            // ── Start Delay ────────────────────────────────────────────────

            // translators: label above the row of delay preset buttons (e.g. Off / 5s / 10s …)
            var delay_label = new Gtk.Label (_("Start Delay:"));
            delay_label.set_halign (Gtk.Align.START);
            grid.attach (delay_label, 0, row++, 1, 1);

            int saved_delay = settings.get_int ("delay-seconds");
            // If the stored value does not match any preset (e.g. the user
            // edited dconf directly) fall back to the first preset (no delay)
            delay_seconds = find_nearest_preset (DELAY_PRESETS, saved_delay);

            var delay_box = make_preset_buttons (
                DELAY_PRESETS, DELAY_LABELS, null,
                delay_seconds, out delay_buttons,
                (val) => {
                    delay_seconds = val;
                    settings.set_int ("delay-seconds", val);
                });
            grid.attach (delay_box, 0, row++, 1, 1);

            // ── Record For (duration) ──────────────────────────────────────

            // translators: label above the row of duration preset buttons (e.g. ∞ / 15s / 30s …)
            var dur_label = new Gtk.Label (_("Record For:"));
            dur_label.set_halign (Gtk.Align.START);
            grid.attach (dur_label, 0, row++, 1, 1);

            int saved_dur    = settings.get_int ("duration-seconds");
            duration_seconds = find_nearest_preset (DURATION_PRESETS, saved_dur);

            var dur_box = make_preset_buttons (
                DURATION_PRESETS, DURATION_LABELS, get_duration_tips (),
                duration_seconds, out duration_buttons,
                (val) => {
                    duration_seconds = val;
                    settings.set_int ("duration-seconds", val);
                });
            grid.attach (dur_box, 0, row++, 1, 1);

            this.add (grid);
            generate_outputs ();
        }

        // ── Hover tooltip popovers ────────────────────────────────────────────
        // Standard GTK tooltips are positioned by the compositor using global
        // pointer coordinates. On Wayland, layer-shell surfaces (like Budgie
        // popovers) have no global position the compositor knows about, so
        // set_tooltip_text() places the tooltip at screen position (0,0) instead
        // of near the widget.
        //
        // The fix is a small Gtk.Popover per widget that we show/hide ourselves
        // on enter/leave-notify-event. Popovers are positioned relative to their
        // relative_to widget within the same surface, so they always appear
        // correctly anchored regardless of compositor coordinate translation.
        //
        // `delay_ms` defaults to 600 ms to feel like a native tooltip. A uint
        // source ID tracks the pending show timer so rapid mouse movement does
        // not stack multiple pending shows.

        // ── Hover tooltip popovers ────────────────────────────────────────────
        // Standard GTK tooltips are mis-positioned on Wayland layer-shell surfaces.
        // We use Gtk.Popover with a simple polling timer instead.
        //
        // The timer starts when the popover is first constructed and runs for the
        // widget's lifetime.

        // Returns true if the device pointer is currently within the widget's
        // on-screen bounding rectangle.
        private bool widget_pointer_over (Gtk.Widget widget) {
            var win = widget.get_window ();
            if (win == null) return false;
            int wx, wy;
            win.get_origin (out wx, out wy);
            Gtk.Allocation alloc;
            widget.get_allocation (out alloc);
            wx += alloc.x;
            wy += alloc.y;
            var seat = Gdk.Display.get_default ().get_default_seat ();
            int px, py;
            seat.get_pointer ().get_position (null, out px, out py);
            return px >= wx && px < wx + alloc.width &&
                   py >= wy && py < wy + alloc.height;
        }

        private void attach_hover_popover (Gtk.Widget widget, string text, uint delay_ms = 600) {
            var tip_label = new Gtk.Label (text);
            tip_label.set_margin_top (4);
            tip_label.set_margin_bottom (4);
            tip_label.set_margin_start (6);
            tip_label.set_margin_end (6);
            tip_label.show ();

            var tip_pop = new Gtk.Popover (widget);
            tip_pop.add (tip_label);
            tip_pop.set_position (Gtk.PositionType.BOTTOM);
            tip_pop.set_modal (false);

            // How many consecutive 100 ms ticks the pointer has been inside.
            // The tip appears once this reaches (delay_ms / TICK_MS).
            const uint TICK_MS   = 100;
            uint ticks_inside    = 0;
            uint ticks_threshold = delay_ms / TICK_MS;
            bool tip_visible     = false;

            Timeout.add (TICK_MS, () => {
                if (!widget.get_mapped ()) {
                    // Widget is off-screen; reset without touching the popover
                    ticks_inside = 0;
                    return true;
                }

                if (widget_pointer_over (widget)) {
                    ticks_inside++;
                    if (!tip_visible && ticks_inside >= ticks_threshold) {
                        tip_pop.popup ();
                        tip_visible = true;
                    }
                } else {
                    ticks_inside = 0;
                    if (tip_visible) {
                        tip_pop.popdown ();
                        tip_visible = false;
                    }
                }
                return true;  // repeat for widget lifetime
            });

            // Dismiss immediately on click; do not consume the event.
            widget.button_press_event.connect ((e) => {
                ticks_inside = 0;
                if (tip_visible) {
                    tip_pop.popdown ();
                    tip_visible = false;
                }
                return false;
            });
        }

        // ── Audio device enumeration ──────────────────────────────────────────
        // Queries PulseAudio/PipeWire for available source names via `pactl`.
        // Called each time the audio toggle is enabled so newly connected
        // devices appear without a panel restart.

        private void populate_device_combo () {
            string saved = audio_device;

            // Block the combo's `changed` signal while we rebuild its contents
            // to avoid triggering spurious settings writes for each item added.
            // We use block_matched with SignalMatchType.DATA rather than storing
            // a handler ID because the signal was connected via a lambda and
            // block_by_func is not usable with closures in Vala.
            SignalHandler.block_matched (device_combo, SignalMatchType.DATA,
                                        0, 0, null, null, null);
            device_combo.remove_all ();

            // translators: first entry in the audio device dropdown; lets wf-recorder choose the default PulseAudio/PipeWire source
            device_combo.append ("", _("System default"));

            foreach (string src in get_audio_sources ()) {
                // Device names from pactl are not translatable (they are
                // hardware identifiers such as "alsa_input.pci-0000_00_1f.3")
                device_combo.append (src, src);
            }

            // Restore the previously selected device; fall back to "System
            // default" (empty ID) if it is no longer present (e.g. unplugged)
            if (saved != "" && device_combo.set_active_id (saved)) {
                // set_active_id returns true when the ID was found and selected
            } else {
                device_combo.set_active_id ("");
                audio_device = "";
            }

            SignalHandler.unblock_matched (device_combo, SignalMatchType.DATA,
                                           0, 0, null, null, null);
            device_combo.show_all ();
        }

        // Runs `pactl list short sources` synchronously and parses the output
        // into a list of source name strings.
        // Output format per line: <index>\t<name>\t<module>\t<format>\t<state>
        // Returns an empty array if pactl is not found or returns an error.
        private string[] get_audio_sources () {
            string[] sources = {};
            string? pactl = Environment.find_program_in_path ("pactl");
            if (pactl == null) return sources;

            string stdout_buf = "";
            string stderr_buf = "";
            int    status     = 0;

            try {
                Process.spawn_command_line_sync (
                    pactl + " list short sources",
                    out stdout_buf, out stderr_buf, out status
                );
            } catch (SpawnError e) {
                warning ("Failed to enumerate audio sources: %s", e.message);
                return sources;
            }

            if (status != 0) return sources;

            foreach (string line in stdout_buf.split ("\n")) {
                string[] parts = line.strip ().split ("\t");
                if (parts.length >= 2) {
                    string name = parts[1].strip ();
                    if (name != "") sources += name;
                }
            }
            return sources;
        }

        // ── Preset button builder ─────────────────────────────────────────────
        // Creates a horizontal box of linked ToggleButtons for a set of integer
        // presets. Exactly one button is always active (radio-button semantics).
        //
        // Parameters:
        //   presets      — integer values corresponding to each button
        //   labels       — display text for each button (parallel array)
        //   tips         — tooltip text, or null for no tooltips (parallel array)
        //   active_value — the preset that should start active
        //   buttons      — out: the created button array (for future manipulation)
        //   on_select    — callback invoked with the chosen value when selection changes

        private delegate void PresetSelected (int value);

        private Gtk.Box make_preset_buttons (int[] presets, string[] labels,
                                             string[]? tips, int active_value,
                                             out Gtk.ToggleButton[] buttons,
                                             PresetSelected on_select) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.get_style_context ().add_class ("linked");
            buttons = new Gtk.ToggleButton[presets.length];

            unowned Gtk.ToggleButton[] btns = buttons;

            // in_handler prevents the toggled signal from re-entering itself
            // when we programmatically deactivate sibling buttons below.
            bool in_handler = false;

            for (int i = 0; i < presets.length; i++) {
                int val = presets[i];
                var btn = new Gtk.ToggleButton.with_label (labels[i]);
                if (tips != null && i < tips.length) {
                    attach_hover_popover (btn, tips[i]);
                }
                btn.set_active (val == active_value);
                buttons[i] = btn;
                box.pack_start (btn, false, false, 0);

                // Capture i by value so the closure refers to the correct index
                int idx = i;
                btn.toggled.connect (() => {
                    if (in_handler) return;

                    if (!btn.get_active ()) {
                        // The user clicked the already-active button: keep it
                        // active so the group always has exactly one selection
                        in_handler = true;
                        btn.set_active (true);
                        in_handler = false;
                        return;
                    }

                    // Deactivate all other buttons in this group
                    in_handler = true;
                    for (int j = 0; j < btns.length; j++) {
                        if (j != idx) btns[j].set_active (false);
                    }
                    in_handler = false;
                    on_select (val);
                });
            }
            return box;
        }

        // ── Display output list ───────────────────────────────────────────────
        // Rebuilds the radio-button list of connected monitors. Called on
        // construction and whenever a monitor is hotplugged or unplugged.

        public void generate_outputs () {
            foreach (Gtk.Widget child in output_box.get_children ()) {
                output_box.remove (child);
                child.destroy ();
            }

            string[] current_outputs = get_output_list ();
            Gtk.RadioButton? first = null;
            foreach (string output in current_outputs) {
                // Auto-select the first available display if none is set
                if (active == "") active = output;
                var radio = new Gtk.RadioButton.with_label_from_widget (first, output);
                if (first == null) first = radio;
                if (output == active) radio.set_active (true);
                radio.toggled.connect (() => {
                    if (radio.active) active = radio.label;
                });
                output_box.pack_start (radio, false, false, 0);
            }
            output_box.show_all ();
        }

        public string? get_selected_output () { return active; }

        // Returns the connector name (e.g. "HDMI-A-1") for each connected
        // monitor, in the order reported by libxfce4windowing.
        private string[] get_output_list () {
            string[] current_outputs = {};
            if (screen == null) {
                warning ("No displays found\n");
                return current_outputs;
            }
            unowned GLib.List<libxfce4windowing.Monitor> monitors = screen.get_monitors ();
            for (unowned GLib.List<libxfce4windowing.Monitor>? m = monitors; m != null; m = m.next) {
                if (m.data == null) continue;
                current_outputs += m.data.get_connector ();
            }
            return current_outputs;
        }

        // ── Helpers ───────────────────────────────────────────────────────────

        // Returns the first preset value that matches target exactly.
        // Falls back to presets[0] (the "safe" default) when the stored value
        // does not match any preset, which can happen if the user edits the
        // GSettings key directly via dconf-editor.
        private int find_nearest_preset (int[] presets, int target) {
            foreach (int p in presets) {
                if (p == target) return p;
            }
            return presets[0];
        }
    }


    // ── Applet ────────────────────────────────────────────────────────────────
    // Owns the panel icon (ScreencastIcon) and popover (ScreencastPopover) and
    // acts as the bridge between UI events and the Recorder backend.
    //
    // Left-click  → start / stop recording with current popover settings
    // Right-click / middle-click → show / hide the settings popover

    public class ScreencastApplet : Budgie.Applet {

        private ScreencastIcon        panel_widget;
        private ScreencastPopover     popover  = null;
        private GLib.Settings?        settings;
        private unowned Budgie.PopoverManager? manager = null;
        public  string uuid { public set; public get; }
        private Recorder recorder_app;

        public ScreencastApplet (string uuid) {
            Object (uuid: uuid);

            initialiseLocaleLanguageSupport ();
            recorder_app = new Recorder ();

            this.settings_schema = "org.ubuntubudgie.budgie-screencast";
            this.settings_prefix = "/com/solus-project/budgie-panel/instance/budgie-screencast";
            this.settings = this.get_applet_settings (uuid);

            // Keep the recorder's save path in sync if it is changed from the
            // settings panel while the applet is running
            this.settings.changed["save-path"].connect (() => {
                string save_path = this.settings.get_string ("save-path");
                if (is_valid_folder (save_path)) recorder_app.set_save_path (save_path);
            });

            string save_path = this.settings.get_string ("save-path");
            if (!is_valid_folder (save_path)) save_path = default_path;
            recorder_app.set_save_path (save_path);

            panel_widget = new ScreencastIcon ();
            add (panel_widget);
            show_all ();

            // Forward recorder state changes to the panel icon
            recorder_app.recording_changed.connect ((rec) => {
                panel_widget.set_recording (rec);
            });

            // pending_changed fires for both start-delay and end-of-recording
            // countdowns; set_pending handles show/hide, update_countdown
            // redraws the digit each second while the badge is visible
            recorder_app.pending_changed.connect ((pend, countdown) => {
                panel_widget.set_pending (pend, countdown);
                if (pend) panel_widget.update_countdown (countdown);
            });

            // area_selection_failed means the user cancelled slurp or it was
            // not installed; recording stays false, no further action needed

            popover = new ScreencastPopover (panel_widget, this.settings);

            panel_widget.button_press_event.connect ((e) => {
                if (e.button == 1) {
                    // Left-click: start or stop recording
                    CaptureMode mode = popover.capture_mode;
                    // In SCREEN mode the output connector is required; guard
                    // against the edge case where no displays are detected
                    string output = (mode == CaptureMode.SCREEN)
                        ? popover.get_selected_output () : "";
                    if (mode == CaptureMode.SCREEN && output == "") return Gdk.EVENT_STOP;

                    recorder_app.toggle (output, mode,
                                        popover.delay_seconds,
                                        popover.duration_seconds,
                                        popover.audio_enabled,
                                        popover.audio_device);
                    return Gdk.EVENT_STOP;
                }

                // Right / middle-click: toggle the settings popover
                if (popover.get_visible ()) {
                    popover.hide ();
                } else {
                    this.manager.show_popover (panel_widget);
                }
                return Gdk.EVENT_STOP;
            });

            popover.get_child ().show_all ();
        }

        public override bool supports_settings () { return true; }

        public override Gtk.Widget? get_settings_ui () {
            return new ScreencastSettings (this.get_applet_settings (uuid));
        }

        public override void update_popovers (Budgie.PopoverManager? manager) {
            this.manager = manager;
            manager.register_popover (panel_widget, popover);
        }

        public void initialiseLocaleLanguageSupport () {
            GLib.Intl.setlocale (GLib.LocaleCategory.ALL, "");
            GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR);
            GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
            GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);
        }
    }


    // ── Module-level helpers ──────────────────────────────────────────────────

    // Returns true only if path is non-empty, exists on disk, and is a directory.
    // Used to validate both the user-chosen save path and the XDG Videos fallback.
    private bool is_valid_folder (string path) {
        if (path == null || path.strip () == "") return false;
        File file = File.new_for_path (path);
        if (!file.query_exists ()) return false;
        return file.query_file_type (FileQueryInfoFlags.NONE, null) == FileType.DIRECTORY;
    }
}


[ModuleInit]
public void peas_register_types (TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Budgie.Plugin),
                                       typeof (ScreencastApplet.Plugin));
}
