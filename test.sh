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

# Check if on Tiger Lake by checking if 'intel-ipu6-camera-hal-git[-fix]' is installed.
if pacman -Qq intel-ipu6-camera-hal-git-fix >/dev/null 2>&1 \
 || pacman -Qq intel-ipu6-camera-hal-git >/dev/null 2>&1; then
  # Set to YUY2 for Tiger Lake
  FORMAT=YUY2
else
  # Set to NV12 for Alder Lake and Meteor Lake
  FORMAT=NV12
fi

sudo -E LANG=C gst-launch-1.0 icamerasrc ! video/x-raw,format="${FORMAT}",width=1280,height=720 ! videoconvert ! "${SINK}"
