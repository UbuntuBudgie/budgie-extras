#!/bin/bash

next_ws=$1
wmctrl -s "$next_ws"
sleep 0.15
/opt/budgie-extras/wprviews/code/wprviews_window &
