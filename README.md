# archlinux-ipu6-webcam

> [!NOTE]
> **`kernel-7-dkms-fixes` branch** — adds support for **`linux 7.0+`**.
> The DKMS module is patched against ~9 kernel-API changes that
> accumulated through `6.13`, `6.15`, `6.17`, `6.18` and `7.0`. The
> `-ep-fix` userspace PKGBUILDs are updated for gcc 16 and declared as
> drop-ins for the `libcamera-ipu6` AUR package. See
> [IPU6-investigation-2026-05-22.md](IPU6-investigation-2026-05-22.md)
> for the full breakdown and migration steps.

> [!WARNING]
> If you are on an **LTS kernel** in the `6.6.x` series, use this repo's
> classic install path (`./install.sh`). It installs the
> `icamerasrc + v4l2-relayd + v4l2loopback` shim chain.
>
> If you are on **`linux` mainline (`7.0+`)**, use the **`libcamera-ipu6`
> path** described below — the classic shim chain no longer applies, the
> upstream kernel ships IPU6 ISYS natively, and image quality is restored
> by routing PipeWire through the proprietary `libcamhal` via the kervel
> libcamera fork.

> [!NOTE]
>
> Intel's IPU6 **ISYS** driver was upstreamed in kernel `6.10`. **PSYS**
> (the hardware ISP) is still out-of-tree — that's the load-bearing
> module DKMS provides, and the reason this repo is still useful on
> modern kernels: it gets you back the hardware ISP + Intel's calibrated
> `.aiqb` tuning blobs, which the upstream libcamera `simple` pipeline
> + SoftISP cannot match.
>
> For reference see:
>
> - [kernel.org](https://lore.kernel.org/lkml/20240516080159.76e8b45d@sal.lan/)
> - [phoronix — IPU6 in Linux 6.10](https://www.phoronix.com/news/Intel-IPU6-Media-In-Linux-6.10)
> - [Javier Tia — Intel IPU6 Webcam on Linux](https://jetm.github.io/blog/posts/ipu6-webcam-libcamera-on-linux/)

This repository provides an easy installation for the patched Intel IPU6
camera drivers, plus PKGBUILDs that act as drop-in replacements for the
AUR `intel-ipu6-*` packages on Alder Lake hardware.

All PKGBUILDs in this repository are originally taken from [this comment](https://bbs.archlinux.org/viewtopic.php?pid=2062371#p2062371) on the Archlinux forums. From `v1.0.0` on, the PKGBUILDs are slightly modified to avoid conflicts with their AUR counter parts. The `kernel-7-dkms-fixes` branch adds the patches listed above.

## Supported kernels

| Kernel                     | Path                                                                   | Notes                                                                                              |
|----------------------------|------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| `linux-lts 6.6.x` (≥ `6.6.55`) | Classic — `./install.sh`                                              | Original supported configuration. DKMS module builds; uses `icamerasrc` + `v4l2-relayd` + `v4l2loopback`. |
| `linux 7.0+` (e.g. `7.0.9`)| Modern — DKMS + `libcamera-ipu6` (AUR)                                 | Patched DKMS module builds on the new kernel API. Userspace via the kervel libcamera fork.         |
| `linux 6.10` … `6.19`      | Same as 7.0+ (DKMS + `libcamera-ipu6`)                                 | The patches target `6.13`+; older kernels in this range may need `#if` guard adjustments.          |
| `linux-lts 6.12`           | **Not supported** by this branch                                        | See [#95](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/95). DKMS regressed on the new LTS. |

## Supported devices

Known working on these devices:

- `Lenovo ThinkPad X1 Carbon Gen 10` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/pull/22#issuecomment-1587014417
- `Dell XPS 13 9315`
- `Dell XPS 13 Plus 9320` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/pull/22#issue-1751399891
- `Dell Precision 5480` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/47
- `Dell Latitude 7340` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/56
- `Dell Latitude 7440` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/29
- `Dell Latitude 7640` from https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/91

May work on many more Alder Lake laptops using Intel's IPU6 cameras. Let us know if it does on yours!
Support for Tiger Lake and beyond Alder Lake is in progress.

This should work with all Arch Linux installation and perhaps even EndeavourOS. This installion has been tested and should work on a fresh Manjaro installation (https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/26#issuecomment-1615873036) but there are several issues reported by Manjaro users. Testing and more issues from Manjaro users are welcome.

## Install

### On `linux 7.0+` — recommended (`libcamera-ipu6` path)

This path is for users on the modern mainline kernel. It uses the
upstream `intel_ipu6_isys` driver shipped with the kernel and adds:

1. The patched out-of-tree `intel_ipu6_psys` module from this branch
   (DKMS).
2. The proprietary `libcamhal` + `.aiqb` tuning blobs.
3. The [`libcamera-ipu6`](https://aur.archlinux.org/packages/libcamera-ipu6)
   AUR package — a fork of libcamera that wraps `libcamhal` and exposes
   the camera as a native libcamera node (no `v4l2-relayd`, no
   `v4l2loopback`).

Easiest: `./install.sh -m` does all of it. Manual step-by-step:

```fish
# 1. Build + install the patched DKMS module (this repo)
cd ~/src/archlinux-ipu6-webcam/intel-ipu6-dkms-git
makepkg -si

# 2. Build + install the gcc-16-fixed Alder Lake camera-bin + camera-hal
cd ~/src/archlinux-ipu6-webcam/intel-ipu6ep-camera-bin
makepkg -si
cd ~/src/archlinux-ipu6-webcam/intel-ipu6ep-camera-hal-git
makepkg -si

# 3. Reboot to load the DKMS module
sudo reboot

# After reboot, confirm the kernel modules + PSYS device are present:
lsmod | grep ipu6        # expect: intel_ipu6, intel_ipu6_isys, intel_ipu6_psys
ls /dev/ipu-psys0        # must exist

# 4. Build the libcamera fork -- this repo's libcamera-ipu6-fix, which is
#    the AUR libcamera-ipu6 + one extra patch that fixes a recurring
#    wireplumber crash in IPU6CameraData::workerThread(). See
#    IPU6-investigation-2026-05-22.md gotcha #4.
cd ~/src/archlinux-ipu6-webcam/libcamera-ipu6-fix
makepkg  # build all five split packages

# 5. Install ALL split packages in one transaction. The -fix variants
#    provide= + replace= the AUR libcamera-ipu6-* names AND upstream
#    libcamera / libcamera-ipa / libcamera-tools / gst-plugin-libcamera /
#    python-libcamera, so pacman swaps everything in one atomic step.
sudo pacman -U *.pkg.tar.zst

# 6. Restart the PipeWire stack so it picks up the new libcamera
systemctl --user restart pipewire pipewire-pulse wireplumber xdg-desktop-portal

# 7. Verify: pipeline handler should now say "ipu6", not "simple"
cam -l 2>&1 | grep -iE "ipu6|simple|libcamhal"
```

To enable PipeWire camera capture in browsers / Electron apps:

- **Firefox**: `about:config` → `media.webrtc.camera.allow-pipewire = true`.
- **Chromium / Chrome / Brave**: `chrome://flags` → `WebRtcPipeWireCamera` → Enabled.
- **Signal / Slack / Discord** etc.: launch with `--enable-features=WebRtcPipeWireCamera`.

### On `linux-lts 6.6.x` — classic path (`./install.sh`)

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
This error most likely occurs when running the `test.sh` script.
This is probably due to `yay` is using the cached `icamerasrc-git` package from a previous install.
In order to fix this, run the following command:

```sh
yay \
  --cleanmenu=false \
  --diffmenu=false \
  --editmenu=false \
  --rebuild \
  -S icamerasrc-git
```

You may also need to delete gstreamer's cache in your `.cache` directory.

### Remove the warnings from an AUR helper

Some AUR helpers will warn you of some packages installed by `install.sh` not being in the Arch User Repository. There is usually a way to prevent these messages from showing up using the configuration file of the helper.

For example, if you're using paru, you might want to add the following to your `/etc/paru.conf` (or your user's config):

```
NoWarn = intel-ipu6ep-camera-bin  intel-ipu6ep-camera-hal-git-fix  v4l2-relayd  v4l2loopback-dkms-git-fix
```
