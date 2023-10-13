#!/usr/bin/env bash

# Put your package manager and arguments for uninstallation without confirmation
PKGMAN=()
# The script will try to look for the following if $PKGMAN is empty and use the first one along with arguments:
SUPPORTED_HELPERS=(yay paru trizen)
HELPER_ARGS=(-Rsn --noconfirm)
# The package suffix used to install the patched packages to not conflict with
# their AUR counter part:
PKG_SUFFIX=fix
INSTALLED_PKG_LIST=ipu6-pkgs.txt
# Temporary
PKGS=(intel-ipu6-dkms-git
      intel-ipu6ep-camera-bin
      intel-ipu6ep-camera-hal-git
      v4l2loopback-dkms-git
      v4l2-relayd
      icamerasrc-git
)

# Functions go here
error() {
  printf "${RED}%s${NC} %s\n" "ERROR:" "${1}"
  exit 1
}

warn() {
  printf "${ORANGE}%s${NC} %s\n" "WARNING:" "${1}" >&2
}

uninstall_pkg() {
  local pkg="$1"
  if pacman -Qq "${pkg}-${PKG_SUFFIX}" >/dev/null 2>&1; then
    warn "Uninstalling ${pkg}-${PKG_SUFFIX}"
    "${PKGMAN[@]}" "${pkg}-${PKG_SUFFIX}"
  elif pacman -Qq "${pkg}" >/dev/null 2>&1; then
    warn "Uninstalling $pkg"
    "${PKGMAN[@]}" "${pkg}"

  else
    warn "$pkg is not installed, skipping"
  fi
}

# Configure package manager here if necessary:
if [[ "${#PKGMAN[@]}" -eq 0 ]]; then
  helper_exists=false
  for helper in "${SUPPORTED_HELPERS[@]}"; do
    if [[ -x "$(command -v "$helper")" ]]; then
      PKGMAN=("$helper" "${HELPER_ARGS[@]}")
      helper_exists=true
    fi
  done
  $helper_exists || error "Couldn't find a package manager, please install any of these helpers: ${SUPPORTED_HELPERS[*]}"
fi

sudo systemctl disable --now v4l2-relayd.service

if [[ -f "${INSTALLED_PKG_LIST}" ]]; then
  warn "Uninstalling packages from ${INSTALLED_PKG_LIST}"
  for pkg in $(tac "${INSTALLED_PKG_LIST}"); do
      uninstall_pkg "$pkg"
  done
else
  # Use the list in this script
  for (( i=${#PKGS[@]}-1 ; i>=0 ; i-- )) ; do
      uninstall_pkg "${PKGS[i]}"
  done
fi

# Get rid of workarounds if they exist:
[[ -d /etc/systemd/system/v4l2-relayd.service.d ]] && sudo rm -rf /etc/systemd/system/v4l2-relayd.service.d/
[[ -f /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh ]] && sudo rm -f /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh
