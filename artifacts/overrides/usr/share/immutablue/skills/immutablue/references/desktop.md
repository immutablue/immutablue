# The Desktop: Sessions and Where to Look

Read this before changing the compositor, the status bar, keybindings, or the
editor-as-window-manager session.

Immutablue ships more than one session and they are genuinely different systems:

- **GNOME on Wayland** — the conventional session. Configure it through dconf; see
  [`configuration.md`](configuration.md).
- **gowl** — a wlroots compositor written against GLib, embedded inside **cmacs**
  (a GNU Emacs fork). In this session Emacs is the window manager.

Check which one is running before advising:

```bash
echo "${XDG_CURRENT_DESKTOP}"
```

On **freebsd-be** the login screen is chosen per machine
(`immutablue display_manager` shows it; `immutablue display_manager
gdm|lightdm` switches; setting `.immutablue.freebsd.display_manager`):
**gdm** (default) keeps GNOME Shell's lock screen but, being X11-only on
FreeBSD, never offers gowl or CMacs — start those from a text console;
**lightdm** offers GNOME (X11), gowl and CMacs, but GNOME sessions then
cannot lock (GNOME Shell needs gdm; i3lock cannot take GNOME Shell's grab).
Super+L runs `/usr/libexec/immutablue/freebsd-lock`, which locks under gdm and
otherwise notifies and exits 1. Don't put `gdm_enable`/`lightdm_enable` in
`rc.conf` by hand: `rc.d/immutablue_dm` writes `/etc/rc.conf.d/{gdm,lightdm}`
from the setting at each boot, and updates reset `rc.conf`'s copies to `NO`.
The installer creates the first user (and asks which login screen). GNOME
Settings has no Wi-Fi panel on FreeBSD (it needs NetworkManager): use
`networkmgr` (a tray icon; GNOME shows it through the Status Icons extension,
on by default on FreeBSD) or `wifimgr` (a window), or `wpa_cli -i wlan0`;
`rc.d/immutablue_wlan` creates the `wlan0` interface for each card at boot, and
`/usr/local/etc/devd/immutablue-wlan.conf` for cards that attach later
(iwlwifi, rtw88/rtw89). There is no `gnome-extensions` command on FreeBSD; use
`gsettings set org.gnome.shell enabled-extensions …`. gowl and CMacs need the
GPU's DRM driver: `rc.d/immutablue_drm` loads `i915kms` (Intel) or `amdgpu`
(AMD) at boot (`kldstat | grep -E 'i915|amdgpu'`); in a VM, or on NVIDIA, they
stop at "Found 0 GPUs" while GNOME (X11) still runs. Images before immutablue `b5341b3` could not unlock the GNOME lock screen
even with the right password (ConsoleKit2 had no usable VT and rejected gdm's
session path); the fix is a patched, `pkg lock`ed `consolekit2` plus a devfs
`ttyv0 -> tty0` link, so the answer there is to update the image, not to
`pkg unlock` or rebuild the package by hand.

## Where each part is documented

| Part | Guide |
|---|---|
| gowl compositor: YAML and C config, keybinds, rules, compositor modules | [`gowl.md`](gowl.md) |
| the bar: layout, widgets, writing and reloading plugins | [`gowl-bar.md`](gowl-bar.md) |
| cmacs: `init.el` / `init.c` / `init.bacon`, subsystems, the on-machine manuals | [`cmacs.md`](cmacs.md) |
| gst, the terminal | [`gst.md`](gst.md) |
| gsurf, the browser — standalone and embedded | [`gsurf.md`](gsurf.md) |
| GNOME defaults (dconf) | [`configuration.md`](configuration.md) |

## Polkit under gowl

GNOME Shell registers its own polkit authentication agent; a bare wlroots session
does not, so without one every GUI action needing authorisation — `pkexec`,
system Flatpak installs, virt-manager reaching the system libvirt socket — fails
with no dialog and no obvious cause. Immutablue ships `mate-polkit` and starts it
from `immutablue-polkit-agent.service`, a user unit bound to `gowl-session.target`
rather than `graphical-session.target`, so it runs only in gowl sessions and never
competes with GNOME's agent.

```bash
systemctl --user status immutablue-polkit-agent.service
```

A "permission denied" with no password prompt under gowl is this unit not
running, before it is anything to do with libvirt or Flatpak.

## Dictation

voxtype ships in GUI variants. Setup, the Super+D keybinding, and the reason the
typing backend differs between GNOME and gowl are covered by:

```bash
immutablue enable_dictation
immutablue dictation_status
```

If `immutablue` says the recipe does not exist, the image's `Justfile` is missing
its `import "./09-dictation.justfile"` line (images built from immutablue `f549e2d` or earlier). Run it as
`just -f /usr/libexec/immutablue/just/09-dictation.justfile enable_dictation`.

The short version: `wtype` speaks `wlr-virtual-keyboard-v1`, which gowl implements
and Mutter does not, so under GNOME voxtype falls through to `ydotool`, which
needs `ydotool.service` running.

## What not to do

- Do not expect a clone of one of these components to affect the running system.
  It is the *source* the binary was built from, not the live config; changing it
  does nothing until the deps container and the image are rebuilt.
- Do not edit shipped modules or plugins in place. Copy into `~/.config/gowl/`,
  which precedes the system directories in the plugin search path.
- Do not tell someone to drop a compositor module `.c` file in
  `~/.config/gowl/bar-plugins/` and expect it to load as a module. That directory
  is for *bar* plugins. A compositor module is a `.so`; from `$HOME` it is loaded
  by `config.c` standalone or through `CMACS_GOWL_MODULE_DIR` under cmacs — see
  [`gowl.md`](gowl.md).
- Do not assume GNOME advice applies to gowl, or the reverse. Check
  `XDG_CURRENT_DESKTOP` first.
