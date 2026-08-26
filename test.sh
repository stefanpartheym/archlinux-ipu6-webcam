#!/usr/bin/env bash
#
# Smoke test: pull a single live preview through the installed camera stack.
# Auto-detects which stack is installed:
#   - libcamera-ipu6 (modern, kernel 7.0+ path) -> gst-launch libcamerasrc
#   - icamerasrc-git[-fix] (classic LTS path)   -> sudo gst-launch icamerasrc

# Configure sink depending on running window manager
case "${XDG_SESSION_TYPE:-}" in
  wayland) SINK=waylandsink ;;
  x11)     SINK=ximagesink ;;
  *)       SINK=autovideosink ;;
esac

WIDTH=1280
HEIGHT=720

# --- Stack B: libcamera-ipu6 (kervel fork wrapping libcamhal) --------------
# Runs as the regular user. The IPU6 pipeline handler is selected via
# LIBCAMERA_PIPELINES_MATCH_LIST from /usr/lib/environment.d/60-libcamera-ipu6.conf
# (loaded by PAM at login). If you launched this from a shell that pre-dates
# the libcamera-ipu6 install, log out + back in first.
if pacman -Qq libcamera-ipu6 >/dev/null 2>&1; then
  echo "# Stack B (libcamera-ipu6) detected -- using libcamerasrc, no sudo."
  exec gst-launch-1.0 libcamerasrc \
    ! "video/x-raw,format=NV12,width=${WIDTH},height=${HEIGHT}" \
    ! videoconvert ! "${SINK}"
fi

# --- Stack A: classic LTS (icamerasrc + v4l2-relayd + v4l2loopback) --------
# Needs sudo: gst-launch must open the v4l2-relayd-managed loopback as root.
if pacman -Qq icamerasrc-git-fix >/dev/null 2>&1 \
   || pacman -Qq icamerasrc-git >/dev/null 2>&1; then
  echo "# Stack A (classic icamerasrc) detected -- using sudo gst-launch."
  exec sudo -E LANG=C gst-launch-1.0 icamerasrc \
    ! "video/x-raw,format=NV12,width=${WIDTH},height=${HEIGHT}" \
    ! videoconvert ! "${SINK}"
fi

cat >&2 <<'EOF'
ERROR: Neither libcamera-ipu6 nor icamerasrc is installed.

Install one of the two stacks first:
  ./install.sh         # classic path, for linux-lts 6.6.x
  ./install.sh -m      # modern path, for linux 7.0+ (libcamera-ipu6)

See README.md for details.
EOF
exit 1
