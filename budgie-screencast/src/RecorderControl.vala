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
 * RecorderControl — wf-recorder process manager
 *
 * Responsibilities:
 *   - Build the correct wf-recorder argv for SCREEN and AREA capture modes
 *   - Optionally invoke slurp before recording to obtain an area geometry string
 *   - Implement a start delay (countdown before wf-recorder is spawned)
 *   - Implement auto-stop after a set duration
 *   - Show an amber countdown badge on the panel icon during the final
 *     COUNTDOWN_WINDOW seconds of either a start delay or a duration stop
 *   - Gracefully terminate wf-recorder via SIGINT, with SIGTERM / SIGKILL
 *     escalation as a safety net
 *
 * No UI code lives here. All state changes are communicated via signals that
 * ScreencastApplet connects to and forwards to ScreencastIcon.
 *
 */

namespace RecorderControl {

    public enum CaptureMode {
        SCREEN,
        AREA
    }

    public class Recorder : Object {

        // ── Public state ──────────────────────────────────────────────────────

        // True while wf-recorder is running
        public bool recording { get; private set; default = false; }

        // True while the countdown badge should be visible on the panel icon
        // (i.e. within COUNTDOWN_WINDOW seconds of a start or auto-stop)
        public bool pending   { get; private set; default = false; }

        // ── Signals ───────────────────────────────────────────────────────────

        // Emitted when wf-recorder starts or stops
        public signal void recording_changed (bool recording);

        // Emitted each second during the visible countdown window, for both
        // start-delay and end-of-recording countdowns.
        //   pending=true,  countdown=N → show badge with digit N
        //   pending=false, countdown=0 → hide badge
        public signal void pending_changed (bool pending, int countdown);

        // Emitted when slurp exits non-zero (user cancelled) or cannot be found
        public signal void area_selection_failed ();

        // ── Private state ─────────────────────────────────────────────────────

        private string save_path = "";

        // PID of the running wf-recorder process; 0 when not recording
        private Pid pid = 0;

        // How many seconds before a start/stop the countdown badge appears
        private const int COUNTDOWN_WINDOW = 5;

        // Source IDs for active timers — must all be cancelled on stop/toggle
        private uint delay_source         = 0;  // 1-second tick during start delay
        private uint duration_source      = 0;  // fires at (duration − COUNTDOWN_WINDOW) seconds
        private uint duration_tick_source = 0;  // 1-second tick in the final COUNTDOWN_WINDOW seconds

        // ── Public API ────────────────────────────────────────────────────────

        // Toggle recording on/off. If a start delay or duration countdown is
        // already in progress, cancels it before stopping.
        public void toggle (string output, CaptureMode mode,
                            int delay_seconds, int duration_seconds,
                            bool audio_enabled, string audio_device) {
            if (recording || pending) {
                cancel_all_timers ();
                clear_pending ();
                stop ();
            } else {
                start (output, mode, delay_seconds, duration_seconds,
                       audio_enabled, audio_device);
            }
        }

        public void start (string output, CaptureMode mode,
                           int delay_seconds, int duration_seconds,
                           bool audio_enabled, string audio_device) {
            if (recording || pending) return;

            if (delay_seconds > 0) {
                run_with_delay (output, mode, delay_seconds, duration_seconds,
                                audio_enabled, audio_device);
            } else {
                launch (output, mode, duration_seconds, audio_enabled, audio_device);
            }
        }

        // Send SIGINT to ask wf-recorder to finish writing the file cleanly.
        // Escalates to SIGTERM after 1.5 s and SIGKILL after 3.5 s as a safety
        // net in case wf-recorder hangs. The ChildWatch callback clears `pid`
        // and emits recording_changed(false) once the process actually exits.
        public void stop () {
            cancel_duration_timers ();
            if (!recording || pid == 0) return;

            Posix.kill ((int) pid, Posix.Signal.INT);

            Pid stopping_pid = pid;
            Timeout.add (1500, () => {
                if (pid == stopping_pid) Posix.kill ((int) pid, Posix.Signal.TERM);
                return false;
            });
            Timeout.add (3500, () => {
                if (pid == stopping_pid) Posix.kill ((int) pid, Posix.Signal.KILL);
                return false;
            });
        }

        public void set_save_path (string path) {
            save_path = path;
        }

