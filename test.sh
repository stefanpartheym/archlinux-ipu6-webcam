#!/bin/sh

# Configure sink depending on running window manager
SINK=waylandsink
pgrep -x Xorg && SINK=ximagesink

sudo -E LANG=C gst-launch-1.0 icamerasrc ! autovideoconvert ! ${SINK}
