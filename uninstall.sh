#!/bin/sh

# Configure package manager here if necessary:
if [ -f /bin/yay ]; then
  PKGMAN="yay -Rsn --noconfirm"
elif [ -f /bin/paru ]; then
  PKGMAN="paru -Rsn --noconfirm"
else
  echo "ERROR: Couldn't find a package manager, please configure it manually"
  exit 1
fi

# The package suffix used to install the patched packages to not conflict with
# their AUR counter part:
PKGSUFFIX=fix

sudo systemctl stop v4l2-relayd.service
sudo systemctl disable v4l2-relayd.service

$PKGMAN intel-ivsc-driver-dkms-git
# Not needed because it is uninstalled as a dependency of the previous package:
#$PKGMAN intel-ivsc-firmware

$PKGMAN icamerasrc-git
$PKGMAN intel-ipu6ep-camera-hal-git-${PKGSUFFIX}
$PKGMAN intel-ipu6ep-camera-bin
$PKGMAN intel-ipu6-dkms-git-${PKGSUFFIX}

$PKGMAN v4l2-relayd-${PKGSUFFIX}
$PKGMAN v4l2loopback-dkms-git-${PKGSUFFIX}

$PKGMAN gst-plugin-pipewire

if [ -d /etc/systemd/system/v4l2-relayd.service.d ]; then
  sudo rm -rf /etc/systemd/system/v4l2-relayd.service.d/
fi
