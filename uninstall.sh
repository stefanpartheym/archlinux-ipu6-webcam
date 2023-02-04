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

# The package suffix used to install the patched packages to not conflict with
# their AUR counter part:
PKGSUFFIX=archfix

sudo systemctl stop v4l2-relayd.service
sudo systemctl disable v4l2-relayd.service

$PKGMAN -Rsn intel-ivsc-driver-dkms-git
$PKGMAN -Rsn intel-ivsc-firmware
$PKGMAN -Rsn icamerasrc-git
$PKGMAN -Rsn intel-ipu6ep-camera-hal-git-${PKGSUFFIX}
$PKGMAN -Rsn intel-ipu6ep-camera-bin
$PKGMAN -Rsn intel-ipu6-dkms-git-${PKGSUFFIX}
$PKGMAN -Rsn v4l2-relayd-${PKGSUFFIX}
$PKGMAN -Rsn v4l2loopback-dkms-git-${PKGSUFFIX}

if [ -d /etc/systemd/system/v4l2-relayd.service.d ]; then
  sudo rm -rf /etc/systemd/system/v4l2-relayd.service.d/
fi
