#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'
# Insert your AUR package manager and equivalent commands here if any.
# The script will try to use either yay or paru if not specified.
PKGMAN=()
MAKEPKG=(makepkg -si --noconfirm --needed)
# Script flags, best to leave them unless you want to 'hardcode' behaviours.
FLAG_YUY2_WA=false
FLAG_S2DISK_HACK=false
FLAG_EXPLICIT_WAYLAND=false
FLAG_REBOOT_AFTER_INSTALL=false
FLAG_QUIET_MODE=false
FLAG_MODERN=false

SUPPORTED_KERNELS=(linux linux-lts linux-zen linux-hardened)
# Classic LTS path (linux-lts 6.6.x) -- icamerasrc + v4l2-relayd + v4l2loopback
PKGS_CLASSIC=(base-devel
  intel-ivsc-firmware
  intel-ipu6-dkms-git
  intel-ipu6ep-camera-bin
  intel-ipu6ep-camera-hal-git
  v4l2loopback-dkms
  v4l2-relayd
  icamerasrc-git-fix
  gst-plugin-pipewire
  gst-plugins-good
)
# Modern path (linux 7.0+) -- patched DKMS + libcamera-ipu6 wraps libcamhal.
# No v4l2-relayd / v4l2loopback / icamerasrc shim needed. The libcamera-ipu6
# AUR package is built in install_libcamera_ipu6() below, not via PKGS.
PKGS_MODERN=(base-devel
  intel-ivsc-firmware
  intel-ipu6-dkms-git
  intel-ipu6ep-camera-bin
  intel-ipu6ep-camera-hal-git
  pipewire-libcamera
)

error() {
  printf "${RED}%s${NC} %s\n" "ERROR:" "${1}"
  exit 1
}

warn() {
  printf "${ORANGE}%s${NC} %s\n" "WARNING:" "${1}"
}

# Configure package manager here if necessary:
if [[ "${#PKGMAN[@]}" -eq 0 ]]; then
  if [[ -x "$(command -v yay)" ]]; then
    PKGMAN=(yay -S --noconfirm --needed)
  elif [[ -x "$(command -v paru)" ]]; then
    PKGMAN=(paru -S --noconfirm --needed)
  elif [[ -x "$(command -v pamac)" ]]; then
    PKGMAN=(pamac install --no-confirm)
  else
    error "\
Couldn't find a package manager, please install either yay, paru, \
pamac or set it manually in the script."
  fi
fi

# Builds the package if a directory with a PKGBUILD is found, or installs it from the AUR/repos if not.
build_and_install() {
  local pkg="${1}"
  if [ -f "${pkg}/PKGBUILD" ]; then
    echo "# Build and install package: ${1}"
    pushd "${pkg}" || error "Somehow unable to go to directory: ${pkg}"
    "${MAKEPKG[@]}" "${pkg}" || error "Failed to build/install: ${pkg}"
    popd || error "Unable to go back to working directory."
    echo "=> SUCCESS"
  else
    echo "# Install package from the AUR/repos: ${pkg}"
    if "${PKGMAN[@]}" "${pkg}"; then
      echo "=> SUCCESS"
    else
      if pacman -Qq "${pkg}"; then
        warn "Package failed to install, but is already installed. Trying to continue."
      else
        error "Couldn't find/unable to install: ${pkg}"
      fi
    fi
  fi
}

# ------------------------------------------------------------------------------
# Handles options
while getopts ":aswrqmh" opt; do
  case $opt in
    a)
      echo "Workaround for other applications will be installed."
      FLAG_YUY2_WA=true
      ;;
    s)
      echo "Hibernation workaround will be installed."
      FLAG_S2DISK_HACK=true
      ;;
    w)
      echo "Installing GST plugins for Wayland."
      FLAG_EXPLICIT_WAYLAND=true
      ;;
    r)
      echo "System will reboot after installation."
      FLAG_REBOOT_AFTER_INSTALL=true
      ;;
    q)
      echo "Quiet mode enabled. No installation messages will be printed."
      FLAG_QUIET_MODE=true
      ;;
    m)
      echo "Modern path: kernel 7.0+ + libcamera-ipu6 (no v4l2-relayd shim)."
      FLAG_MODERN=true
      ;;
    h)
      echo "Usage: ${0} [options]"
      echo "Options:"
      echo "  -m          Modern path for 'linux' kernel >= 7.0:"
      echo "                patched DKMS + libcamera-ipu6 (AUR), no"
      echo "                v4l2-relayd / v4l2loopback / icamerasrc shim."
      echo "                Without -m, the script installs the classic"
      echo "                LTS 6.6.x stack (icamerasrc + v4l2-relayd)."
      echo "  -a          Install workaround for other applications."
      echo "              (Ignored with -m; libcamhal does its own AGC.)"
      echo "  -s          Install workaround for hibernation."
      echo "  -w          Install GST plugins (bad) for Wayland. Only needed to specify if installing from the TTY."
      echo "              Normally, the script will check \$XDG_SESSION_TYPE to determine if Wayland is used."
      echo "              Right now, you are on '${XDG_SESSION_TYPE}'. If this is empty and you are going to use a Wayland DE, use this option."
      echo "  -r          Reboot after installation. Not recommended unless success is guaranteed."
      echo "  -q          Quiet mode by not printing builds and installs. Also not recommended. (Currently not working.)"
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

