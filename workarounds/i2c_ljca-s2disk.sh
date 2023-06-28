#!/bin/sh
# Path: /usr/lib/systemd/system-sleep/i2c_ljca-s2disk.sh
# Unloads and reloads the i2c_ljca module so resume from hibernation works.
# WARNING: This won't work on locked down kernels.
# This is supposed to be just a hack until this PR is merged:
# https://github.com/intel/ipu6-drivers/pull/116

stage=$1
op=$2

case $stage in
  pre)
    case $op in
      hibernate|hybrid-sleep)
        /usr/bin/modprobe -r i2c_ljca
        ;;
      suspend-then-hibernate)
        [ "$SYSTEMD_SLEEP_ACTION" = "hibernate" ] && /usr/bin/modprobe -r i2c_ljca
        ;;
    esac
    ;;
  post)
    # This might be entirely unnecessary since the module is somehow loaded after resume, but it doesn't hurt to be sure.
    case $op in
      hibernate|hybrid-sleep)
        /usr/bin/modprobe i2c_ljca
        ;;
      suspend-then-hibernate)
        [ "$SYSTEMD_SLEEP_ACTION" = "suspend" ] && /usr/bin/modprobe i2c_ljca
        ;;
    esac
    ;;
esac