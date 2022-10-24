#!/bin/sh

sudo systemctl stop v4l2-relayd.service
sudo systemctl disable v4l2-relayd.service

yay -Rsn \
  intel-ivsc-driver-dkms-git \
  intel-ivsc-firmware \
  icamerasrc-git \
  intel-ipu6-dkms-git \
  intel-ipu6ep-camera-bin \
  intel-ipu6ep-camera-hal-git \
  v4l2-relayd \
  v4l2loopback-dkms-git \
