#!/bin/sh

yay -S \
  intel-ivsc-driver-dkms-git \
  intel-ivsc-firmware \
  icamerasrc-git \
  intel-ipu6ep-camera-bin

pushd intel-ipu6-dkms-git
makepkg -si
popd

pushd intel-ipu6ep-camera-hal-git
makepkg -si
popd

pushd v4l2-looback-dkms-git
makepkg -si
popd

pushd v4l2-relayd
makepkg -si
popd

sudo systemctl enable v4l2-relayd.service
sudo systemctl start v4l2-relayd.service
