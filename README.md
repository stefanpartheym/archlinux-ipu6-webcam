# archlinux-ipu6-webcam

This repository is supposed to provide an easy installation for the patched Intel IPU6 camera drivers. Currently tested on `6.1.4-arch1-1` and `6.1.4-zen2-1-zen`

All PKGBUILDs in this repository are taken from [this comment](https://bbs.archlinux.org/viewtopic.php?pid=2062371#p2062371) on the Archlinux forums.

## Install

Run shell script `install.sh` to install all necessary packages and enable/start services. Make sure to reboot after a successfull installation.

## Test

Test your webcam by running script `test.sh`.

## Uninstall

Run shell script `uninstall.sh` to disable/stop services and uninstall all previously installed packages.

## Make camera work in Chrome/Firefox and electron-based applications

The camera should now work without any major issues in many applications (e.g. Chromium, OBS Studio) but it might not work correctly in some other applications (e.g. FireFox, Discord) due to the default NV12 format not being supported.

This can be fixed by running the install.sh script with a `--workaround flag`, which will edit `/etc/systemd/system/v4l2-relayd.service.d/override.conf` to convert the camera output to the YUY2 format.

Please note that some applications (e.g. GNOME Cheese) will still very likely not work. This is due to Intel's driver just being low-quality. There is an [issue](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/1) curently open for this.

