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

public abstract class Synapse.BaseAction: Synapse.Match {
    public int default_relevancy { get; set; }
    public bool notify_match { get; set; default = true; }

    public abstract bool valid_for_match (Match match);
    public virtual int get_relevancy_for_match (Match match) {
      return default_relevancy;
    }

    public abstract void do_execute (Match? source, Match? target = null);
    public override void execute_with_target (Match? source, Match? target = null) {
      do_execute (source, target);
      if (notify_match) source.executed ();
    }

    public override bool needs_target () {
      return false;
    }

    public override QueryFlags target_flags () {
      return QueryFlags.ALL;
    }
}
