import os
from Xlib.display import Display
from Xlib import X
from Xlib.ext.xtest import fake_input
import Xlib.XK


"""
Budgie QuickChar
Author: Jacob Vlijm
Copyright © 2017-2019 Ubuntu Budgie Developers
Website: https://ubuntubudgie.org
This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or any later version. This
program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details. You
should have received a copy of the GNU General Public License along with this
program.  If not, see <http://www.gnu.org/licenses/>.
"""


def paste_char(*args, **kwargs):
    for c in args:
        fake_input(_display, X.KeyPress, _to_keysim(c))
        _display.sync()
    for c in reversed(args):
        fake_input(_display, X.KeyRelease, _to_keysim(c))
        _display.sync()


def _to_keysim(gotkey):
    return _display.keysym_to_keycode(Xlib.XK.string_to_keysym(gotkey))


_display = Display(os.environ['DISPLAY'])
