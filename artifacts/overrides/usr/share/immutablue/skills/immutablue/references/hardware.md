# Hardware, Virtualisation, and Peripherals

Machine-level features that are neither package installs nor desktop config.

## Libvirt / virt-manager

libvirt ships but is off by default.

```bash
immutablue status_libvirt
immutablue enable_libvirt_dry_run     # see the plan
immutablue enable_libvirt             # services + adds you to the libvirt group
```

Group membership takes effect at the **next login**, so "permission denied" right
after enabling is expected. Two failure modes have their own fix:

- VMs fail with `network 'default' is not active`, or virtlogd logs
  `Permission denied` → `immutablue fix_libvirt_selinux_mislabel`. libvirt's
  state under `/var` has the wrong SELinux labels; this relabels it.
- No password dialog for system-libvirt actions under gowl → the polkit agent.
  See [`desktop.md`](desktop.md); GNOME has its own.

`immutablue-libvirt-manager [-s] [--dry-run] enable|disable|status` is what the
recipes call.

## Hardware video acceleration

GUI variants ship the RPM Fusion *freeworld* Mesa VA-API/VDPAU drivers, so AMD and
Intel GPUs get H.264, HEVC and VC-1 in hardware, on top of AV1/VP9/JPEG. The
browser still has to be told to use it.

```bash
vainfo                    # driver loads (radeonsi / iHD / i965) and the profile list
```

No `H264`/`HEVC` profiles in that list means the freeworld swap is not in this
image — rebase to a current one. No driver at all is a kernel/DRM problem
(`/dev/dri/renderD128` missing), not a browser problem.

In Firefox/LibreWolf `about:config`: `media.hardware-video-decoding.enabled` and
`.force-enabled` → `true`, `widget.dmabuf.force-enabled` → `true`,
`gfx.x11-egl.force-enabled` → `true` on X11 only. The old
`media.ffmpeg.vaapi.enabled` pref no longer exists. Verify in `about:support`:
**HARDWARE_VIDEO_DECODING** should read `available` or `force_enabled`, and
`radeontop` / `intel_gpu_top` / `nvtop` should show the decode engine busy while
the CPU stays idle.

**The AV1 trap:** YouTube serves AV1 by default and only Intel Arc / 11th gen+,
RTX 30+, and RDNA2+ decode it in hardware. On older GPUs it falls back to CPU
*even with freeworld*. The fix is a codec-blocking extension (`enhanced-h264ify`)
so YouTube serves H.264.

## Power and suspend

`immutablue disable_suspend` / `enable_suspend`, with `_ac` and `_battery` halves,
change GNOME's idle-suspend for the current user. They do **not** stop GDM
suspending at the login screen or `systemctl suspend`. An always-on machine
wants the sleep targets masked instead:

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

Masking is also what the crash-capture watchdog interlock requires — see
[`crash-capture.md`](crash-capture.md).

## Hardware overrides

`immutablue hardware_override_asmedia_prefer_usb_storage_over_uas` forces the
`usb-storage` driver over UAS for ASMedia USB-SATA bridges. Reach for it when
`dmesg` shows repeated `uas_eh_device_reset_handler` / `uas_eh_abort_handler` on
an external drive. `..._unprefer_...` undoes it.

## NVIDIA (cyan)

**Fedora 44+ cyan carries two driver stacks in one image** and picks one per
machine at boot. Fedora 42/43 cyan still bakes a single akmod-built driver into
the image (modules in `modules-load.d`) and has none of the below.

| Stack | Driver | Hardware |
|-------|--------|----------|
| `open` | current branch, open kernel modules | Turing and newer; the only choice for Blackwell |
| `580` | proprietary 580xx legacy branch | Maxwell, Pascal, Volta; also Turing–Ada, so a Pascal + Ampere box gets `580` |
| `none` | neither is activated | no NVIDIA GPU, or deliberately off |

How it picks: `immutablue-nvidia.service` (early boot, before the display
manager) runs `immutablue-nvidia-setup --activate`. With no saved choice it reads
every NVIDIA display device from `/sys/bus/pci/devices` and selects `open` if
`open` supports **all** of them, else `580` if that does, else **fails without
saving** — a mix with one pre-Maxwell (legacy-branch) card is unsupported. No
NVIDIA GPU saves `none`. The choice is written once to
`/etc/immutablue/nvidia.json` and reused on every later boot and update; it is
**not** re-detected automatically.

