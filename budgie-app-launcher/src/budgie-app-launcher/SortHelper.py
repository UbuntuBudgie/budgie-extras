#!/usr/bin/python3

# This file is part of App Launcher

# Copyright © 2018-2019 Ubuntu Budgie Developers

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.


import re


class SortHelper():

    def __init__(self):
        self.TAG = "budgie-app-launcher.SortHelper"

    def convert(self, text):
        if text.isdigit():
            return int(text)
        else:
            return text.lower()

    def naturalSortAppsByName(self, app):
        key = app.getName()
        cList = []
        if key is not None:
            for c in re.split('([0-9]+)', key):
                cList.append(self.convert(c))
        return cList

    def sortedAppsByName(self, listToSort):
        return sorted(listToSort, key=self.naturalSortAppsByName)

    def naturalSortAppsByIndex(self, app):
        key = str(app.getIndex())
        cList = []
        if key is not None:
            for c in re.split('([0-9]+)', key):
                cList.append(self.convert(c))
        return cList

    def sortedAppsByIndex(self, listToSort):
        return sorted(listToSort, key=self.naturalSortAppsByIndex)
