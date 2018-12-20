#!/usr/bin/python3

# This file is part of App Launcher

# Copyright © 2018-2019 Ubuntu Budgie Developers

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.


class App():

    def __init__(self, id, name, isActive):
        self.id = id
        self.name = name
        self.isActive = isActive
        self.info = None
        self.index = None

    def setId(self, id):
        self.id = id

    def getId(self):
        return self.id

    def getName(self):
        return self.name

    def setActive(self, isActive):
        self.isActive = isActive

    def getActive(self):
        return self.isActive

    def setInfo(self, info):
        self.info = info

    def getInfo(self):
        return self.info

    def setIndex(self, index):
        self.index = index

    def getIndex(self):
        return self.index
