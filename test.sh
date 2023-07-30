#!/usr/bin/env bash

# Configure sink depending on running window manager
case "${XDG_SESSION_TYPE}" in
  wayland)
    SINK=waylandsink
    ;;
  x11)
    SINK=ximagesink
    ;;
esac

sudo -E LANG=C gst-launch-1.0 icamerasrc ! video/x-raw,format=NV12,width=1280,height=720 ! videoconvert ! "${SINK}"
