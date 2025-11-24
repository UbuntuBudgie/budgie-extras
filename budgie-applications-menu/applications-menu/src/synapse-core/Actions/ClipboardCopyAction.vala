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

private class Synapse.ClipboardCopyAction: Synapse.BaseAction {
    public ClipboardCopyAction () {
        Object (title: _("Copy to Clipboard"),
                description: _("Copy selection to clipboard"),
                icon_name: "gtk-copy", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: Match.Score.AVERAGE);
    }

    public override void do_execute (Match? match, Match? target = null) {
        var cb = Gtk.Clipboard.get (Gdk.Atom.NONE);
        if (match.match_type == MatchType.GENERIC_URI) {
            UriMatch uri_match = match as UriMatch;
            return_if_fail (uri_match != null);

            /*  Just wow, Gtk and also Vala are trying really hard to make this hard to do...
                Gtk.TargetEntry[] no_entries = {};
                Gtk.TargetList l = new Gtk.TargetList (no_entries);
                l.add_uri_targets (0);
                l.add_text_targets (0);
                Gtk.TargetEntry te = Gtk.target_table_new_from_list (l, 2);
                cb.set_with_data ();
            */
            cb.set_text (uri_match.uri, -1);
        } else if (match.match_type == MatchType.TEXT) {
            TextMatch? text_match = match as TextMatch;
            unowned string content = text_match != null ? text_match.text : match.title;

            cb.set_text (content, -1);
        }
    }

    public override bool valid_for_match (Match match) {
        switch (match.match_type) {
            case MatchType.GENERIC_URI:
                return true;
            case MatchType.TEXT:
                return true;
            default:
                return false;
        }
    }

    public override int get_relevancy_for_match (Match match) {
        unowned TextMatch? text_match = match as TextMatch;
        if (text_match != null && text_match.text_origin == TextOrigin.CLIPBOARD) {
            return 0;
        }

        return default_relevancy;
    }
}