# Auto-suggest the modern path when running on linux 7.0+ but not booted on
# linux-lts. Don't force -- the user might explicitly want the classic stack.
if ! $FLAG_MODERN; then
  _running_kver=$(uname -r)
  _running_major=${_running_kver%%.*}
  if [[ "${_running_kver}" != *"lts"* ]] && [[ "${_running_major}" -ge 7 ]]; then
    warn "You are running ${_running_kver}. The classic LTS path will likely fail to build the DKMS module on this kernel."
    warn "Consider re-running with -m for the kernel 7.0+ / libcamera-ipu6 path. (See README.md.)"
  fi
fi

# Pick which package list to install
if $FLAG_MODERN; then
  PKGS=("${PKGS_MODERN[@]}")
else
  PKGS=("${PKGS_CLASSIC[@]}")
fi

# Need to have the correct headers installed before proceding with DKMS
# kernel_exists=true
# for kernel in "${SUPPORTED_KERNELS[@]}"; do
#   if pacman -Qq "${kernel}" 1>/dev/null 2>&1; then
#     echo "# Install headers for: ${kernel}"
#     build_and_install "${kernel}-headers"
#     kernel_exists=true
#   fi
# done
# $kernel_exists || error "No supported kernel found. Please install one of the following: ${SUPPORTED_KERNELS[*]}"

# Wayland gst-plugins-bad is only needed for the classic icamerasrc pipeline.
# The modern path uses libcamera natively via PipeWire; no extra gst plugin needed.
if ! $FLAG_MODERN; then
  if $FLAG_EXPLICIT_WAYLAND || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    echo "# Wayland detected or explicitly requested. Installing 'gst-plugins-bad'."
    PKGS+=(gst-plugins-bad)
  fi
fi

# Install all packages in order
for pkg in "${PKGS[@]}"; do
  build_and_install "${pkg}"
done

# Modern path: build + install this repo's libcamera-ipu6-fix, which is
# a superset of the AUR libcamera-ipu6 package with one extra patch on
# top (0003-...workerThread-drop-stale-buffers-instead-of-asserting)
# that fixes a recurring wireplumber SIGABRT observed 4x over 5 weeks
# -- see IPU6-investigation-2026-05-22.md gotcha #4.
#
# It provides= / conflicts= all five AUR libcamera-ipu6-* names so it
# is a drop-in replacement. It also replaces upstream libcamera /
# libcamera-ipa / libcamera-tools / gst-plugin-libcamera / python-libcamera.
# All five split packages must be installed in one pacman transaction to
# avoid the /usr/bin/libcamera-bug-report file conflict.
install_libcamera_ipu6() {
  local build_dir
  build_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/libcamera-ipu6-fix"
  if [ ! -d "$build_dir" ]; then
    error "libcamera-ipu6-fix/ not found next to install.sh at ${build_dir}"
  fi
  echo "# Build libcamera-ipu6-fix in ${build_dir}"
  pushd "$build_dir" >/dev/null
  # -f rebuilds even if a .pkg.tar.zst is already present. We don't use -i
  # so we can install all five split packages in a single sudo pacman -U.
  makepkg -f --noconfirm || error "Failed to build libcamera-ipu6-fix"
  echo "# Install all libcamera-ipu6-fix split packages atomically"
  sudo pacman -U --noconfirm ./*.pkg.tar.zst \
    || error "Failed to install libcamera-ipu6-fix split packages"
  popd >/dev/null
  echo "=> SUCCESS"
}

if $FLAG_MODERN; then
  install_libcamera_ipu6
fi

# Copy workarounds if requested
$FLAG_S2DISK_HACK && sudo install -m 744 workarounds/i2c_ljca-s2disk.sh /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh
if $FLAG_YUY2_WA && ! $FLAG_MODERN; then
  sudo mkdir -p /etc/systemd/system/v4l2-relayd.service.d
  sudo cp -f workarounds/override.conf /etc/systemd/system/v4l2-relayd.service.d/override.conf
elif $FLAG_YUY2_WA && $FLAG_MODERN; then
  warn "-a (YUY2 v4l2-relayd workaround) ignored: libcamera-ipu6 path has no v4l2-relayd."
fi

# v4l2-relayd.service is only relevant on the classic LTS path.
if ! $FLAG_MODERN; then
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
else
  cat <<'EOF'

# Browser flags needed for the libcamera-ipu6 path (one-time per user):
#
#   Firefox:   about:config -> media.webrtc.camera.allow-pipewire = true
#   Chromium:  chrome://flags -> "WebRtcPipeWireCamera" -> Enabled
#   Electron:  launch with --enable-features=WebRtcPipeWireCamera
EOF
fi

if ! $FLAG_REBOOT_AFTER_INSTALL; then
  echo -e "\n\nAll done.\nRemember to reboot upon succesful installation!"
  read -r -p "Reboot now? [y/N] " ans
  if [ "$ans" = "Y" ] || [ "$ans" = "y" ]; then
    FLAG_REBOOT_AFTER_INSTALL=true
  fi
fi

if $FLAG_REBOOT_AFTER_INSTALL; then
  echo "# Rebooting in 5 seconds..."
  sleep 5
  reboot
else
  echo "# Don't forget to reboot!"
  exit 0
fi
