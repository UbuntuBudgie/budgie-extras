#!/usr/bin/python3

import os
import subprocess
import sys

inputfile = sys.argv[1]
replacetext = sys.argv[2]
outputfile = sys.argv[3]
args = len(sys.argv)
if args == 5:
    podir = sys.argv[4]

# Read in the file
with open(inputfile, 'r') as file:
    filedata = file.read()

# Replace the target string
filedata = filedata.replace('PATH_LOC', replacetext)

# Write the file out again
if args == 5:
    staging = "staging"
else:
    staging = ""
with open(outputfile + staging, 'w') as file:
    file.write(filedata)

if args == 5:
    subprocess.run(['intltool-merge',
                    '--desktop-style',
                    podir,
                    outputfile + staging,
                    outputfile])
