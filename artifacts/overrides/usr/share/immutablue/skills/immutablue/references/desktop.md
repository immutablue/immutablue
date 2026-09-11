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