        // ── Start delay countdown ─────────────────────────────────────────────
        // Runs a 1-second ticker for the full delay period. The badge is only
        // shown during the final COUNTDOWN_WINDOW seconds; before that the
        // ticker runs silently so the UI stays uncluttered during long waits.

        private void run_with_delay (string output, CaptureMode mode,
                                     int delay_seconds, int duration_seconds,
                                     bool audio_enabled, string audio_device) {
            int remaining = delay_seconds;

            // Show immediately if the chosen delay is already within the window
            if (remaining <= COUNTDOWN_WINDOW) {
                show_pending (remaining);
            }

            delay_source = Timeout.add (1000, () => {
                remaining--;

                if (remaining <= 0) {
                    delay_source = 0;
                    clear_pending ();
                    launch (output, mode, duration_seconds, audio_enabled, audio_device);
                    return false;  // stop timer
                }

                if (remaining <= COUNTDOWN_WINDOW) {
                    show_pending (remaining);
                }
                return true;  // keep ticking
            });
        }

        // ── Badge helpers ─────────────────────────────────────────────────────

        private void show_pending (int countdown) {
            pending = true;
            pending_changed (true, countdown);
        }

        private void clear_pending () {
            if (!pending) return;
            pending = false;
            pending_changed (false, 0);
        }

        // Cancel the start-delay ticker and hide the badge
        private void cancel_pending_delay () {
            if (delay_source != 0) {
                GLib.Source.remove (delay_source);
                delay_source = 0;
            }
            clear_pending ();
        }

        // ── Launch ────────────────────────────────────────────────────────────

        private void launch (string output, CaptureMode mode, int duration_seconds,
                             bool audio_enabled, string audio_device) {
            if (mode == CaptureMode.AREA) {
                start_area_capture (duration_seconds, audio_enabled, audio_device);
            } else {
                spawn_recorder (build_argv (output, null, audio_enabled, audio_device),
                                duration_seconds);
            }
        }

        // ── Area capture via slurp ────────────────────────────────────────────
        // slurp is a Wayland-native interactive region selector that prints a
        // geometry string ("X,Y WxH") to stdout. We spawn it asynchronously
        // so the compositor can draw the selection overlay, then read the
        // result and hand it to wf-recorder via -g.

        private void start_area_capture (int duration_seconds,
                                         bool audio_enabled, string audio_device) {
            string? slurp = Environment.find_program_in_path ("slurp");
            if (slurp == null) {
                warning ("Unable to locate slurp — needed for area capture");
                area_selection_failed ();
                return;
            }

            string?[] slurp_argv = { slurp, null };
            Pid slurp_pid;

            try {
                int stdout_fd;
                Process.spawn_async_with_pipes (
                    null, slurp_argv, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out slurp_pid, null, out stdout_fd, null
                );

                IOChannel channel = new IOChannel.unix_new (stdout_fd);

                ChildWatch.add (slurp_pid, (child_pid, status) => {
                    Process.close_pid (child_pid);

                    // Non-zero exit means the user pressed Escape to cancel
                    if (status != 0) {
                        area_selection_failed ();
                        return;
                    }

                    string geometry = "";
                    try {
                        channel.read_line (out geometry, null, null);
                        geometry = geometry.strip ();
                    } catch (Error e) {
                        warning ("Failed to read slurp output: %s", e.message);
                        area_selection_failed ();
                        return;
                    }

                    if (geometry == "") {
                        area_selection_failed ();
                        return;
                    }

                    spawn_recorder (build_argv (null, geometry, audio_enabled, audio_device),
                                    duration_seconds);
                });

            } catch (SpawnError e) {
                warning ("Failed to start slurp: %s", e.message);
                area_selection_failed ();
            }
        }

        // ── argv builder ──────────────────────────────────────────────────────
        // Builds the argument vector for wf-recorder. Exactly one of `output`
        // (screen mode, passed as -o) or `geometry` (area mode, passed as -g)
        // should be non-null; passing both or neither is a programming error.
        //
        // Audio:
        //   -a           → record audio using the system default PulseAudio/PipeWire source
        //   -a<device>   → record from a specific named source (no space before device name)
        //
        // The array is null-terminated because Process.spawn_async requires it.
        // We use string?[] (nullable element type) so the null sentinel is
        // type-correct; GenericArray<string> would produce a compiler warning.

