#!/bin/bash

next_ws=$1
nokeys=$2
wmctrl -s "$next_ws"
sleep 0.15
/usr/lib/budgie-desktop/plugins/budgie-wprviews/wprv $nokeys&
