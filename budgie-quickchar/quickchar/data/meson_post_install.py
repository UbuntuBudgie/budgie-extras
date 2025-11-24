#!/usr/bin/python3

import os
import subprocess
import sys

destdir = os.environ.get('DESTDIR', '')
datadir = sys.argv[1]
bindir = os.path.normpath(destdir + os.sep + sys.argv[2])
pkgdatadir = sys.argv[3]
application_id = sys.argv[4]

if not os.path.exists(bindir):
    os.makedirs(bindir)

src = os.path.join(pkgdatadir, application_id)
dest = os.path.join(bindir, 'quickchar')
subprocess.call(['ln', '-s', '-f', src, dest])
