#!/bin/sh

# Configure package manager here if necessary:
PKGMAN=yay

sudo systemctl stop v4l2-relayd.service
sudo systemctl disable v4l2-relayd.service

$PKGMAN -Rsn intel-ivsc-driver-dkms-git
$PKGMAN -Rsn intel-ivsc-firmware
$PKGMAN -Rsn icamerasrc-git
$PKGMAN -Rsn intel-ipu6ep-camera-hal-git
$PKGMAN -Rsn intel-ipu6ep-camera-bin
$PKGMAN -Rsn intel-ipu6-dkms-git
$PKGMAN -Rsn v4l2-relayd
$PKGMAN -Rsn v4l2loopback-dkms-git
