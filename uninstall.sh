#!/usr/bin/env bash

# Configure package manager here if necessary:
if [[ -x "$(command -v yay)" ]]; then
  PKGMAN="yay -Rsn --noconfirm"
elif [[ -x "$(command -v paru)" ]]; then
  PKGMAN="paru -Rsn --noconfirm"
else
  echo "ERROR: Couldn't find a package manager, please install either yay or paru"
  exit 1
fi

# The package suffix used to install the patched packages to not conflict with
# their AUR counter part:
PKGSUFFIX=fix

sudo systemctl stop v4l2-relayd.service
sudo systemctl disable v4l2-relayd.service

# Not needed anymore due to being built and installed together with intel-ipu6-dkms
# eval "${PKGMAN} intel-ivsc-driver-dkms-git"
# Not needed because it is uninstalled as a dependency of the previous package:
#$PKGMAN intel-ivsc-firmware

eval "${PKGMAN} icamerasrc-git-${PKGSUFFIX}"
eval "${PKGMAN} intel-ipu6ep-camera-hal-git-${PKGSUFFIX}"
eval "${PKGMAN} intel-ipu6ep-camera-bin"
eval "${PKGMAN} intel-ipu6-dkms-git"
eval "${PKGMAN} intel-ivsc-firmware"

eval "${PKGMAN} v4l2-relayd"
eval "${PKGMAN} v4l2loopback-dkms-git-${PKGSUFFIX}"

eval "${PKGMAN} gst-plugin-pipewire"

# Get rid of workarounds if they exist:
[[ -d /etc/systemd/system/v4l2-relayd.service.d ]] && sudo rm -rf /etc/systemd/system/v4l2-relayd.service.d/
[[ -f /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh ]] && sudo rm -f /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh
