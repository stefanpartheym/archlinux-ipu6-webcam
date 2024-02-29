# archlinux-ipu6-webcam

This repository is supposed to provide an easy installation for the patched Intel IPU6 camera drivers.

All PKGBUILDs in this repository are taken from [this comment](https://bbs.archlinux.org/viewtopic.php?pid=2062371#p2062371) on the Archlinux forums. From `v1.0.0` on, the PKGBUILDs are slightly modified to avoid conflicts with their AUR counter parts.

## Supported kernels

**NOTE:** Due to frequent changes in the stable kernels, it is recommended to use LTS kernels in order to minimize issues when upgrading the kernel.

**:warning: WARNING:** Currently kernel versions 6.7.x are not supported.

LTS kernels:

- `6.6.18-1-lts`

Stable kernels:

- `6.1.4-arch1-1`
- `6.3.7-arch1-1`
- `6.4.3-arch1-1`
- `6.4.7-arch1-2`
- `6.4.8-arch1-1`
- `6.4.12-arch1-1`
- `6.5.5-arch1-1` (see [issue #42](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/40))
- `6.5.6-arch2-1`
- `6.5.7-arch1-1`
- `6.5.8-arch1-1`
- `6.5.9-arch2-1`
- `6.6.1-arch1-1` (see [issue #53](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/53))
- `6.6.7-arch1-1`
- `6.6.8-arch1-1`
- `6.6.10-arch1-1`

Zen kernels:

- `6.1.4-zen2-1-zen`
- `6.6.7-zen-1-zen`
- `6.6.9-zen1-zen`

Manjaro kernels:

- `6.1.31-2-MANJARO`
- `6.4.1-5-MANJARO`
- `6.5.5-1-MANJARO` (see [issue #21](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/21))

## Supported devices

Known working on these devices:

- `Lenovo ThinkPad X1 Carbon Gen 10` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/pull/22#issuecomment-1587014417
- `Dell XPS 13 9315`
- `Dell XPS 13 Plus 9320` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/pull/22#issue-1751399891
- `Dell Latitude 7440` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/29
- `Dell Precision 5480` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/47
- `Dell Latitude 7340` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/56

May work on many more Alder Lake laptops using Intel's IPU6 cameras. Let us know if it does on yours!
Support for Tiger Lake and beyond Alder Lake is in progress.

This should work with all Arch Linux installation and perhaps even EndeavourOS. This installion has been tested and should work on a fresh Manjaro installation (https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/26#issuecomment-1615873036) but there are several issues reported by Manjaro users. Testing and more issues from Manjaro users are welcome.

## Install

Run shell script `install.sh` to install all necessary packages and enable/start services. Make sure to reboot after a successful installation.

## Test

### Script `test.sh`

Test your webcam by running script `test.sh`.

### Chromium and Firefox-based browsers

If you want to check, whether your camera works in Chromium-based Browsers (like Chrome, Brave, etc.) you can use [this website](https://webrtc.github.io/samples/src/content/devices/input-output/) to do so. Firefox from version 115 onwards should also work.

### GNOME Cheese

You can also use Cheese (a image/video capture software from GNOME) to test your video stack. To do so, identify the name of the device exposed by your video stack with `v4l2-ctl --list-devices`. Then call Cheese : `sudo cheese -d <your_device_name>`.

Example: `sudo cheese -d "Virtual Camera"`

## Uninstall

Run shell script `uninstall.sh` to disable/stop services and uninstall all previously installed packages.

## Make camera work in some Electron-based applications

The camera should now work without any major issues in many applications (e.g. Chromium, OBS Studio, Firefox >= 115) but it might not work correctly in some other ones (e.g. Discord) due to the default NV12 format not being supported.

This can be fixed by running `./install.sh -a`, which will add `/etc/systemd/system/v4l2-relayd.service.d/override.conf` to convert the camera output to the YUY2 format.

Please note that some applications (e.g. GNOME Cheese) might still not work. This is due to Intel's driver just being low-quality. There is an [issue](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/1) curently open for this.

## Hibernation support

The module 'i2c_ljca' breaks resuming from hibernation. To fix this, doing `modprobe -r i2c_ljca` before hibernating is necessary. A script is provided by running `./install.sh -s`. This script will be executed before hibernating and after resume.
Since this is using `modprobe`, this will most likely not work on kernel lockdowns!

If you want both workarounds, you can run `./install.sh -as`.

## Tips and tricks

### Solving error `WARNING: erroneous pipeline: no element "icamerasrc"`

When using `yay` as an AUR helper, chances are, that you will experience the following error message after upgrading to a newer kernel version:
`WARNING: erroneous pipeline: no element "icamerasrc"`
This is probably due to `yay` is using the cached `icamerasrc-git` package from a previous install.
Make sure to remove the cache with `rm -rf ~/.cache/yay/icamerasrc-git` to force a clean build and installation of the package.

### Remove the warnings from an AUR helper

Some AUR helpers will warn you of some packages installed by `install.sh` not being in the Arch User Repository. There is usually a way to prevent these messages from showing up using the configuration file of the helper.

For example, if you're using paru, you might want to add the following to your `/etc/paru.conf` (or your user's config):

```
NoWarn = intel-ipu6ep-camera-bin  intel-ipu6ep-camera-hal-git-fix  v4l2-relayd  v4l2loopback-dkms-git-fix
```
