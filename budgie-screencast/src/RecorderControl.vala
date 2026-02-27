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
 * This controls wf-recorder. It attempts to start it, and to stop it using
 * SIGINT. When wf-recorder is stopped, it will emit a "recording-changed"
 * signal the applet can use to update the state. This is designed to make
 * sure wf-recorder completely stops.
 */

namespace RecorderControl {

    public class Recorder : Object {
        public bool recording { get; private set; default = false; }
        public signal void recording_changed (bool recording);
        private string save_path;

        private Pid pid = 0;

        private string[] build_argv (string output) {
            string timestamp = (new DateTime.now_local()).format("%Y-%m-%d-_%H-%M-%S");
            string filename = "Recording_%s.mp4".printf(timestamp);
            var out_path = Path.build_filename(save_path, filename);
            string? wf_app = Environment.find_program_in_path("wf-recorder");
            return { wf_app, "-o", output, "-f", out_path, null };
        }

        public void toggle (string output) {
            if (recording) stop();
            else start(output);
        }

        public void start (string output) {
            if (recording) return;

            try {
                var argv = build_argv(output);
                if (argv[0] == null) {
                    warning("Unable to locate wf-recorder");
                    return;
                }
                // This is designed to hopefully prevent a wf-recorder zombie process
                Process.spawn_async(null, argv, null, 
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out pid
                );
                ChildWatch.add(pid, (child_pid, status) => {
                    Process.close_pid(child_pid);

                    if (pid == child_pid) {
                        pid = 0;
                        update_recording_state(false);
                    }
                });

                update_recording_state(true);

            } catch (SpawnError e) {
                pid = 0;
                update_recording_state(false);
                warning("Failed to start wf-recorder: %s", e.message);
            }
        }

        public void stop () {
            if (!recording || pid == 0) return;

            // Graceful stop - wfrecorder ends on SIGINT
            Posix.kill((int)pid, Posix.Signal.INT);

            // If it doesn't stop when we tell it to, here is our backup plan
            Pid stopping_pid = pid;
            Timeout.add(1500, () => {
                if (pid == stopping_pid) Posix.kill((int)pid, Posix.Signal.TERM);
                return false;
            });
            Timeout.add(3500, () => {
                if (pid == stopping_pid) Posix.kill((int)pid, Posix.Signal.KILL);
                return false;
            });
        }

        private void update_recording_state (bool value) {
            if (recording == value) return;
            recording = value;
            recording_changed(recording);
        }

        public void set_save_path(string path) {
            save_path = path;
        }
    }
}