#!/bin/sh
# Path: /usr/lib/systemd/system-sleep/v4l2-susp.sh
# Stops and resumes the v4l2 relayd service, so that the webcam will work after resuming if it was in use
# when the system was suspended.

stage=$1
op=$2

if [ "pre" = "$stage" ]; then
    systemctl stop v4l2-relayd.service
elif [ "${1}" == "post" ]; then
    systemctl start v4l2-relayd.service
fi