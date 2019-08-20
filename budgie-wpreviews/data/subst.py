#!/usr/bin/python3

import os
import subprocess
import sys

inputfile = sys.argv[1]
replacetext = sys.argv[2]
outputfile= sys.argv[3]

# Read in the file
with open(inputfile, 'r') as file :
  filedata = file.read()

# Replace the target string
filedata = filedata.replace('PATH_LOC', replacetext)

# Write the file out again
with open(outputfile, 'w') as file:
  file.write(filedata)