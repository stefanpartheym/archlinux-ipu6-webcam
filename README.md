# archlinux-ipu6-webcam

This repository is supposed to provide an easy installation for the patched Intel IPU6 camera drivers. Currently tested on the following kernel versions:

- `6.1.4-arch1-1`
- `6.1.4-zen2-1-zen`
- `6.1.9-arch1-1`

All PKGBUILDs in this repository are taken from [this comment](https://bbs.archlinux.org/viewtopic.php?pid=2062371#p2062371) on the Archlinux forums. From `v1.0.0` on, the PKGBUILDs are slightly modified to avoid conflicts with their AUR counter parts.

## Install

Run shell script `install.sh` to install all necessary packages and enable/start services. Make sure to reboot after a successfull installation.

## Upgrading to `v1.0.0`

If you already installed an older version of this repository (pre `v1.0.0`), it is important to uninstall the old packages first, because as of `v1.0.0` custom package names are suffixed with `-archfix` to avoid conflicts with their AUR counter parts.

Please follow the steps below to upgrade:

1. Uninstall using `uninstall.sh` from tag `v0.1.0`.
2. Run `git pull` to update to tag `v1.0.0`.
3. Install using `install.sh` as described in the *Install* section.

## Upgrading to `v1.1.0`

In version `v1.1.0` package name suffix `-archfix` is renamed to `-fix` to comply to AUR package naming conventions.
Upgrading to `v1.1.0` is the same as upgrading to `v1.0.0`. Please read *Upgrading to `v1.0.0`* for necessary steps to upgrade to `v1.1.0` from any tag prior to it.

## Test

### Script `test.sh`

Test your webcam by running script `test.sh`.

### Chromium-based browsers

If you want to check, whether your camera works in Chromium-based Browsers (like Chrome, Brave, etc.) you can use [this website](https://webrtc.github.io/samples/src/content/devices/input-output/) to do so. To use Firefox, read *Make camera work in Firefox and some Electron-based applications*

### GNOME Cheese

You can also use Cheese (a image/video capture software from GNOME) to test your video stack. To do so, identify the name of the device exposed by your video stack with `v4l2-ctl --list-devices`. Then call Cheese : `sudo cheese -d <your_device_name>`.

Example: `sudo cheese -d "Virtual Camera"`

## Uninstall

Run shell script `uninstall.sh` to disable/stop services and uninstall all previously installed packages.

## Make camera work in Firefox and some Electron-based applications

The camera should now work without any major issues in many applications (e.g. Chromium, OBS Studio) but it might not work correctly in some other ones (e.g. FireFox, Discord) due to the default NV12 format not being supported.

This can be fixed by running the install.sh script with a `--workaround` flag, which will edit `/etc/systemd/system/v4l2-relayd.service.d/override.conf` to convert the camera output to the YUY2 format.

Please note that some applications (e.g. GNOME Cheese) might still not work. This is due to Intel's driver just being low-quality. There is an [issue](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/1) curently open for this.


## Tips and tricks

### Remove the warnings from an AUR helper

Some AUR helpers will warn you of some packages installed by `install.sh` not being in the Arch User Repository. There is usually a way to prevent these messages from showing up using the configuration file of the helper.

For example, if you're using paru, you might want to add the following to your `/etc/paru.conf` (or your user's config):

```
NoWarn = intel-ipu6-dkms-git-fix  intel-ipu6ep-camera-hal-git-fix  v4l2-relayd  v4l2loopback-dkms-git-fix
```