Activation links `/usr/lib/immutablue/nvidia/<driver>/immutablue-nvidia.raw` to
`/run/extensions/` and merges it with `systemd-sysext` — kernel modules, GL/Vulkan,
CUDA driver libraries and the NVIDIA systemd units (580 suspend/resume hooks
included) all live in that read-only image, not in the RPM database. Nouveau and
Nova are blacklisted and kept out of the initramfs; `none` does **not** bring
Nouveau back.

```bash
immutablue nvidia_status                 # the saved choice (no root); not proof it loaded
immutablue nvidia_setup                  # re-detect and save — after swapping a GPU
immutablue nvidia_setup --driver 580     # force a stack; not checked against the hardware
immutablue nvidia_setup --driver none    # turn both off
systemctl reboot                         # a choice applies at the next boot, never live
```

When the display is gone or `nvidia-smi` fails:

```bash
journalctl -b -u immutablue-nvidia.service    # "no bundled driver supports all NVIDIA GPUs", "missing … stack", "invalid saved driver"
systemd-sysext status                         # is immutablue-nvidia merged into /usr?
cat /etc/immutablue/nvidia.json
cat /usr/lib/immutablue/nvidia/*/manifest.json   # driver version and the kernel each stack was built for
lsmod | grep -E 'nvidia|nouveau'
nvidia-smi
```

- A malformed `nvidia.json` fails activation; `immutablue nvidia_setup` rewrites it atomically.
- A boot with `/.autorelabel` present skips activation; the next normal boot activates.
- `enable_nvidia_kmod` on 44+ re-runs detection (replacing a forced `--driver`) and
  appends the nouveau-blacklist and `nvidia-drm.modeset=1` kargs; `disable_nvidia_kmod`
  saves `none` and removes those kargs. Run `disable_nvidia_kmod` **before** rebasing
  off `-cyan` — the image-level blacklists leave with the image, the kargs do not.
- `rpm -q` shows no NVIDIA packages on 44+; the version is in `manifest.json`.
- CUDA *toolkits* are not included, only the driver libraries.
- Secure Boot module signing is not established; do not promise it works.

## Asahi

`asahi_enable_notch_render` / `asahi_disable_notch_render` render into, or avoid,
the display notch.

## Print to cmacs

GUI variants ship (from the cmacs image, not `artifacts/overrides/`) a virtual
CUPS printer named `cmacs`: print from any application and the job becomes a
directory under
`~/Documents/notes/03_resources/cmacs-print/` with `index.org`, `source.pdf`,
and one PNG per page. Nothing to install.

```bash
lpstat -p cmacs                                   # printer cmacs is idle
systemctl --user status cmacs-print-drain.path    # Active: active (waiting)
lp -d cmacs file.pdf                              # scripted print
```

Three pieces: the CUPS backend `/usr/lib/cups/backend/cmacs-print` writes the PDF
to `/tmp/cmacs-print-<uid>/`; a user `path`+`service` pair drains it with
`cmacs --batch`; `cmacs-print-register.service` runs `lpadmin` at boot. The
`/tmp` spool is deliberate — it is the one place stock SELinux lets `cupsd_t`
write that a user service can read; the obvious D-Bus and `/run/user` designs
fail with no AVC logged.

If either unit is missing on a fresh install, the preset did not fire:

```bash
sudo systemctl enable --now cmacs-print-register.service
systemctl --user enable --now cmacs-print-drain.path
```

Tunables are Emacs `customize-group cmacs-print` (target dir, DPI, formats);
restart `cmacs-print-drain.path` after changing them. To turn it off:

```bash
sudo systemctl disable --now cmacs-print-register.service
sudo lpadmin -x cmacs
systemctl --user disable --now cmacs-print-drain.path
```

The image keeps shipping the files; this only stops them running.

## Speech input

Two separate systems ship. `voxtype` (push-to-talk, Super+D) is the supported one
and is covered in [`desktop.md`](desktop.md). `ibus-speech-to-text` is also in the
package set for GNOME users who want an input-method-style dictation source
(Settings → Keyboard → Input Sources → "Speech To Text"). Do not suggest
`rpm-ostree install` for it; it is already there.
