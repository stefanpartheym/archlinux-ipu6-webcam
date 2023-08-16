#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'
MAKEPKG="makepkg -si --noconfirm --needed"
FLAG_YUY2_WA=0
FLAG_S2DISK_HACK=0

error() {
  printf "${RED}%s${NC} %s\n" "ERROR:" "${1}"
  exit 1
}

warning() {
  printf "${ORANGE}%s${NC} %s\n" "WARNING:" "${1}"
}

# Configure package manager here if necessary:
if [[ -x "$(command -v yay)" ]]; then
  PKGMAN="yay -S --noconfirm --needed"
elif [[ -x "$(command -v paru)" ]]; then
  PKGMAN="paru -S --noconfirm --needed"
else
  error "Couldn't find a package manager, please install either yay or paru"
fi

build_and_install() {
  echo "# Build and install package: ${1}"
  pushd "${1}" || error "Not a directory: ${1}"
  eval "${MAKEPKG}"
  local installation_state="${?}"
  popd || error "Unable to go back to working directory."
  if [[ "${installation_state}" -eq 0 ]]; then
    echo "=> SUCCESS"
  else
    error "Failed to install: ${1}"
  fi
}

# ------------------------------------------------------------------------------
# Handles options
while getopts ":ash" opt; do
  case $opt in
    a)
      echo "Workaround for other applications will be installed."
      FLAG_YUY2_WA=1
      ;;
    s)
      echo "Hibernation workaround will be installed."
      FLAG_S2DISK_HACK=1
      ;;
    h)
      echo "Usage: ${0} [options]"
      echo "Options:"
      echo "  -a          Install workaround for other applications."
      echo "  -s          Install workaround for hibernation."
      echo "  -h          Show this help message."
      exit 0
      ;;
    \?)
      echo "Invalid option -$OPTARG" >&2
      echo "Try '${0} -h' for usage." >&2
      exit 1
      ;;
  esac
done

# Need to have the correct headers installed before proceding with DKMS
if pacman -Qq linux >/dev/null 2>/dev/null; then
  eval "${PKGMAN} linux-headers"
fi
if pacman -Qq linux-lts >/dev/null 2>/dev/null; then
  eval "${PKGMAN} linux-lts-headers"
fi
if pacman -Qq linux-zen >/dev/null 2>/dev/null; then
  eval "${PKGMAN} linux-zen-headers"
fi
if pacman -Qq linux-hardened >/dev/null 2>/dev/null; then
  eval "${PKGMAN} --needed linux-hardened-headers"
fi

# General dependency(-ies?) to make the webcam work:
# icamerasrc-git from the AUR works as of 2023-08-16.
general_dependencies=(icamerasrc-git gst-plugin-pipewire gst-plugins-good)

# Install build dependencies
if pacman -Qq base-devel >/dev/null 2>&1; then
  echo "# Install build dependencies"
  eval "${PKGMAN} base-devel"
else
  error "base-devel is not installed"
fi

# Install dependency for intel-ipu6-dkms-git
echo "# Install dependency for intel-ipu6-dkms-git"
if eval "${PKGMAN} intel-ivsc-firmware"; then
  echo "=> SUCCESS"
else
  error " Failed to install: intel-ivsc-firmware"
fi

# Install ipu6-driver
echo "# Install IPU6 driver"
if eval "${PKGMAN} intel-ipu6-dkms-git"; then
  echo "=> SUCCESS"
else
  error " Failed to install: intel-ipu6-dkms-git"
fi

build_and_install "intel-ipu6ep-camera-bin"
build_and_install "intel-ipu6ep-camera-hal-git"
build_and_install "v4l2loopback-dkms-git"
build_and_install "v4l2-relayd"
# Not needed as of 2023-08-16. Keeping in case Intel breaks it again.
# build_and_install "icamerasrc-git"

# Install general dependencies
echo "# Install general dependencies"
if eval "${PKGMAN} ${general_dependencies[*]}"; then
  echo "=> SUCCESS"
elif pacman -Qq "${general_dependencies[@]}"; then
  warning "Dependencies failed to update, but are already installed. Trying to continue."
else
  error "Failed to install: ${general_dependencies[*]}"
fi

# Copy workarounds if requested
[ $FLAG_S2DISK_HACK -eq 1 ] && sudo install -m 744 workarounds/i2c_ljca-s2disk.sh /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh
if [ $FLAG_YUY2_WA -eq 1 ]; then
  sudo mkdir -p /etc/systemd/system/v4l2-relayd.service.d
  sudo cp -f workarounds/override.conf /etc/systemd/system/v4l2-relayd.service.d/override.conf
fi

echo "# Enable: v4l2-relayd.service"
if sudo systemctl enable v4l2-relayd.service; then
  echo "=> SUCCESS"
else
  error "Failed to enable: v4l2-relayd.service"
fi
echo "# Start: v4l2-relayd.service"
if sudo systemctl start v4l2-relayd.service; then
  echo "=> SUCCESS"
else
  error "Failed to start: v4l2-relayd.service"
fi

echo -e "\n\nAll done.\nRemember to reboot upon succesful installation!"
read -p "Reboot now\? [y/N] " ans
if [ "$ans" = "Y" ] || [ "$ans" = "y" ]; then
  systemctl reboot
fi
