#!/bin/sh

# Configure package manager here if necessary:
if [ -f /bin/yay ]; then
  PKGMAN="yay -S --noconfirm"
elif [ -f /bin/paru ]
  PKGMAN="paru -S --noconfirm"
else
  echo "ERROR: Couldn't find a package manager, please configure it manually"
  exit 1
fi

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


if [ "$1" = "--workaround" ]; then
  PATH="/etc/systemd/system/v4l2-relayd.service.d/"
  echo "# Creating /etc/systemd/system/v4l2-relayd.service.d/override.conf"
  sudo mkdir -p /etc/systemd/system/v4l2-relayd.service.d && \
  sudo echo -e "[Service]\nExecStart=\nExecStart=/bin/sh -c \'DEVICE=\$(grep -l -m1 -E \"^\${CARD_LABEL}\$\" /sys/devices/virtual/video4linux/*/name | cut -d/ -f6); exec /usr/bin/v4l2-relayd -i \"\${VIDEOSRC}\" \$\${SPLASHSRC:+-s \"\${SPLASHSRC}\"} -o \"appsrc name=appsrc caps=video/x-raw,format=\${FORMAT},width=\${WIDTH},height=\${HEIGHT},framerate=\${FRAMERATE} ! videoconvert ! video/x-raw,format=YUY2 ! v4l2sink name=v4l2sink device=/dev/\$\${DEVICE}\"\'" \
  sudo tee /etc/systemd/system/v4l2-relayd.service.d/override.conf && \
  echo "=>SUCCESS" || \
  error "Failed to write: /etc/systemd/system/v4l2-relayd.service.d/override.conf"

  echo "# Restart: v4l2-relayd.service"
  sudo systemctl restart v4l2-relayd.service && \
    echo "=> SUCCESS" || \
    error "Failed to restart: v4l2-relayd.service"
  
  echo "# Reloading systemd daemon"
  sudo systemctl daemon-reload && \
    echo "=> SUCCESS" || \
    error "Failed to reload systemctl daemon"
fi

