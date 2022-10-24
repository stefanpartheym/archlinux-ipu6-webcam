#!/bin/sh

sudo -E LANG=C gst-launch-1.0 icamerasrc ! autovideoconvert ! waylandsink
