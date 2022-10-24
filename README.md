# archlinux-ipu6-webcam

This repository is supposed to provide an easy installation for the patched Intel IPU6 camera drivers. I tested the installation on kernel `6.0.2-arch1-1`.

All PKGBUILDs in this repository are taken from [this comment](https://bbs.archlinux.org/viewtopic.php?pid=2062371#p2062371) on the Archlinux forums.

## Install

Run shell script `install.sh` to install all necessary packages and enable/start services. Make sure to reboot after a successfull installation.

## Test

Test your webcam by running script `test.sh`.

## Uninstall

Run shell script `uninstall.sh` to disable/stop services and uninstall all previously installed packages.

## Make camera work in Chrome/Firefox and electron-based applications

Unfortunately I couldn't figure out how to make the webcam available in web browsers and other electron-based applications out of the box.

However, [this post](https://stackoverflow.com/q/68433415) on stack overflow mentions the a workaround for this (see **Solution (long version)** for more details):

```shell
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback exclusive_caps=1
```

NOTE: You probably need to stop `v4l2-relayd.service` before you try to unload the `v4l2loopback` module, otherwise you'll receive the following error:

```text
modprobe: FATAL: Module v4l2loopback is in use.
```

Finally, you can test your setup [in your browser](https://webrtc.github.io/samples/src/content/devices/input-output/).
