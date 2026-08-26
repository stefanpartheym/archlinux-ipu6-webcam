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

# Helper: only invoke the package manager for a package that's actually
# installed. Avoids ERROR exits when uninstalling a system that only had part
# of one of the two stacks (classic LTS vs. modern libcamera-ipu6).
maybe_remove() {
  local pkg="$1"
  if pacman -Qq "${pkg}" >/dev/null 2>&1; then
    echo "# Remove: ${pkg}"
    eval "${PKGMAN} ${pkg}" || echo "  -> failed to remove ${pkg}, continuing"
  fi
}

# Stop legacy v4l2-relayd if its unit file is present (classic-stack only).
if systemctl list-unit-files 2>/dev/null | grep -q '^v4l2-relayd.service'; then
  sudo systemctl stop v4l2-relayd.service 2>/dev/null || true
  sudo systemctl disable v4l2-relayd.service 2>/dev/null || true
fi

# --- Modern path: libcamera-ipu6 family (this repo's -fix variants + the
# --- AUR versions they replace / kervel libcamera fork) --------------------
# Remove in dependency order: GStreamer / Python first, then tools / IPA /
# main. pacman with -Rsn drops the bridging libs cleanly. Handle both
# libcamera-ipu6-*-fix (our fork, ships the workerThread race fix) and the
# unsuffixed libcamera-ipu6-* (upstream AUR) so a system that was ever on
# either path gets fully cleaned.
for pkg in gst-plugin-libcamera-ipu6-fix python-libcamera-ipu6-fix \
           libcamera-ipu6-tools-fix libcamera-ipu6-ipa-fix libcamera-ipu6-fix \
           gst-plugin-libcamera-ipu6 python-libcamera-ipu6 \
           libcamera-ipu6-tools libcamera-ipu6-ipa libcamera-ipu6; do
  maybe_remove "${pkg}"
done

# --- Classic path: this repo's -fix variants + the AUR shim chain ----------
# Order: leaf packages first, DKMS / firmware last.
for pkg in "icamerasrc-git-${PKGSUFFIX}" icamerasrc-git \
           "intel-ipu6ep-camera-hal-git-${PKGSUFFIX}" intel-ipu6-camera-hal-git \
           "intel-ipu6ep-camera-bin-${PKGSUFFIX}" intel-ipu6-camera-bin \
           "intel-ipu6-dkms-git-${PKGSUFFIX}" intel-ipu6-dkms-git \
           intel-ivsc-firmware \
           v4l2-relayd v4l2loopback-dkms \
           gst-plugin-pipewire; do
  maybe_remove "${pkg}"
done

# --- Workarounds installed by this repo ------------------------------------
# v4l2-relayd YUY2 override (classic path -a flag).
[[ -d /etc/systemd/system/v4l2-relayd.service.d ]] && \
  sudo rm -rf /etc/systemd/system/v4l2-relayd.service.d/
# i2c_ljca s2disk hook (classic path -s flag).
[[ -f /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh ]] && \
  sudo rm -f /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh
# Manual exposure udev rule from the upstream-libcamera Simple-pipeline
# workaround (only present if the user followed IPU6-investigation-2026-05-22.md).
if [[ -f /etc/udev/rules.d/99-ov01a10-defaults.rules ]]; then
  sudo rm -f /etc/udev/rules.d/99-ov01a10-defaults.rules
  sudo udevadm control --reload 2>/dev/null || true
fi

echo "Uninstall complete."
