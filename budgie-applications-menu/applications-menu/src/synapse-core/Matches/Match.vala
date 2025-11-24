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
*              Alberto Aldegheri <albyrock87+dev@gmail.com>
*/

public enum Synapse.MatchType {
    UNKNOWN = 0,
    TEXT,
    APPLICATION,
    BOOKMARK,
    GENERIC_URI,
    ACTION,
    SEARCH,
    CONTACT,
}

public abstract class Synapse.Match: GLib.Object {
    public enum Score {
        INCREMENT_MINOR = 2000,
        INCREMENT_SMALL = 5000,
        INCREMENT_MEDIUM = 10000,
        INCREMENT_LARGE = 20000,
        URI_PENALTY = 15000,

        POOR = 50000,
        BELOW_AVERAGE = 60000,
        AVERAGE = 70000,
        ABOVE_AVERAGE = 75000,
        GOOD = 80000,
        VERY_GOOD = 85000,
        EXCELLENT = 90000,

        HIGHEST = 100000
    }

    // properties
    public string title { get; construct set; default = ""; }
    public string description { get; set; default = ""; }
    public string? icon_name { get; construct set; default = null; }
    public bool has_thumbnail { get; construct set; default = false; }
    public string? thumbnail_path { get; construct set; default = null; }
    public Synapse.MatchType match_type { get; construct set; default = Synapse.MatchType.UNKNOWN; }

    public virtual void execute (Synapse.Match? match) {
        critical ("execute () is not implemented");
    }

    public virtual void execute_with_target (Synapse.Match? source, Synapse.Match? target = null) {
        if (target == null) {
            execute (source);
        } else {
            critical ("execute () is not implemented");
        }
    }

    public virtual bool needs_target () {
        return false;
    }

    public virtual Synapse.QueryFlags target_flags () {
        return Synapse.QueryFlags.ALL;
    }

    public signal void executed ();
}
