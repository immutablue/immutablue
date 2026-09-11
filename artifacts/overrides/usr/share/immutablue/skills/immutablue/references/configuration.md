# Configuring Immutablue

Read this before changing any system setting on a machine running Immutablue.

The question to answer first is **which layer owns this setting**. There are four,
and putting a change in the wrong one is how it gets silently reverted on the next
update.

| Layer | Path | Survives update? |
|-------|------|------------------|
| Image defaults | `/usr/immutablue/settings.yaml` | replaced by the update |
| System override | `/etc/immutablue/settings.yaml` | yes |
| User override | `~/.config/immutablue/settings.yaml` | yes |
| The image itself | the git repo — see [`building.md`](building.md) | yes, everywhere |

## Immutablue's own settings

`immutablue-settings` resolves a key across the cascade, highest priority first:
`~/.config/immutablue/settings.yaml` → `/etc/immutablue/settings.yaml` →
`/usr/immutablue/settings.yaml`.

```bash
immutablue-settings .immutablue.run_bootc_update      # read one key
cat /usr/immutablue/settings.yaml                     # see every key and its default
```

To change one, copy just that key into `/etc/immutablue/settings.yaml` (system-wide)
or `~/.config/immutablue/settings.yaml` (one user). **Never edit
`/usr/immutablue/settings.yaml`** — it is read-only and replaced on update.

```bash
sudo mkdir -p /etc/immutablue
sudo tee -a /etc/immutablue/settings.yaml <<'YAML'
immutablue:
  run_flatpak_user_update: false
YAML
```

The file is read with `yq`, so it must be a valid YAML mapping. The cascade merges
by key lookup, not by deep merge of documents: a key is taken from the first file
that defines it.

### What is actually settable

Read the shipped file rather than guessing — it is commented per key. The broad
groups today:

- `immutablue.run_*` — which components `immutablue-update` touches (bootc,
  distrobox, flatpak system/user, brew), and whether install runs on update
- `immutablue.snapshot_before_update`, `snapshot_keep` — `/var` snapshot policy
- `immutablue.gen.*` — output paths for the Lima and qcow2 generators
- `immutablue.header.*` — connectivity detection and preferred terminal
- `immutablue.profile.*` — starship, brew completions, fzf-git, `ulimit -n`
- `services.syncthing.*`, `kuberblue.*` — per-service and variant settings
- `immutablue.run_first_boot_*` — whether the first-boot wizard and scripts run

`immutablue.profile.*` drives `/etc/profile.d/25-immutablue.sh` and
`immutablue.header.*` drives the shared bash header; both are described in
[`automation.md`](automation.md).

## GNOME settings (dconf)

Immutablue ships desktop defaults as a dconf keyfile compiled into the `local`
database at build time. Fedora's profile reads `user-db:user` **before**
`system-db:local`, so these are defaults, not policy: anything changed in the GUI
wins and keeps winning, and resetting a key falls back to the Immutablue default
rather than GNOME's.

```bash
gsettings set org.gnome.desktop.interface color-scheme default   # your choice wins
gsettings reset org.gnome.desktop.interface color-scheme         # back to the image default
```

To add your own system-wide defaults:

```bash
sudo tee /etc/dconf/db/local.d/50-mine <<'EOF2'
[org/gnome/desktop/interface]
clock-show-seconds=true
EOF2
sudo dconf update
```

Two traps worth knowing:

- **`dconf update` reads every file in `local.d/`, whatever it is named.** A
  `.disabled` or `.bak` suffix does not exclude it. To keep a keyfile inert, store
  it somewhere else entirely.
- **Arrays do not layer.** dconf resolves a key by taking the first database that
  defines it; it does not merge. So a system default for an array key — GNOME's
  `custom-keybindings` is the one that bites — is invisible to any user who has
  ever set that key themselves. Appending to the user's existing array is the only
  way to add one entry.

Nothing is placed in `/etc/dconf/db/local.d/locks/`, so no setting is enforced.

## Services

`systemctl` works normally, and changes under `/etc/systemd/` persist. But a unit
enabled by hand is enabled on **this machine only**. To make it true everywhere,
add it to the `services_enable_sys` / `services_enable_user` / `services_disable_*`
/ `services_mask_*` lists in `packages.yaml` — see [`building.md`](building.md).

## Configuration that belongs to a component, not to Immutablue

Several things Immutablue ships have their own configuration systems, with their
own cascades. Do not try to drive them through `settings.yaml`:

| Component | Config |
|-----------|--------|
| gowl compositor | `~/.config/gowl/` — YAML plus optional C; see [`gowl.md`](gowl.md) |
| the gowl bar | `~/.config/gowl/bar-plugins/`; see [`gowl-bar.md`](gowl-bar.md) |
| cmacs | `init.el`, `~/.config/cmacs/init.c`, `init.bacon`; see [`cmacs.md`](cmacs.md) |
| gst | `~/.config/gst/config.yaml`, `config.c`; see [`gst.md`](gst.md) |
| gsurf | `~/.config/gsurf/config.yaml`, `config.c`, or Elisp under cmacs; see [`gsurf.md`](gsurf.md) |
| voxtype dictation | `~/.config/voxtype/config.toml`, or `voxtype configure` |
| `ai` (ai-glib) | `/usr/share/ai-glib/config.yaml` → `/etc/ai-glib/config.yaml` → `~/.config/ai-glib/config.yaml`, or `ai --setup` |

## Checking your work

```bash
immutablue check_local_etc_overrides   # what in /etc diverges from the image
immutablue doctor                      # whether the result is coherent
```

`check_local_etc_overrides` is the fastest way to answer "what has been changed on
this machine" — on an atomic system that set is small and knowable, which is much
of the point.
