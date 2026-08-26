# IPU6 webcam on Arch Linux — investigation notes (2026-05-22)

Notes from debugging a Dell laptop (Alder Lake IPU6EP, OV01A10 sensor) whose
webcam stopped working after `pacman -Syu`. Captures the full state of
the IPU6 stack on Arch in May 2026, what works, what doesn't, and why.

## Hardware

```
0000:00:05.0 Multimedia controller [0480]: Intel Corporation Alder Lake
  Imaging Signal Processor [8086:465d] (rev 02)
  Subsystem: Dell Device [1028:0af3]
Sensor: ov01a10 17-0036  (1 MP OmniVision, MIPI CSI-2)
```

## Initial state

- Running kernel: `linux-lts 6.6.31-1-lts` (May 2024) — predates this repo's
  documented minimum (`6.6.55+`), yet it worked.
- Mainline kernel installed but not booted: `linux 7.0.9.arch1-1`.
- This repo's custom stack was installed:
  `intel-ipu6-dkms-git-fix`, `intel-ipu6ep-camera-bin-fix`,
  `intel-ipu6ep-camera-hal-git-fix`, `icamerasrc-git-fix`,
  `v4l2-relayd r42.6fd6b6a-1`, `v4l2loopback-dkms`.

## What broke (proximate cause)

`/var/log/pacman.log` showed two changes from the 2026-05-18/21 `-Syu`:

1. **2026-05-18** — `linux: 6.19.10 → 7.0.8 → 7.0.9`. DKMS rebuild of
   `ipu6-drivers/r165.cfb7af1e5` against `7.0.9-arch1-1` **failed**
   (`==> WARNING: dkms install ... exited 10` — see
   `/var/lib/dkms/ipu6-drivers/r165.cfb7af1e5/build/make.log`,
   compile error on `drivers/media/pci/intel/ipu6/../ipu-trace.o`).
   Did not affect the running LTS kernel, but flagged that the
   out-of-tree driver is end-of-life vs current kernel API.
2. **2026-05-21** — `v4l2-relayd r42.6fd6b6a-1 → 0.2.0-1`. The
   `pacman -Syu` batch ran with a long `--ignore` list, but
   `v4l2-relayd` wasn't on it, so the AUR/upstream version replaced
   the repo's custom build. The 0.2.0 version doesn't carry this repo's
   wayland-fix patch (commit `d1c471c`), and the relay started
   exiting immediately — apps saw an empty `/dev/video0` loopback.

## Immediate fix (back to working on LTS 6.6.31)

Restored repo's custom packages by re-running `./install.sh`:

```fish
yay -R icamerasrc-git              # remove conflicting AUR version
cd ~/src/archlinux-ipu6-webcam
./install.sh                       # rebuilds + downgrades to repo's r42
```

To prevent the silent swap from recurring, the custom packages should be
added to `IgnorePkg` in `/etc/pacman.conf`:

```
IgnorePkg = v4l2-relayd icamerasrc-git-fix intel-ipu6-dkms-git-fix \
            intel-ipu6ep-camera-bin-fix intel-ipu6ep-camera-hal-git-fix
```

## Bigger picture: this repo is end-of-life for kernel ≥ 6.10

