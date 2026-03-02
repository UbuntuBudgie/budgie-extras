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

/*
 * ScreencastIcon — panel icon with a state-driven indicator overlay
 *
 * The base icon (budgie-screencast-symbolic) is always visible. Overlaid on
 * its bottom-right corner is a shared DrawingArea that renders differently
 * depending on the current state:
 *
 *   IDLE      → indicator hidden
 *   PENDING   → amber filled circle with a white countdown digit (14×14 px)
 *               shown during the final 5 seconds before recording starts or stops
 *   RECORDING → small red dot (10×10 px) that blinks at 0.5 Hz
 *
 * The indicator is sized differently in each state because the countdown badge
 * needs to accommodate a digit (14 px gives enough room for Cairo text layout),
 * while the recording dot is intentionally small and unobtrusive (10 px).
 *
 */

public class ScreencastIcon : Gtk.EventBox {

    private Gtk.Overlay     overlay;
    private Gtk.Image       base_icon;
    // Shared canvas: draws either a red dot or an amber countdown badge
    private Gtk.DrawingArea indicator;

    // Flash timer source ID; 0 when not active
    private uint timeout_id  = 0;
    // Current flash visibility state, toggled every 500 ms while recording
    private bool flash_state = true;

    // ── State machine ─────────────────────────────────────────────────────────
    // All rendering decisions go through transition_to() to ensure the indicator
    // size, visibility, and timer are always consistent with the current state.

    private enum State { IDLE, PENDING, RECORDING }
    private State state     = State.IDLE;
    // Countdown digit shown in PENDING state; updated by update_countdown()
    private int   countdown = 0;

    // ── Construction ─────────────────────────────────────────────────────────

    public ScreencastIcon (string icon_name = "budgie-screencast-symbolic") {
        this.set_visible_window (false);

        overlay = new Gtk.Overlay ();
        this.add (overlay);

        base_icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.BUTTON);
        overlay.add (base_icon);

        indicator = new Gtk.DrawingArea ();
        // Default size for the recording dot; resized to 14×14 in PENDING state
        indicator.set_size_request (10, 10);
        indicator.set_halign (Gtk.Align.END);
        indicator.set_valign (Gtk.Align.END);
        indicator.set_margin_bottom (10);
        indicator.set_margin_end (0);
        indicator.draw.connect (on_draw_indicator);
        overlay.add_overlay (indicator);

        this.show_all ();
        indicator.hide ();  // hidden until we enter PENDING or RECORDING
    }

    // Called by ScreencastApplet in response to Recorder signals.
    // Drive the RECORDING state. Ignores calls that would leave the state
    // unchanged to avoid redundant redraws.
    public void set_recording (bool recording) {
        if (recording) {
            transition_to (State.RECORDING, 0);
        } else if (state == State.RECORDING) {
            transition_to (State.IDLE, 0);
        }
    }

    // Drive the PENDING state. `seconds` is the initial countdown digit.
    // Subsequent digit updates arrive via update_countdown().
    public void set_pending (bool pending, int seconds) {
        if (pending) {
            transition_to (State.PENDING, seconds);
        } else if (state == State.PENDING) {
            transition_to (State.IDLE, 0);
        }
    }

    // Update the countdown digit while already in PENDING state.
    // Called once per second by ScreencastApplet from the pending_changed signal.
    public void update_countdown (int seconds) {
        if (state != State.PENDING) return;
        countdown = seconds;
        indicator.queue_draw ();
    }

    // ── State transitions ─────────────────────────────────────────────────────

    private void transition_to (State next, int cd) {
        stop_timer ();
        state     = next;
        countdown = cd;

        switch (state) {
            case State.IDLE:
                indicator.hide ();
                break;

            case State.PENDING:
                // Larger canvas to fit the countdown digit inside the badge circle
                indicator.set_size_request (14, 14);
                indicator.show ();
                indicator.queue_draw ();
                break;

            case State.RECORDING:
                // Smaller canvas for the unobtrusive recording dot
                indicator.set_size_request (10, 10);
                flash_state = true;
                indicator.show ();
                start_flash_timer ();
                break;
        }
    }

    // ── Drawing ───────────────────────────────────────────────────────────────

    private bool on_draw_indicator (Cairo.Context cr) {
        switch (state) {
            case State.RECORDING:
                draw_dot (cr);
                break;
            case State.PENDING:
                draw_countdown_badge (cr);
                break;
            default:
                break;
        }
        return false;  // allow further drawing by the overlay
    }

    // Solid red circle filling the 10×10 canvas
    private void draw_dot (Cairo.Context cr) {
        cr.arc (5, 5, 4, 0, 2 * Math.PI);
        cr.set_source_rgb (1.0, 0.0, 0.0);
        cr.fill ();
    }

    // Amber filled circle with a white bold digit centred inside it.
    // The circle is drawn in the 14×14 canvas; the digit is positioned using
    // Cairo text extents so it is centred regardless of the digit's width.
    private void draw_countdown_badge (Cairo.Context cr) {
        cr.arc (7, 7, 6.5, 0, 2 * Math.PI);
        cr.set_source_rgb (1.0, 0.65, 0.0);
        cr.fill ();

        cr.set_source_rgb (1.0, 1.0, 1.0);
        cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size (8.0);
        string text = countdown.to_string ();
        Cairo.TextExtents ext;
        cr.text_extents (text, out ext);
        // Adjust for the glyph's bearing so the visual centre of the text
        // aligns with the centre of the circle rather than the origin of the
        // bounding box
        cr.move_to (7 - ext.width / 2 - ext.x_bearing,
                    7 - ext.height / 2 - ext.y_bearing);
        cr.show_text (text);
    }

    // ── Flash timer ───────────────────────────────────────────────────────────

    // Toggles the indicator's visibility every 500 ms to produce a 1 Hz blink
    private void start_flash_timer () {
        if (timeout_id != 0) return;
        timeout_id = GLib.Timeout.add (500, () => {
            flash_state = !flash_state;
            indicator.set_visible (flash_state);
            return true;  // repeat indefinitely
        });
    }

    private void stop_timer () {
        if (timeout_id != 0) {
            GLib.Source.remove (timeout_id);
            timeout_id = 0;
        }
        // Ensure the indicator is visible when the timer restarts in a new state
        flash_state = true;
    }
}
