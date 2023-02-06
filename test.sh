#!/bin/sh

# Configure sink depending on running window manager
SINK=waylandsink
pgrep -x Xorg >/dev/null && SINK=ximagesink

sudo -E LANG=C gst-launch-1.0 icamerasrc ! video/x-raw,format=NV12,width=1280,height=720 ! videoconvert ! ${SINK}
