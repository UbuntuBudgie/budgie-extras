#!/usr/bin/env python3
import ast

"""
Use this script to extract the name field of hotcorner's defaults.in.in file
into a entrynames.vala - file
"""

lines = open("./defaults.in.in", "r").readlines()
target = "./entrynames.vala"

with open(target, "wt") as valafile:
    n = 1
    for count in lines:
        try:
            dictline = ast.literal_eval(count)
        except (SyntaxError, ValueError):
            print("malformed line: %d" % n)
        else:
            name = dictline["name"]
            valafile.write('_("%s")\n' % name)
        n = n + 1
