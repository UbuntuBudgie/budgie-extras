#!/usr/bin/python3

# This file is part of App Launcher

# Copyright © 2018-2019 Ubuntu Budgie Developers

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

import errno
import os

from App import App
from JsonHelper import JsonHelper


class LocaleHelper():

    def __init__(self):

        self.TAG = "LocalStateHelper"
        self.jsonHelper = JsonHelper()

        self.dirPath = os.path.expanduser("~") + "/.config/budgie-app-launcher"
        self.makeDirIfNotExist(self.dirPath)
        self.filePath = self.dirPath + "/Locale State"

    # makes dir
    def makeDirIfNotExist(self, path):
        if (path is not ""):
            try:
                os.makedirs(path)
            except OSError as e:
                if e.errno != errno.EEXIST:
                    raise

    def retriveApps(self):
        apps = []
        data = self.getData()
        if "apps" in data:
            appsData = data["apps"]
            for appKey in appsData:
                appData = appsData[appKey]
                id = appData["id"]
                name = appData["name"]
                isActive = appData["isActive"]
                index = appData["index"]
                app = App(id, name, isActive)
                app.setIndex(index)
                apps.append(app)

        return apps

    def saveShowOnPanel(self, showOnPanel):
        data = self.getData()
        data["showOnPanel"] = showOnPanel
        self.jsonHelper.writeData(self.filePath, data)

    def retriveShowOnPanel(self):
        showOnPanel = 0
        data = self.getData()
        if "showOnPanel" in data:
            showOnPanel = data["showOnPanel"]
        return showOnPanel

    def saveApps(self, apps):
        data = self.getData()
        appsData = {}
        for app in apps:
            appsData[app.getName()] = \
                {"id": app.getId(),
                 "name": app.getName(),
                 "isActive": app.getActive(),
                 "index": app.getIndex()}

        data["apps"] = appsData
        self.jsonHelper.writeData(self.filePath, data)

    def retriveAppsDict(self):
        appsDict = {}
        data = self.getData()
        if "apps" in data:
            appsData = data["apps"]

            # Converts json data to python object
            for appKey in appsData:
                appData = appsData[appKey]
                id = appData["id"]
                name = appData["name"]
                isActive = appData["isActive"]
                index = appData["index"]
                app = App(id, name, isActive)
                app.setIndex(index)
                appsDict[id] = app
        return appsDict

    def saveIconSize(self, iconSize):
        data = self.getData()
        data["iconSize"] = iconSize
        self.jsonHelper.writeData(self.filePath, data)

    def retriveIconSize(self):
        iconSize = 24
        data = self.getData()
        if "iconSize" in data:
            iconSize = data["iconSize"]
        return iconSize

    def getData(self):
        self.makeDirIfNotExist(self.dirPath)
        data = self.jsonHelper.readData(self.filePath)
        if data is None:
            data = {}
        return data
