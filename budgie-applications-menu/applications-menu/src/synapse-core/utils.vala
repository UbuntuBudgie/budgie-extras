/*
* Copyright (c) 2010 Michal Hruby <michal.mhr@gmail.com>
*               2017 elementary LLC.
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Michal Hruby <michal.mhr@gmail.com>
*/

namespace Synapse {
    [CCode (gir_namespace = "SynapseUtils", gir_version = "1.0")]
    namespace Utils {
        /* Make sure setlocale was called before calling this function
        *   (Gtk.init calls it automatically)
        */
        public static string? remove_accents (string input) {
            string? result;
            unowned string charset;
            GLib.get_charset (out charset);

            try {
                result = GLib.convert (input, input.length,
                "US-ASCII//TRANSLIT", charset);
                // no need to waste cpu cycles if the input is the same
                if (input == result) {
                    return null;
                }
            } catch (ConvertError err) {
                result = null;
            }

            return result;
        }

        public static async bool query_exists_async (GLib.File f) {
            bool exists;

            try {
                yield f.query_info_async (FileAttribute.STANDARD_TYPE, 0, 0, null);
                exists = true;
            } catch (Error err) {
                exists = false;
            }

            return exists;
        }

        [Compact]
        private class DelegateWrapper {
            public SourceFunc callback;

            public DelegateWrapper (owned SourceFunc cb) {
                callback = (owned) cb;
            }
        }

        /*
        * Asynchronous Once.
        *
        * Usage:
        * private AsyncOnce<string> once = new AsyncOnce<string> ();
        * public async void foo ()
        * {
        *   if (!once.is_initialized ()) // not stricly necessary but improves perf
        *   {
        *     if (yield once.enter ())
        *     {
        *       // this block will be executed only once, but the method
        *       // is reentrant; it's also recommended to wrap this block
        *       // in try { } and call once.leave() in finally { }
        *       // if any of the operations can throw an error
        *       var s = yield get_the_string ();
        *       once.leave (s);
        *     }
        *   }
        *   // if control reaches this point the once was initialized
        *   yield do_something_for_string (once.get_data ());
        * }
        */
        public class AsyncOnce<G> {
            private enum OperationState {
                NOT_STARTED,
                IN_PROGRESS,
                DONE
            }

            private G inner;

            private OperationState state;
            private DelegateWrapper[] callbacks = {};

            public AsyncOnce () {
                state = OperationState.NOT_STARTED;
            }

            public bool is_initialized () {
                return state == OperationState.DONE;
            }

            public async bool enter () {
                if (state == OperationState.NOT_STARTED) {
                    state = OperationState.IN_PROGRESS;
                    return true;
                } else if (state == OperationState.IN_PROGRESS) {
                    yield wait_async ();
                }

                return false;
            }

            public void leave (G result) {
                if (state != OperationState.IN_PROGRESS) {
                    warning ("Incorrect usage of AsyncOnce");
                    return;
                }

                state = OperationState.DONE;
                inner = result;
                notify_all ();
            }

            private void notify_all () {
                foreach (unowned DelegateWrapper wrapper in callbacks) {
                    wrapper.callback ();
                }
                callbacks = {};
            }

            private async void wait_async () {
                callbacks += new DelegateWrapper (wait_async.callback);
                yield;
            }
        }
    }
}