        private string?[] build_argv (string? output, string? geometry,
                                      bool audio_enabled, string audio_device) {
            string?[] args = {};
            args += Environment.find_program_in_path ("wf-recorder");

            if (output != null) {
                args += "-o";
                args += output;
            } else if (geometry != null) {
                args += "-g";
                args += geometry;
            }

            args += "-f";
            args += output_path ();

            if (audio_enabled) {
                if (audio_device != null && audio_device.strip () != "") {
                    // wf-recorder accepts the device name concatenated directly
                    // onto the flag with no intervening space: -a<device>
                    args += "-a" + audio_device;
                } else {
                    args += "-a";
                }
            }

            // spawn_async requires a null sentinel at the end of the array
            args += null;
            return args;
        }

        // Generates a timestamped output filename under save_path
        private string output_path () {
            string timestamp = (new DateTime.now_local ()).format ("%Y-%m-%d-%H-%M-%S");
            return Path.build_filename (save_path, "recording_%s.mp4".printf (timestamp));
        }

        // ── Spawn + child watch ───────────────────────────────────────────────

        private void spawn_recorder (string?[] argv, int duration_seconds) {
            if (argv[0] == null) {
                warning ("Unable to locate wf-recorder");
                return;
            }

            try {
                // DO_NOT_REAP_CHILD is required so we can install a ChildWatch;
                // the watch callback calls Process.close_pid to avoid a zombie
                Process.spawn_async (null, argv, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out pid
                );

                ChildWatch.add (pid, (child_pid, status) => {
                    Process.close_pid (child_pid);
                    if (pid == child_pid) {
                        pid = 0;
                        cancel_duration_timers ();
                        clear_pending ();
                        set_recording_state (false);
                    }
                });

                set_recording_state (true);

                if (duration_seconds > 0) {
                    schedule_duration_stop (duration_seconds);
                }

            } catch (SpawnError e) {
                pid = 0;
                set_recording_state (false);
                warning ("Failed to start wf-recorder: %s", e.message);
            }
        }

        // ── Duration auto-stop with end-of-recording countdown ────────────────
        // Two-phase approach to keep the UI quiet during long recordings:
        //
        //   Phase 1 (silent): a single Timeout fires after (duration − COUNTDOWN_WINDOW)
        //                     seconds with no visible feedback.
        //   Phase 2 (visible): a 1-second ticker counts down from COUNTDOWN_WINDOW,
        //                      showing the amber badge, then calls stop().
        //
        // For durations ≤ COUNTDOWN_WINDOW the silent phase is skipped and the
        // ticker starts immediately.

        private void schedule_duration_stop (int duration_seconds) {
            int silent_wait = duration_seconds - COUNTDOWN_WINDOW;

            if (silent_wait > 0) {
                duration_source = Timeout.add_seconds (silent_wait, () => {
                    duration_source = 0;
                    start_duration_tick (COUNTDOWN_WINDOW);
                    return false;
                });
            } else {
                // Duration is short enough to go straight into the visible countdown
                start_duration_tick (duration_seconds);
            }
        }

        private void start_duration_tick (int initial_countdown) {
            int remaining = initial_countdown;
            show_pending (remaining);

            duration_tick_source = Timeout.add (1000, () => {
                remaining--;

                if (remaining <= 0) {
                    duration_tick_source = 0;
                    clear_pending ();
                    stop ();
                    return false;
                }

                show_pending (remaining);
                return true;
            });
        }

        // ── Timer cleanup ─────────────────────────────────────────────────────

        // Cancel only the duration-related timers (used when stop() is called
        // normally or when a manual stop interrupts an auto-stop countdown)
        private void cancel_duration_timers () {
            if (duration_source != 0) {
                GLib.Source.remove (duration_source);
                duration_source = 0;
            }
            if (duration_tick_source != 0) {
                GLib.Source.remove (duration_tick_source);
                duration_tick_source = 0;
            }
        }

        // Cancel every active timer — used by toggle() when the user clicks
        // stop while a start-delay or duration countdown is in progress
        private void cancel_all_timers () {
            cancel_pending_delay ();
            cancel_duration_timers ();
        }

        // ── Recording state ───────────────────────────────────────────────────

        private void set_recording_state (bool value) {
            if (recording == value) return;
            recording = value;
            recording_changed (recording);
        }
    }
}
