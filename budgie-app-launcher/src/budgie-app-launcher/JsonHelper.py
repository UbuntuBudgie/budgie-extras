#!/usr/bin/python3

# This file is part of App Launcher

# Copyright © 2018-2019 Ubuntu Budgie Developers

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.


import json
from Log import Log
from Error import Error


class JsonHelper():

    def __init__(self):
        self.TAG = "JsonHelper"
        self.log = Log("budgie-app-launcher")

    def setDictIfNone(self, data, key):
        if data is not None and key is not None:
            if data.get(key, None) is None:
                data[key] = {}
            return data[key]

    def setListIfNone(self, data, key):
        if data is not None and key is not None:
            if data.get(key, None) is None:
                data[key] = []
            return data[key]

    def readData(self, filePath):
        try:
            with open(filePath, 'r+') as json_file:
                data = json.load(json_file)
                return data
        except Exception as e:
            self.log.e(self.TAG, Error.ERROR_1010, e)

    def writeData(self, filePath, data):
        try:
            with open(filePath, 'w+') as outfile:
                json.dump(data, outfile, indent=4)
        except Exception as e:
            self.log.e(self.TAG, Error.ERROR_1011, e)
