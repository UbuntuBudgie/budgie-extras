#!/usr/bin/env python3
import ast

"""
Use this script to extract the name field of hotcorner's defaults.in.in file
into a entrynames.vala - file
"""

lines = open("./defaults.in.in", "r").readlines()
target = "./entrynames.vala"

with open(target, "wt") as valafile:
    for l in lines:
        dictline = ast.literal_eval(l)
        name = dictline["name"]
        valafile.write('_("%s")\n' % name)

        
        
    


