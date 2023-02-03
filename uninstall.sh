#!/bin/sh

# Configure package manager here if necessary:
if [ -f /bin/yay ]; then
  PKGMAN=yay
elif [ -f /bin/paru ]; then
  PKGMAN=paru
else
  echo "ERROR: Couldn't find a package manager, please configure it manually"
  exit 1
fi

sudo systemctl stop v4l2-relayd.service
sudo systemctl disable v4l2-relayd.service

$PKGMAN -Rsn intel-ivsc-driver-dkms-git
# Not needed because it is uninstalled as a dependency of the previous package:
#$PKGMAN -Rsn intel-ivsc-firmware

$PKGMAN -Rsn icamerasrc-git
$PKGMAN -Rsn intel-ipu6ep-camera-hal-git
$PKGMAN -Rsn intel-ipu6ep-camera-bin
$PKGMAN -Rsn intel-ipu6-dkms-git

$PKGMAN -Rsn v4l2-relayd
$PKGMAN -Rsn v4l2loopback-dkms-git

$PKGMAN -Rsn gst-plugin-pipewire

if [ -d /etc/systemd/system/v4l2-relayd.service.d ]; then
  sudo rm -rf /etc/systemd/system/v4l2-relayd.service.d/
fi
