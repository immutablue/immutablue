# Automation: Hooks, Settings, and the Shared Header

Immutablue ships a small automation surface that is easy to miss and easy to
reinvent badly. Reach for these before writing a systemd timer by hand.

## Hook directories

`immutablue-script-orchestrator <mode>` runs every script in three layers, in
this order, and the systemd timers and `immutablue-update` call it for you:

| Layer | Path | Who owns it |
|-------|------|-------------|
| image | `/usr/libexec/immutablue/<scope>/<mode>/` | the image, read-only |
| host | `/etc/immutablue/scripts/<scope>/<mode>/` | root; survives updates |
| user | `~/.config/immutablue/scripts/<mode>/` | you; **no `user/` segment** |

`<scope>` is decided by UID, not by argument: root runs the `system` trees, anyone
else runs the `user` trees, and only a non-root run reads the home layer.

| Mode | Fired by |
|------|----------|
| `on_boot`, `on_shutdown` | `immutablue-onboot.service` (system and user); user `on_boot` is first login after boot |
| `hourly`, `daily`, `weekly`, `monthly` | `immutablue-<mode>.timer` (system and `--user`) |
| `pre_update`, `post_update` | `immutablue-update`, before anything is touched / only after every component succeeded |

How scripts actually run — this is where the docs and the code differ, and the
code wins:

- Each script is fed to `bash - < script`. The executable bit is **not**
  required and the shebang is **not** honoured: a hook must be bash.
- Any path containing `.ignore` is skipped. That is how the shipped placeholder
  files are ignored, and how you park a hook without deleting it
  (`10-backup.sh.ignore`).
- A failing script prints `<path> failed with <n>` and the run **continues**.
  For `pre_update` that means a failed hook does not stop the update; if it
  must, make the hook itself refuse loudly and check the journal.
- Within each layer, scripts run in glob order — use numeric prefixes.

```bash
mkdir -p ~/.config/immutablue/scripts/daily
cat > ~/.config/immutablue/scripts/daily/10-backup-notes.sh <<'SH'
set -euo pipefail
rsync -a --delete ~/Documents/notes/ ~/Backups/notes/
SH
immutablue-script-orchestrator daily        # run the whole mode now, as you
systemctl --user list-timers | grep immutablue
journalctl --user -u immutablue-daily.service
```

A system-wide hook goes in `/etc/immutablue/scripts/system/<mode>/` and is
exercised with `sudo immutablue-script-orchestrator <mode>`. Do not put hooks in
`/usr/libexec/immutablue/` on a running machine — that is the image layer and is
read-only; ship them through `artifacts/overrides/` instead.

## The update hooks

`immutablue-update` brackets its work with `pre_update` and `post_update` so
machine-specific steps attach to an update without editing a script in `/usr`:
stop a service that dislikes its files being replaced, export a pool, resync
something afterwards. It normally runs as your user, so it reads the **user**
trees; run it as root for the system ones. `post_update` only fires when every
component succeeded, so it can assume the update is good.

## `immutablue-settings`

One key, resolved through the cascade
`~/.config/immutablue/settings.yaml` → `/etc/immutablue/settings.yaml` →
`/usr/immutablue/settings.yaml`, first file that defines it wins:

```bash
immutablue-settings .immutablue.profile.enable_starship     # true
immutablue-settings .services.syncthing.tailscale_mode
```

Exit 1 means not found or an invalid path. This is what every shipped script
uses, so a setting you add to `/usr/immutablue/settings.yaml` in the image is
immediately readable the same way. Groups that exist today: `run_*` (update
components), `snapshot_*`, `gen.*` (generator output paths), `header.*`,
`profile.*`, `run_first_boot_*`, `services.*`, `kuberblue.*`. See
[`configuration.md`](configuration.md) for how to override one.

## The shared bash header

`/usr/libexec/immutablue/immutablue-header.sh` is sourced by every shipped
script and is the right thing to source in yours:

```bash
source /usr/libexec/immutablue/immutablue-header.sh
```

| Function | Returns |
|----------|---------|
| `immutablue_get_image_full` / `_base` / `_tag` / `_version` | `immutablue:44` / `immutablue` / `44-lts` / `44`, from `image-info.json` |
| `immutablue_image_info_field <name>` | one flat string field of `image-info.json` (`built`, `source_commit`) |
| `immutablue_has_internet` / `_v4` / `_v6` | `${TRUE}` or `${FALSE}`; honours `header.force_always_has_internet*` and `header.has_internet_host_v4/v6` |
| `immutablue_wait_for_internet [secs]` | blocks until online, with a timeout |
| `immutablue_get_terminal_command` | kitty → ptyxis → gnome-terminal, or `header.preferred_terminal` |
| `immutablue_services_enable_setup_for_next_boot` / `_disable_` | re-arm or mark done the first-boot wizard |

`TRUE` is `1` and `FALSE` is `0`, and the functions *print* them — compare
against `"${TRUE}"`, do not test the exit status. The image-identity functions
read `image-info.json` with `sed`, not `yq`, because they run at early boot; do
the same in an `on_boot` hook rather than assuming `yq` is available.

## Login shell: `/etc/profile.d/25-immutablue.sh`

Runs for every login shell, driven by `immutablue.profile.*`:

| Key | Default | Effect |
|-----|---------|--------|
| `ulimit_nofile` | `524288` | `ulimit -n` for non-root users |
| `enable_starship` | `true` | `eval "$(starship init bash)"` |
| `enable_brew_bash_completions` | `true` | sources linuxbrew's `bash_completion.d/*` |
| `enable_sourcing_fzf_git` | `true` | sources `/usr/bin/fzf-git` |

Turn one off per user in `~/.config/immutablue/settings.yaml`. The `25-` prefix
places it after system defaults and before `90-` user drop-ins, so a later
`profile.d` file of yours can still override anything it set.

## First boot and first login

The shipped login/logout hooks use `${USER:-$(id -un)}` so systemd user units and other contexts without `USER` do not abort under `set -u`.

`immutablue-first-boot.service` runs `/usr/libexec/immutablue/setup/first_boot.sh`
once; on GUI variants `immutablue-first-login.service` then runs the graphical
wizard at first login. Nucleus gets the TUI immediately. Gated by
`immutablue.run_first_boot_script`, `run_first_login_script`, and
`run_first_boot_graphical_installer`.

Completion is tracked by marker files in `/etc/immutablue/setup/` —
`did_first_boot`, `did_first_boot_setup`, `did_first_boot_graphical` — plus the
wizard's answers in `first_boot_config.yaml`. The directory is `root:wheel 0775`
on purpose: a wheel user can re-arm setup without `sudo`, an unprivileged user
cannot suppress it.

```bash
immutablue initial_setup                          # re-run the wizard now, no reboot
immutablue_services_enable_setup_for_next_boot    # from the header: clear markers, unmask, run at next boot
```

`immutablue install` (distrobox, flatpaks, brew, services) is what the wizard
ends with, and is safe to re-run on its own; `immutablue.run_install_on_update`
makes `immutablue-update` re-run it after the next reboot.
