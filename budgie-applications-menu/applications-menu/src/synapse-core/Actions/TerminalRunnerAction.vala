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

private class Synapse.TerminalRunnerAction: Synapse.BaseAction {
    public TerminalRunnerAction () {
    Object (title: _("Run in Terminal"),
    description: _("Run application or command in terminal"),
    icon_name: "terminal", has_thumbnail: false,
    match_type: MatchType.ACTION,
    default_relevancy: Match.Score.BELOW_AVERAGE);
    }

    public override void do_execute (Match? match, Match? target = null) {
        if (match.match_type == MatchType.APPLICATION) {
            unowned ApplicationMatch? app_match = match as ApplicationMatch;
            return_if_fail (app_match != null);

            AppInfo original = app_match.app_info ??
            new DesktopAppInfo.from_filename (app_match.filename);

            try {
                AppInfo app = AppInfo.create_from_commandline (
                original.get_commandline (), original.get_name (),
                AppInfoCreateFlags.NEEDS_TERMINAL);
                weak Gdk.Display display = Gdk.Display.get_default ();
                app.launch (null, display.get_app_launch_context ());
            } catch (Error err) {
                critical (err.message);
            }
        }
    }

    public override bool valid_for_match (Match match) {
        switch (match.match_type) {
        case MatchType.APPLICATION:
            unowned ApplicationMatch? am = match as ApplicationMatch;
            return am != null;
        default:
            return false;
        }
    }
}
