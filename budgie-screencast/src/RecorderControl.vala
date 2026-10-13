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
 * RecorderControl — screen recorder process manager
 *
 * Uses gpu-screen-recorder if it is installed, otherwise falls back to
 * wf-recorder. The choice is made automatically and is invisible to the user.
 * The first time gpu-screen-recorder is used, a single polkit prompt grants
 * its gsr-kms-server helper the capability it needs so that later recordings
 * are prompt-free.
 *
 * Responsibilities:
 *   - Build the correct recorder argv (gpu-screen-recorder or wf-recorder)
 *     for SCREEN and AREA capture modes
 *   - Optionally invoke slurp before recording to obtain an area geometry string
 *   - Implement a start delay (countdown before the recorder is spawned)
 *   - Implement auto-stop after a set duration
 *   - Show an amber countdown badge on the panel icon during the final
 *     COUNTDOWN_WINDOW seconds of either a start delay or a duration stop
 *   - Gracefully terminate the recorder via SIGINT, with SIGTERM / SIGKILL
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

        // Which command line recorder is used. gpu-screen-recorder is preferred
        // when it is installed and able to capture without a polkit prompt;
        // wf-recorder is the fallback.
        private enum Backend {
            WF_RECORDER,
            GPU_SCREEN_RECORDER
        }

        // True while the one-time privilege setup dialog is open
        private bool setting_up = false;

        // The privilege setup is only attempted once per applet session, so a
        // cancelled dialog does not reappear on every recording
        private bool setup_attempted = false;

        private Backend detect_backend () {
            if (Environment.find_program_in_path ("gpu-screen-recorder") == null) {
                return Backend.WF_RECORDER;
            }
            // Without the privileges gpu-screen-recorder would show a polkit
            // prompt on every recording, so prefer wf-recorder if we have it
            if (gsr_has_privileges () ||
                Environment.find_program_in_path ("wf-recorder") == null) {
                return Backend.GPU_SCREEN_RECORDER;
            }
            return Backend.WF_RECORDER;
        }

        // ── gsr-kms-server privileges ─────────────────────────────────────────
        // On Wayland gpu-screen-recorder captures monitors through its helper
        // gsr-kms-server, which needs CAP_SYS_ADMIN. If the helper has not been
        // given that capability (or setuid root) gpu-screen-recorder asks for
        // a password via polkit every time. We grant the capability once.

        // Looks in PATH first, then the sbin directories, which are often not
        // in a normal user's PATH
        private string? find_tool (string name) {
            string? found = Environment.find_program_in_path (name);
            if (found != null) return found;
            foreach (string dir in new string[] { "/usr/sbin", "/sbin", "/usr/bin", "/bin" }) {
                string candidate = Path.build_filename (dir, name);
                if (FileUtils.test (candidate, FileTest.IS_EXECUTABLE)) return candidate;
            }
            return null;
        }

        // Resolved path of the helper, with symlinks followed (setcap does not
        // work on a symlink); null if it cannot be found
        private string? kms_server_path () {
            string? found = find_tool ("gsr-kms-server");
            if (found == null) return null;
            string? real = Posix.realpath (found);
            return real != null ? real : found;
        }

        private bool is_setuid_root (string path) {
            try {
                FileInfo info = File.new_for_path (path).query_info (
                    "unix::mode,unix::uid", FileQueryInfoFlags.NONE);
                return info.get_attribute_uint32 ("unix::uid") == 0 &&
                       (info.get_attribute_uint32 ("unix::mode") & 04000) != 0;
            } catch (Error e) {
                return false;
            }
        }

        private bool gsr_has_privileges () {
            string? path = kms_server_path ();
            if (path == null) return false;
            if (is_setuid_root (path)) return true;

            string? getcap = find_tool ("getcap");
            if (getcap == null) return false;

            try {
                string[] argv = { getcap, path };
                string out_text;
                int status;
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH,
                                    null, out out_text, null, out status);
                // getcap prints e.g. "/usr/bin/gsr-kms-server cap_sys_admin=ep"
                return status == 0 && out_text.contains ("cap_sys_admin");
            } catch (SpawnError e) {
                warning ("Failed to run getcap: %s", e.message);
                return false;
            }
        }

        // True if gpu-screen-recorder is installed but its helper still needs
        // the capability, and we have what we need to grant it
        private bool needs_privilege_setup () {
            if (setup_attempted) return false;
            if (Environment.find_program_in_path ("gpu-screen-recorder") == null) return false;
            if (kms_server_path () == null) return false;
            if (find_tool ("setcap") == null || find_tool ("pkexec") == null) return false;
            return !gsr_has_privileges ();
        }

        // Runs `pkexec setcap cap_sys_admin+ep <gsr-kms-server>`. This shows a
        // single polkit authentication dialog; afterwards the capability is
        // stored on the file, so it is a one-time action (until the package
        // is upgraded and replaces the file). If the user cancels or it fails
        // we carry on with wf-recorder.
        private async void setup_privileges () {
            setup_attempted = true;
            setting_up = true;

            string? pkexec = find_tool ("pkexec");
            string? setcap = find_tool ("setcap");
            string? target = kms_server_path ();

            if (pkexec != null && setcap != null && target != null) {
                try {
                    string[] argv = { pkexec, setcap, "cap_sys_admin+ep", target };
                    var proc = new Subprocess.newv (argv,
                        SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                    yield proc.wait_check_async ();
                } catch (Error e) {
                    // Includes the user dismissing the authentication dialog
                    warning ("gsr-kms-server capability was not set: %s", e.message);
                }
            }

            setting_up = false;
        }

        // ── Public state ──────────────────────────────────────────────────────

        // True while the recorder process is running
        public bool recording { get; private set; default = false; }

        // True while the countdown badge should be visible on the panel icon
        // (i.e. within COUNTDOWN_WINDOW seconds of a start or auto-stop)
        public bool pending   { get; private set; default = false; }

        // ── Signals ───────────────────────────────────────────────────────────

        // Emitted when the recorder starts or stops
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

        // PID of the running recorder process; 0 when not recording
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
            if (recording || pending || setting_up) return;

            // One-time grant of the capability gpu-screen-recorder needs to
            // record without prompting; the recording starts once that is done
            if (needs_privilege_setup ()) {
                setup_privileges.begin ((obj, res) => {
                    setup_privileges.end (res);
                    start (output, mode, delay_seconds, duration_seconds,
                           audio_enabled, audio_device);
                });
                return;
            }

            if (delay_seconds > 0) {
                run_with_delay (output, mode, delay_seconds, duration_seconds,
                                audio_enabled, audio_device);
            } else {
                launch (output, mode, duration_seconds, audio_enabled, audio_device);
            }
        }

        // Send SIGINT to ask the recorder to finish writing the file cleanly
        // (both wf-recorder and gpu-screen-recorder finalise on SIGINT).
        // Escalates to SIGTERM after 1.5 s and SIGKILL after 3.5 s as a safety
        // net in case the recorder hangs. The ChildWatch callback clears `pid`
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
        // result and hand it to the recorder.

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
        // Builds the argument vector for the recorder. Exactly one of `output`
        // (screen mode) or `geometry` (area mode, slurp format "X,Y WxH")
        // should be non-null; passing both or neither is a programming error.
        //
        // The backend is re-detected on every recording, so installing or
        // removing gpu-screen-recorder takes effect without restarting the applet.
        //
        // The array is null-terminated because Process.spawn_async requires it.
        // We use string?[] (nullable element type) so the null sentinel is
        // type-correct; GenericArray<string> would produce a compiler warning.

        private string?[] build_argv (string? output, string? geometry,
                                      bool audio_enabled, string audio_device) {
            if (detect_backend () == Backend.GPU_SCREEN_RECORDER) {
                return build_gsr_argv (output, geometry, audio_enabled, audio_device);
            }
            return build_wf_argv (output, geometry, audio_enabled, audio_device);
        }

        // wf-recorder:
        //   -o <output>  → capture a whole output
        //   -g <geometry>→ capture a slurp region
        //   -a           → record audio using the system default PulseAudio/PipeWire source
        //   -a<device>   → record from a specific named source (no space before device name)
        private string?[] build_wf_argv (string? output, string? geometry,
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

        // gpu-screen-recorder:
        //   -w <monitor> → capture a whole monitor (by name, e.g. HDMI-A-1)
        //   -w region    → capture a region, given with -region WxH+X+Y
        //   -f <fps>     → framerate
        //   -c mp4       → container format
        //   -a <device>  → audio source; "default_input" is the default source
        //                  and any other value is a named PulseAudio/PipeWire device
        //   -o <file>    → output file
        private string?[] build_gsr_argv (string? output, string? geometry,
                                          bool audio_enabled, string audio_device) {
            string?[] args = {};
            args += Environment.find_program_in_path ("gpu-screen-recorder");

            args += "-w";
            if (output != null) {
                args += output;
            } else if (geometry != null) {
                string? region = slurp_to_gsr_region (geometry);
                if (region == null) {
                    warning ("Unable to parse slurp geometry: %s", geometry);
                    // Returning an empty argv makes spawn_recorder bail out
                    string?[] none = { null };
                    return none;
                }
                args += "region";
                args += "-region";
                args += region;
            }

            args += "-f";
            args += "60";
            args += "-c";
            args += "mp4";

            if (audio_enabled) {
                args += "-a";
                if (audio_device != null && audio_device.strip () != "") {
                    args += audio_device;
                } else {
                    args += "default_input";
                }
            }

            args += "-o";
            args += output_path ();

            // spawn_async requires a null sentinel at the end of the array
            args += null;
            return args;
        }

        // Converts slurp's "X,Y WxH" into gpu-screen-recorder's "WxH+X+Y".
        // Returns null if the string cannot be parsed.
        private string? slurp_to_gsr_region (string geometry) {
            // slurp prints "X,Y WxH"
            string[] parts = geometry.strip ().split (" ");
            if (parts.length != 2) return null;

            string[] pos  = parts[0].split (",");
            string[] size = parts[1].split ("x");
            if (pos.length != 2 || size.length != 2) return null;

            int x = int.parse (pos[0]);
            int y = int.parse (pos[1]);
            int w = int.parse (size[0]);
            int h = int.parse (size[1]);
            if (w <= 0 || h <= 0) return null;

            // Coordinates can be negative on multi-monitor layouts; emit an
            // explicit sign for each offset
            return "%dx%d%s%d%s%d".printf (w, h,
                                           x < 0 ? "-" : "+", x.abs (),
                                           y < 0 ? "-" : "+", y.abs ());
        }

        // Generates a timestamped output filename under save_path
        private string output_path () {
            string timestamp = (new DateTime.now_local ()).format ("%Y-%m-%d-%H-%M-%S");
            return Path.build_filename (save_path, "recording_%s.mp4".printf (timestamp));
        }

        // ── Spawn + child watch ───────────────────────────────────────────────

        private void spawn_recorder (string?[] argv, int duration_seconds) {
            if (argv[0] == null) {
                warning ("Unable to locate gpu-screen-recorder or wf-recorder");
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
                warning ("Failed to start recorder: %s", e.message);
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
