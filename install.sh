#!/bin/sh

# Configure package manager here if necessary:
PKGMAN="yay -S --noconfirm"
# Configure makepkg here if necessary:
MAKEPKG="makepkg -si --noconfirm"

error() {
  echo "ERROR: $1"
  exit 1
}

build_and_install() {
  test -d "$1" || error "Not a directory: $1"
  echo "# Build and install package: $1"
  pushd "$1"
  $MAKEPKG
  local installation_state=$?
  popd
  test $installation_state -eq 0 && \
    echo "=> SUCCESS" || \
    error "Failed to install: $1"
}

# ------------------------------------------------------------------------------

# General dependencies to make the webcam work:
general_dependencies="intel-ivsc-driver-dkms-git intel-ivsc-firmware icamerasrc-git"

build_and_install "intel-ipu6-dkms-git"

# Install dependency for intel-ipu6ep-camera-hal-git
echo "# Install dependency for intel-ipu6ep-camera-hal-git"
$PKGMAN intel-ipu6ep-camera-bin && \
  echo "=> SUCCESS" || \
  error "# Failed to install: intel-ipu6ep-camera-bin"

build_and_install "intel-ipu6ep-camera-hal-git"
build_and_install "v4l2-looback-dkms-git"
build_and_install "v4l2-relayd"

# Install general dependencies
echo "# Install general dependencies"
$PKGMAN $general_dependencies && \
  echo "=> SUCCESS" || \
  error "Failed to install: $general_dependencies"

echo "# Enable: v4l2-relayd.service"
sudo systemctl enable v4l2-relayd.service && \
  echo "=> SUCCESS" || \
  error "# Failed to enable: v4l2-relayd.service"
echo "# Start: v4l2-relayd.service"
sudo systemctl start v4l2-relayd.service && \
  echo "=> SUCCESS" || \
  error "Failed to start: v4l2-relayd.service"