- `README.md` of this repo says supported kernels are LTS `6.6.55+`.
- IPU6 ISYS driver upstreamed in kernel `6.10` ([Phoronix](https://www.phoronix.com/news/Intel-IPU6-Media-In-Linux-6.10)).
- `intel/ipu6-drivers` out-of-tree repo doesn't build on kernel `6.17+`:
  - [intel/ipu6-drivers#423](https://github.com/intel/ipu6-drivers/issues/423) — Ubuntu 24.04, kernel 6.17, broken.
  - [Launchpad #2131913](https://bugs.launchpad.net/bugs/2131913) — `intel-ipu6-dkms fails to build on 6.17.0-6-generic`.
  - This repo's own [#95](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/95) (6.12 LTS regression), [#89](https://github.com/stefanpartheym/archlinux-ipu6-webcam/issues/89) (6.10).
- Linux 7.0 ([Phoronix](https://www.phoronix.com/news/Linux-7.0-Released)) was released 2026-04-12. Linus bumped 6.19 → 7.0 purely
  because he rolls over at x.19; no major API break vs 6.18/6.19. So
  anything broken on 6.17/18/19 stays broken on 7.0. Linux 7.0 is **not**
  LTS — current LTS is **6.18** (supported until Dec 2028).

Conclusion: **this repo's stack only continues to work on `linux-lts 6.6.x`**.
Newer kernels need a different approach.

## Stack alternatives on kernel 7.0+ (Alder Lake IPU6EP + OV01A10)

### A. Upstream `libcamera` Simple pipeline + SoftISP

Tried this. State of play on 2026-05-22:

| Layer        | Status                                            |
|--------------|---------------------------------------------------|
| Kernel       | `intel-ipu6`, `intel-ipu6-isys`, `ivsc-csi`, `ov01a10`, LJCA bridge modules — all upstream and loaded. ✓ |
| Firmware     | `linux-firmware-intel` ships `ipu6epadln_fw.bin`. ✓ |
| Userspace    | `libcamera 0.7.1` + `libcamera-ipa` + `pipewire-libcamera` + `gst-plugin-libcamera`. ✓ |
| Sensor tuning| **`ov01a10.yaml` not shipped in libcamera 0.7.1** — falls back to `uncalibrated.yaml`. ✗ |
| AGC          | **Bang-bang controller** with fixed 10% step → **brightness flicker**. ✗ |
| Hardware ISP | **PSYS not used at all** — all processing on CPU. Worse quality. ✗ |

Workarounds applied:
- Disabled `Agc:` in `/usr/share/libcamera/ipa/simple/uncalibrated.yaml`
  to stop flicker. Backed up the original; added `NoUpgrade = usr/share/libcamera/ipa/simple/uncalibrated.yaml` to `/etc/pacman.conf`.
- Manual `analogue_gain` / `exposure` via udev rule:
  ```
  /etc/udev/rules.d/99-ov01a10-defaults.rules
  ACTION=="add", SUBSYSTEM=="video4linux", ATTR{name}=="ov01a10*", \
    RUN+="/usr/bin/v4l2-ctl -d $devnode --set-ctrl=analogue_gain=2048 \
                                         --set-ctrl=exposure=1500"
  ```
- Removed the no-longer-useful shim packages: `v4l2-relayd`,
  `v4l2-relayd-debug`, `v4l2loopback-dkms`.

Result: works in Firefox (`media.webrtc.camera.allow-pipewire=true`) and
Chromium (`chrome://flags` → `WebRtcPipeWireCamera` enabled), but image is
visibly worse than the old stack — washed-out colors, manually pinned
exposure, no auto-adaptation to lighting.

Tracking:
- [libcamera-devel: PATCH v4 proportional AGC](https://lists.libcamera.org/pipermail/libcamera-devel/2026-April/058416.html) — will fix flicker; not yet in a release.
- [intel/ipu6-camera-hal#161](https://github.com/intel/ipu6-camera-hal/issues/161) — OV01A10 needs proper tuning yaml + sensor helper.
- [Javier Tia's migration guide](https://jetm.github.io/blog/posts/ipu6-webcam-libcamera-on-linux/) — most comprehensive reference for this stack.

### B. `libcamera-ipu6` AUR — wraps `libcamhal` via libcamera pipeline handler

`https://aur.archlinux.org/packages/libcamera-ipu6` — fork of libcamera
from `kervel/libcamera@ipu6-pipeline-handler` packaged for Arch by
"Stick" (2026-04-30). Cloned to `~/src/libcamera-ipu6/`.

What it does:

```
sensor → ISYS+PSYS → libcamhal (Intel proprietary) →
   → libcamera ipu6 pipeline handler (kervel fork) → PipeWire → app
```

Restores the hardware ISP path **and** keeps native libcamera integration
(no `v4l2-relayd`/`v4l2loopback`). Ships an `ov01a10.yaml` and a sensor
helper patch for OV01A10 — explicit support for our exact sensor.
Tested by the maintainer on a Dell Latitude 5470 with the same chip
family.

Runtime dependencies (from PKGBUILD):
- `intel-ipu6-camera-hal-git` (AUR) — proprietary `libcamhal`.
- `intel-ipu6-camera-bin` (AUR) — Intel `.aiqb` tuning blobs.
- **`intel-ipu6-dkms-git` (AUR) — out-of-tree PSYS kernel module.**

**The catch on kernel 7.0.9**: the same DKMS module that already failed
to build for `linux 7.0.9` is required at runtime. Without
`/dev/ipu-psys0`, `libcamhal` can't initialize and the IPU6 pipeline
handler degrades or fails. So `libcamera-ipu6` works only on a kernel
where `intel-ipu6-dkms-git` builds — i.e., `linux-lts 6.6.x`.

### C. Stay on this repo's stack with `linux-lts 6.6.31`

Status quo. Works today, fragile against future `pacman -Syu`
unless `IgnorePkg` is set. Uses `icamerasrc + v4l2-relayd + v4l2loopback`
shim — older architecture but battle-tested for this hardware.

## Decision matrix

| Setup                                   | Kernel       | Image quality | Maintenance | Notes |
|-----------------------------------------|--------------|---------------|-------------|-------|
| This repo (status quo on LTS)           | `6.6.31-lts` | Excellent (HW ISP + Intel tuning) | High (`IgnorePkg`, stuck on old LTS) | Currently active |
| Upstream libcamera Simple on mainline   | `7.0.9`      | Poor (SoftISP, no tuning, AGC off → dark) | Low (everything in repos) | Currently active on `linux` kernel |
| `libcamera-ipu6` AUR on LTS             | `6.6.31-lts` | Excellent (HW ISP) + modern libcamera/PipeWire integration | Medium | **Recommended** if image quality matters |
| `libcamera-ipu6` AUR on mainline 7.0.9  | `7.0.9`      | N/A — DKMS doesn't build | N/A | Blocked until intel/ipu6-drivers gets 7.0 patches |

## Current configuration (as of end of session, 2026-05-22)

Boots: dual kernel (LTS 6.6.31 + mainline 7.0.9), each able to use the
camera with their respective userspace stacks:

- **On LTS 6.6.31**: this repo's custom packages all installed and working.
  `IgnorePkg` not yet set in `pacman.conf` (TODO).
- **On mainline 7.0.9**: upstream `libcamera 0.7.1` + `libcamera-ipa` +
  `gst-plugin-libcamera` + `pipewire-libcamera`. AGC disabled in
  `uncalibrated.yaml` (with `NoUpgrade` in `pacman.conf`). Manual
  exposure via udev rule (`/etc/udev/rules.d/99-ov01a10-defaults.rules`).
  Shim packages removed.

## Useful commands (reference)

```fish
# Identify hardware
lspci -nnk | grep -A3 -i "imag\|camera"
ls /sys/class/video4linux/v4l-subdev*/name | xargs -I{} sh -c 'echo {}; cat {}'

# Kernel module / firmware presence
lsmod | grep -iE "ipu6|ivsc|ljca|ov01a10|hi556|ov2740"
ls /usr/lib/firmware/intel/ipu/                 # ipu6*_fw.bin*
find /usr/lib/modules/$(uname -r)/kernel/drivers/media/pci/intel -type f

# libcamera-side discovery
cam -l
cam -c 1 -C5                                     # capture 5 frames sanity
qcam                                             # live preview window

# v4l2 controls (sensor subdev)
v4l2-ctl --list-devices
v4l2-ctl -d /dev/v4l-subdev5 --list-ctrls
v4l2-ctl -d /dev/v4l-subdev5 --get-ctrl=analogue_gain,exposure
v4l2-ctl -d /dev/v4l-subdev5 --set-ctrl=analogue_gain=2048 --set-ctrl=exposure=1500

# PipeWire-side check
wpctl status | grep -iE "camera|video"
gst-device-monitor-1.0 Video/Source

# GStreamer test capture (encoded JPEG, unlike cam --file which is raw)
gst-launch-1.0 libcamerasrc num-buffers=1 \
  ! video/x-raw,width=1280,height=800 ! videoconvert ! jpegenc \
  ! filesink location=/tmp/cam.jpg

# DKMS state
sudo dkms status
cat /var/lib/dkms/ipu6-drivers/*/build/make.log | tail -40

# udev reload after editing rules
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=video4linux

# PipeWire reload after libcamera config change
systemctl --user restart wireplumber pipewire pipewire-pulse
```

## Browser flags

- **Firefox**: `about:config` → `media.webrtc.camera.allow-pipewire = true`.
- **Chromium/Chrome/Brave**: `chrome://flags` → `WebRtcPipeWireCamera` → Enabled.
- **Electron apps (Signal, Slack, Discord, etc.)**: launch with
  `--enable-features=WebRtcPipeWireCamera`.

## Patching the DKMS module for kernel 7.0 (this branch's work)

Update 2026-05-23: rather than waiting for upstream `intel/ipu6-drivers`
to ship a 7.0 patchset (still open, see PRs #424 and #425 — neither
addresses 7.0 specifically), the DKMS module was patched locally in this
repo. The patch lives at
[intel-ipu6-dkms-git/0001-kernel-7-build-fixes.patch](intel-ipu6-dkms-git/0001-kernel-7-build-fixes.patch).
PKGBUILD bumped from pinned commit `cfb7af1e` → `ca28a0278` (tip of
`iotg_ipu6` as of 2026-05-22, includes PR #430 "IPU6 release for iot
kernel v6.18").

### Build errors encountered, in order, and the fix for each

| # | Error                                                                              | Root cause                                                                                                                  | Fix                                                                                                 |
|---|------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| 1 | `MODULE_IMPORT_NS(INTEL_IPU_BRIDGE)` / `EXPORT_SYMBOL_NS_GPL(..., INTEL_IPU6)` fail to compile (28 sites) | Kernel 6.13 [`cdd30ebb1b9f`](https://www.mail-archive.com/linux-kernel@vger.kernel.org/msg2579808.html) — namespace must now be a string literal | New `include/ipu-namespace-compat.h` shim that `__stringify()`s the namespace on ≥6.13; force-included via `subdir-ccflags-y` |
| 2 | `asc->match.src_pad` — `struct v4l2_async_match_desc` has no `src_pad`            | `src_pad` is an out-of-tree-only field added by `patch/v6.18.3/0008-media-lt6911-2-pads-linked-to-ipu-2-ports-for-split-mode.patch` | Pass `-1` (matches `patch/v6.18.3/0023-...align-params-for-non-MIPI-split...`); function discovers source pad itself |
| 3 | `v4l2_get_link_freq(ext_sd->ctrl_handler, …)` — incompatible pointer              | Kernel 6.15 dropped the ctrl_handler overload (`_Generic`), 7.0 removed it entirely; only `struct media_pad *` accepted     | Use `src_pad` (already in scope) on ≥6.15                                                           |
| 4 | `struct v4l2_subdev_stream_config` undefined                                      | Kernel 6.18 made the struct opaque; access via `state->routing.routes[]` now                                                | Walk `state->routing.routes[i]` and match `route->sink_pad == r_pad->index`                         |
| 5 | `struct vb2_ops` has no `wait_prepare`/`wait_finish`                              | Kernel 7.0 removed these callbacks; core handles queue locking via `q->lock`                                                | `#if LINUX_VERSION_CODE < KERNEL_VERSION(7, 0, 0)` around the two assignments                       |
| 6 | `field 'clkdev_data' is of incomplete type`                                       | `<linux/clkdev.h>` was included only under `#if IS_ENABLED(CONFIG_INTEL_IPU_ACPI)`, but the struct using `clk_lookup` isn't guarded | Include `<linux/clkdev.h>` unconditionally                                                          |
| 7 | `ipu6_isys_init`: trailing comma syntax error when `CONFIG_INTEL_IPU_ACPI` off    | Function signature/call site put a comma OUTSIDE the conditional `spdata` arg                                               | Move the comma INSIDE the `#if IS_ENABLED(CONFIG_INTEL_IPU_ACPI)` block on both signature and call  |
| 8 | `ipu_get_acpi_devices` undefined at modpost                                       | We disabled the `ipu-acpi` modules but the call site in `ipu6.c` is gated by `CONFIG_INTEL_IPU_ACPI` (and the macro was still defined) | Stop exporting `CONFIG_INTEL_IPU_ACPI` / `CONFIG_INTEL_IPU6_ACPI` in the Makefile                   |
| 9 | `isx031.c:1059: invalid array subscript` on `platform_data->suffix[0]`            | Pre-existing code bug: struct has `char suffix;` but driver formats it with `%s` and subscripts with `[0]`                  | Disable the industrial/automotive sensor drivers (ISX031, MAX9X, AR0234, LT6911UX{C,E}) for DKMS — they don't apply to consumer laptops, the `.c.non_upstream` files require manual rename anyway |

### What gets built now

Three core modules only — exactly what `libcamera-ipu6` / `libcamhal` needs:
- `intel-ipu6.ko` (replaces the kernel's in-tree one)
- `intel-ipu6-isys.ko` (replaces the kernel's in-tree one)
- `intel-ipu6-psys.ko` ⭐ — **the module with no upstream equivalent**, required by libcamhal to open `/dev/ipu-psys0`.

### Confirmed working on 2026-05-23

```
$ sudo dkms status
ipu6-drivers/r193.ca28a0278, 7.0.9-arch1-1, x86_64: installed (Original modules exist)

$ ls /lib/modules/7.0.9-arch1-1/updates/dkms/ | grep ipu6
intel-ipu6-isys.ko.zst
intel-ipu6.ko.zst
intel-ipu6-psys.ko.zst
```

The `(Original modules exist)` note means DKMS detected the kernel's own
in-tree `intel-ipu6{,-isys}` and our `/updates/dkms/` versions take
precedence at modprobe time (standard DKMS behavior).

### What this unblocks

The `libcamera-ipu6` AUR package (cloned at `~/src/libcamera-ipu6`) was
previously blocked on kernel 7.0 because it requires `/dev/ipu-psys0`
(provided only by this DKMS module). With the patched DKMS now building,
the proper migration path on `linux 7.0.9` is:

```fish
# remove the upstream Simple-pipeline libcamera packages (they conflict
# with libcamera-ipu6, which provides=libcamera)
yay -R gst-plugin-libcamera libcamera-ipa libcamera

# install Intel's userspace stack + the libcamera fork that wraps it
yay -S intel-ipu6-camera-hal-git intel-ipu6-camera-bin
cd ~/src/libcamera-ipu6 && makepkg -si

# undo the dark-image workarounds — libcamhal does proper AGC via PSYS
sudo rm -f /etc/udev/rules.d/99-ov01a10-defaults.rules
sudo cp /usr/share/libcamera/ipa/simple/uncalibrated.yaml.bak \
        /usr/share/libcamera/ipa/simple/uncalibrated.yaml 2>/dev/null

# reboot, then verify pipeline handler is now "ipu6" (not "simple")
cam -l
```

This should restore the hardware-ISP image quality (the thing the
upstream Simple pipeline can't match) while keeping you on the new
kernel. The four "fixes you won't find documented elsewhere" from
[libcamera-ipu6's README](file:///home/user/src/libcamera-ipu6/README.md)
handle the GDM/wireplumber/seccomp/libcamhal race conditions.

### gcc 16 also breaks `intel-ipu6-camera-hal-git`

On the same migration day, building Intel's userspace HAL (libcamhal)
failed against gcc 16 because two legacy warnings were promoted to
errors:

```
src/iutils/CameraDump.cpp:551
  int bytes_read = 0;      // set but never read
modules/ia_css/ipu6/include/ia_css_psys_terminal_impl.h:1862
  unsigned mem_offset;     // set but never read
```

Both are pre-existing dead-variable warnings that older gcc tolerated.
Fixed in this repo's [intel-ipu6ep-camera-hal-git/PKGBUILD](intel-ipu6ep-camera-hal-git/PKGBUILD)
by exporting `-Wno-error=unused-but-set-variable` (+ a few related
flags) in `build()`. The PKGBUILD now also `provides=intel-ipu6-camera-hal-git`
so it is a drop-in for `libcamera-ipu6`'s dependency.

Same naming-provides change applied to
[intel-ipu6ep-camera-bin/PKGBUILD](intel-ipu6ep-camera-bin/PKGBUILD) —
this Alder-Lake-only variant now also `provides=intel-ipu6-camera-bin`,
so the same code path covers users on this repo's `-fix` variants and
users coming from `libcamera-ipu6 → intel-ipu6-camera-{hal,bin}` AUR
deps.

### Caveats

- DKMS build still **fails on `linux-lts 6.6.31`** (the patches assume
  newer-kernel APIs in places). If you want LTS to work too, reinstall
  the previous `intel-ipu6-dkms-git-fix r165.cfb7af1e5` while on LTS, or
  bound the patches with version guards.
- The Makefile no longer builds the industrial/automotive sensors. If
  you have ISX031/MAX9X/LT6911 hardware, revert the commented-out
  `obj-y` lines in `intel-ipu6-dkms-git/0001-kernel-7-build-fixes.patch`
  and fix `isx031.c`'s `suffix[0]`/`%s` mismatch yourself.

## Gotchas hit during the `libcamera-ipu6` migration

Two non-obvious things blocked the IPU6 pipeline from claiming the
camera even after every package was installed correctly. The
`libcamera-ipu6` README mentions related symptoms in passing; calling
them out explicitly here because they cost ~an hour and there are no
single-search-hit answers for either.

### 1. `LIBCAMERA_PIPELINES_MATCH_LIST` must reach the user's environment

The `libcamera-ipu6` package ships
`/usr/lib/environment.d/60-libcamera-ipu6.conf` containing:

```sh
LIBCAMERA_PIPELINES_MATCH_LIST=ipu6,simple,uvcvideo
```

This forces the `ipu6` pipeline handler to win the probe race against
`simple`. But `environment.d` is only read by PAM at session start
(via `pam_systemd`). If you installed `libcamera-ipu6` and then ran
`qcam` from a pre-existing terminal, the env var isn't set in that
shell and `simple` claims the camera first.

Symptom: `cam -l` / `qcam` logs show
```
INFO Camera camera_manager.cpp:223 Adding camera '\_SB_.PC00.LNK1' for pipeline handler simple
INFO IPASoft soft_simple.cpp:258 IPASoft: Exposure 4-1784, gain 1-63.9961
INFO SoftwareIsp software_isp.cpp:278 Input 1292x812-BGGR-10 stride 2624
```

Confirmation: prefix the command with the env var manually —
`LIBCAMERA_PIPELINES_MATCH_LIST=ipu6 qcam` — and the pipeline handler
flips to `ipu6`.

Fix: log out and back in (or reboot) so PAM applies the env file. After
that, `echo $LIBCAMERA_PIPELINES_MATCH_LIST` should print
`ipu6,simple,uvcvideo`.

### 2. `TAG+="uaccess"` is not always enough — add yourself to `video`

The `/usr/lib/udev/rules.d/99-ipu6-psys.rules` rule tags `/dev/ipu-psys0`
with `uaccess`, which *should* grant the active-session user a
per-session ACL (same scheme `/dev/video*` uses). In practice the ACL
sometimes never reaches an interactive shell — observed result was:

```
$ getfacl /dev/ipu-psys0
# owner: root
# group: video
user::rw-
group::rw-
other::---
```

No `user:<you>:rw-` line, despite `udevadm info` correctly reporting
`TAGS=:uaccess: CURRENT_TAGS=:uaccess:`. Likely cause: logind didn't
re-trigger ACL application on the running session (could be that the
session was non-`Class=user`, or that the rule fired before login).

Symptom from libcamhal once `ipu6` pipeline is forced active:

```
CamHAL[ERR] Failed to open PSYS, error: Permission non accordée
CamHAL[ERR] Failed to initialize Context
CamHAL[ERR] create PG 187 error
CamHAL[ERR] Failed to create PGs for executor: ipu6_lb_video_bayer
```

Fix: add yourself to the `video` group (which already owns the chardev):

```fish
sudo usermod -a -G video $USER
# log out and back in, or:
sudo reboot
```

After re-login, `id` should list `video` and `cat /dev/ipu-psys0` should
fail with `operation not supported` (the device works, but isn't a
regular file) instead of `Permission denied`.

### 3. Harmless noise to ignore

These error lines fire on every libcamhal init and do **not** prevent
IPU6 enumeration or capture:

```
CamHAL[ERR] Malformed ET range in exposure time range configuration
CamHAL[ERR] Parse AE eExposure time range failed
CamHAL[ERR] Parse AE gain range failed
```

They come from a strict-parser branch in
`src/platformdata/CameraParser.cpp:1386` that rejects what the shipped
sensor XML clearly accepts elsewhere. Probably a stale check vs. an
out-of-date sample format. libcamhal still parses the actual AIQB tuning
file and opens the camera successfully — these are warnings dressed as
errors.

### 4. Recurring wireplumber crash in `IPU6CameraData::workerThread()` — **fixed on this branch**

> **Update 2026-08-26 (`libcamera-ipu6-fix` pkgrel=3)**: pkgrel=2 fixed
> the CPU-cost + log-noise problems of pkgrel=1 (guard moved before
> memcpy, log downgraded to Debug), but user reported a new symptom:
> PipeWire graph "goes stale" after some uptime — Firefox reports
> "webcam not working", full-stack restart (`systemctl --user
> restart pipewire pipewire-pulse wireplumber xdg-desktop-portal` +
> Firefox restart) fixes it, and the pattern recurs. Sometimes wireplumber
> also SIGSEGVs in `Request::Private::prepare()` called from
> `PipelineHandler::queueRequest()` (unrelated stack trace to the
> workerThread SIGABRT we originally fixed).
>
> Root cause identified via a deep-dive into libcamera's request-queue
> ownership: **the guard's skip path leaks Requests into
> `Camera::Private::queuedRequests_` forever**. `PipelineHandler::completeRequest`
> (`pipeline_handler.cpp:592-600`) is the only site that pops from that
> queue, and it stops at the first `RequestPending` at the head. If the
> guard silently skips a Request, that Request stays there with
> `status=RequestPending`, blocking every later completion. That's the
> PipeWire target-not-found / graph-stale symptom. The `prepare()`
> SIGSEGV may be a downstream effect (memory/state corruption from the
> accumulating leak) or an independent bug — pkgrel=3 addresses only
> the leak; we'll see if the SEGV survives it.
>
> pkgrel=3 fix: when the guard fires with `status == RequestPending`,
> ALSO call `pipe()->completeRequest(request)` to drain from
> `queuedRequests_`. Safe because `Request::Private::complete()`'s
> two asserts (status=Pending and !hasPendingBuffers) are exactly what
> the guard just verified. When `status != RequestPending`, keep pure
> skip — a second `complete()` would trip its own assert.
>
> **Update 2026-08-25 (`libcamera-ipu6-fix` pkgrel=2)**: no crashes in
> the ~2 months since pkgrel=1 shipped ✓. But the guard fires in
> bursts of 20+ per second during camera start/stop transitions.
> Every fire = one dropped frame. Result: no SIGABRT, but Firefox /
> video-call apps see the camera as "not working" during the drop
> bursts (they time out waiting for a first frame).
>
> pkgrel=2 widens the guard:
>   - Guard moved BEFORE the ~50 ms memcpy (previously wasted ~1 s of
>     CPU per burst on data destined for the trash).
>   - Also check `request->status() == RequestPending` — a request in
>     RequestComplete/RequestCancelled state should never be processed.
>   - Log level Warning → Debug — the bursts flood the journal and
>     they're the expected behaviour of a working guard, not a warning
>     event.
>
> The patch is applied via a Python string-replace in
> [libcamera-ipu6-fix/PKGBUILD](libcamera-ipu6-fix/PKGBUILD)'s
> `prepare()` (large multi-line block replacement; more robust than
> a unified diff whose context drifts between patch iterations).
> The `.patch` file at
> [libcamera-ipu6-fix/0003-...](libcamera-ipu6-fix/0003-ipu6-workerThread-drop-stale-buffers-instead-of-asserting.patch)
> is now a human-readable rationale only, not applied by `patch -Np1`.
>
> **Update 2026-07-01 (`libcamera-ipu6-fix` pkgrel=1)**: after a fourth
> crash (2026-07-01 16:16, same exact stack offsets as the earlier
> three), promoted the workaround to a local fix. See the pkgrel=1
> section below for the original patch (Warning-level, post-memcpy).
>
> **Update 2026-05-28**: this is no longer a "single occurrence" — three
> crashes now logged in `~/sound-video-crash/`, all with identical
> stack offsets (`completeBuffer+0x1fc`, `workerThread+0x176`). Two of
> them clustered 14 minutes apart in the same wireplumber session.
> Auto-recovery still works each time, but the bug is real and frequent.

Observed 2026-05-26 and 2026-05-28: SIGABRT in `wireplumber` from the
kervel fork's IPU6 worker thread:

```
FATAL request.cpp:111 assertion "ret == 1" failed in completeBuffer()
  libcamera::Request::Private::completeBuffer(libcamera::FrameBuffer*)
  libcamera::IPU6CameraData::workerThread()
```

`ret == 1` from `Request::Private::completeBuffer()` means the worker
thread tried to mark a frame buffer as complete for a request, but the
request's accounting said the buffer wasn't owned by it (already
completed, or completed out of order). Classic race in an async-frame
pipeline-handler bridge.

**The good news**: systemd-user respawns wireplumber within ~1-2s, the
`wait-libcamhal-shm` ExecStartPre clears the SHM boot race, libcamhal
re-initializes from scratch, and the camera (+ audio + bluetooth media
endpoints) come back cleanly. Auto-recovery works without intervention.

**Not in the libcamera-ipu6 README's known-fix list** (#1 init refcount,
#2 udev `uaccess`, #3 seccomp `@ipc`, #4 SHM boot race). Looks like a
fifth race the maintainer hasn't hit yet.

**No upstream fix available** as of 2026-05-26: the AUR PKGBUILD pins
`kervel/libcamera@ipu6-pipeline-handler` commit `48748f15`, which is
also the current HEAD of that branch. The branch is "12 commits ahead
of and 88 commits behind libcamera-org/libcamera:master" — no churn on
the IPU6 handler since the AUR pin was set.

**Fix pkgrel=1 landed 2026-07-01** in `libcamera-ipu6-fix/`. Original
guard: catches the crash at the `completeBuffer()` call site, drops
stale buffers with a Warning-level log instead of aborting. Prevented
the SIGABRT successfully (zero crashes over the ~2 months it was
deployed). But logged at Warning and ran AFTER the memcpy, so a fired
guard still burned ~50 ms per stale buffer + flooded the journal:

```cpp
// libcamera-ipu6-fix/0003-...patch pkgrel=1, in ipu6.cpp near the
// existing completeBuffer() call at ipu6.cpp:457
if (!request->_d()->hasPendingBuffers()) {
    LOG(IPU6, Warning)
        << "Dropping stale buffer for cancelled/completed request";
} else {
    pipe()->completeBuffer(request, buffer);
    pipe()->completeRequest(request);
}
```

**Fix pkgrel=2 landed 2026-08-25**. Widens the guard after seeing it
fire in bursts of 20+ per second during camera start/stop transitions.
Moved BEFORE the memcpy, added `status() == RequestPending` check,
downgraded log to Debug. Fixed the CPU/log-noise problems, but silently
kept the queuedRequests_ leak from pkgrel=1 (see pkgrel=3 note above).

**Fix pkgrel=3 landed 2026-08-26**. Adds `pipe()->completeRequest(request)`
in the skip path when `status == RequestPending`, so the stale request
is drained from `queuedRequests_` instead of leaking:

```cpp
// libcamera-ipu6-fix/0003-...patch pkgrel=3 — applied via Python
// string-replace in PKGBUILD prepare(). Skip-path now drains.
bool __ipu6_stale = !buffer ||
    request->status() != Request::RequestPending ||
    !request->_d()->hasPendingBuffers();
if (__ipu6_stale) {
    LOG(IPU6, Debug)
        << "Skipping stale request in worker "
           "(cancelled or completed elsewhere)";
    if (request->status() == Request::RequestPending &&
        !request->_d()->hasPendingBuffers()) {
        pipe()->completeRequest(request);  // <-- pkgrel=3 addition
    }
} else if (buffer) {
    /* ...MappedFrameBuffer + memcpy + metadata + completeBuffer + completeRequest... */
}
```

The `-fix` variants of the split packages provide= and conflicts= the
upstream AUR `libcamera-ipu6-*` names, so `pacman -U ./*.pkg.tar.zst`
against the built directory replaces the AUR family atomically.
`install.sh -m` uses this by default now (previously it cloned the
AUR package).

**Workaround if you can't run the fix yet**: live with the auto-recovery.
**Do NOT**:
- mask wireplumber (kills all PipeWire audio + video)
- `pacman -Syu` libcamera (would pull upstream `libcamera` from `extra`,
  which `conflicts/replaces` `libcamera-ipu6` and reverts you to the
  Simple-pipeline / SoftISP dark-image path)
- disable the camera "to test stability"

**What the non-crashing threads show**: across all three coredumps the
other libcamhal threads are uniformly **idle, waiting for work** —
`RequestThread::threadLoop` blocked on a condition variable,
`PSysProcessor::processNewFrame` and `PipeLiteExecutor::processNewFrame`
both blocked in `BufferQueue::waitFreeBuffersInQueue`, `CaptureUnit::poll`
and `SofSource::poll` blocked in `cros::V4L2DevicePoller::Poll`. So the
race is exclusively in the libcamera-side worker that hands libcamhal
frames back into libcamera's `Request`/`FrameBuffer` accounting — not
in libcamhal itself.

**Long-term**: capture with `coredumpctl gdb wireplumber` and report.
The fix would be in `IPU6CameraData::workerThread()` (or the libcamhal
shim that calls into it) — likely a missing check that the buffer's
parent request is still active before invoking `completeBuffer()`.
Useful one-shot capture script for the next occurrence:

```fish
coredumpctl info --no-pager 2>&1 | tail -50
sudo coredumpctl gdb wireplumber <<'EOF' 2>&1 | tail -100
thread apply all bt full
frame 5
info locals
quit
EOF
journalctl --user --since "5 minutes ago" -o cat 2>&1 | tail -80 \
  > /tmp/crash-context.log
```

The crash repro would also benefit from knowing the trigger — which app
was using the camera, and whether the crash correlates with a
state-transition event (call join/leave, camera toggle, lid close,
suspend/resume, app close). Report the combination at:

- AUR comments: <https://aur.archlinux.org/packages/libcamera-ipu6>
- kervel/libcamera: <https://github.com/kervel/libcamera> (currently
  no issue tracker enabled on the fork — comments on the maintainer's
  AUR page is the most likely path)

No upstream fix is available as of 2026-05-28 — the kervel branch HEAD
is still `48748f15` (same as the AUR pin), 12 ahead and 88 behind
`libcamera-org/libcamera:master`, and the maintainer hasn't bumped
since 2026-04-30.

### End-to-end verification, 2026-05-24

After adding to `video` group + reboot, `qcam 2>&1 | head -20` shows:

```
INFO Camera camera_manager.cpp:340 libcamera v0.7.0+ov01a10.2
INFO IPU6 ipu6.cpp:714 Found 5 IPU6 camera(s) via libcamhal
INFO IPU6 ipu6.cpp:175 Found IPU6 camera 0: ov01a10-uf (facing=1)
INFO Camera camera_manager.cpp:223 Adding camera 'ipu6-ov01a10-uf-0' for pipeline handler ipu6
INFO Camera camera.cpp:1216 configuring streams: (0) 1280x720-NV12/sYCC
INFO IPU6 ipu6.cpp:232 Opening camera device 0
```

Image quality observably good — calibrated colors, no flicker, no
manual exposure pin needed. Stack B confirmed working on `linux 7.0.9-arch1-1`.

## Recommended next steps

1. **Short term**: install `libcamera-ipu6` from AUR now that the PSYS
   module is available on 7.0. See the migration block above.
2. **Medium term**: open a PR upstream to `intel/ipu6-drivers` based on
   the local patch, so other distros benefit (the bulk of it is generic
   kernel-API churn, not laptop-specific).
3. **Long term (passive)**: track libcamera 0.8 (proportional AGC, per-
   sensor tuning files for OV01A10). When those land, the upstream
   Simple-pipeline path may be good enough to drop libcamhal entirely.

## Sources

- [Linux 7.0 release — Phoronix](https://www.phoronix.com/news/Linux-7.0-Released)
- [Linux 7.0 — The Register](https://www.theregister.com/2026/04/13/linux_kernel_7_releaseed/)
- [Intel IPU6 driver — kernel.org](https://docs.kernel.org/driver-api/media/drivers/ipu6.html)
- [Intel IPU6 Webcam on Linux: From Proprietary Stack to Mainline — Javier Tia](https://jetm.github.io/blog/posts/ipu6-webcam-libcamera-on-linux/)
- [How to use the IPU6 webcam with kernel 6.10+? — Arch Linux Forums](https://bbs.archlinux.org/viewtopic.php?id=297262)
- [libcamera-ipu6 AUR package](https://aur.archlinux.org/packages/libcamera-ipu6)
- [kervel/libcamera — IPU6 pipeline handler fork](https://github.com/kervel/libcamera)
- [intel/ipu6-drivers issues](https://github.com/intel/ipu6-drivers/issues)
- [intel/ipu6-camera-hal#161 — OV01A10 missing tuning](https://github.com/intel/ipu6-camera-hal/issues/161)
- [libcamera Sensor Tuning Guide](https://libcamera.stefanklug.com/docs/tuning-guide/tuning.html)
- [libcamera-devel: PATCH v4 proportional AGC](https://lists.libcamera.org/pipermail/libcamera-devel/2026-April/058416.html)
- [stefanpartheym/archlinux-ipu6-webcam README](./README.md)
