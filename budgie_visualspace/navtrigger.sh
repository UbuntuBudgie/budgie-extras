#!/bin/bash

f='/tmp/'$USER'_shownav_busy'

touch "$f"
sleep 0.2
rm "$f"
