#!/usr/bin/python3

# This file is part of App Launcher

# Copyright © 2018-2019 Ubuntu Budgie Developers

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.


class FilterHelper():

    def __init__(self):
        self.TAG = "FilterHelper"

    def filteredAppsByName(self, apps, showOnPanel, searchText):
        filteredApps = []
        counter = 0
        for app in apps:
            if counter >= showOnPanel and \
                    searchText.lower() in app.getName().lower():
                filteredApps.append(app)
            counter += 1
        if searchText is "":
            filteredApps = apps
        return filteredApps
