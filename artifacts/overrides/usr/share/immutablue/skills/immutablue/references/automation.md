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

## podomation: event-driven automation

The hooks above run on a clock or around an update. For "when X happens, do Y"
— a file changes, a D-Bus signal, a container image is pushed, a webhook
arrives, power or network changes — the image ships **podomation**, an event
engine with a small DSL: `pod NAME = module->constructor(args);` and
`NAME->event => module->handler(args);`. Prefer it over a polling script in a
`daily` hook.

```bash
podomation list-modules                 # what this build has (the AI and registry ones included)
podomation help-module registry         # constructors, handlers, events, fields
podomation validate ~/.config/podomation/main.pod
podomation simulate ~/.config/podomation/main.pod   # binding topology, nothing runs
podomation run ~/.config/podomation/main.pod        # a bare .pod: every module enabled, no YAML needed
```

Config is searched `--config` → `$PODOMATION_CONFIG` →
`~/.config/podomation/config.yaml` → `/etc/podomation/config.yaml`. The image
ships **no service unit**; to keep one running, write a user unit
(`~/.config/systemd/user/podomation.service` with
`ExecStart=/usr/bin/podomation run %h/.config/podomation/main.pod`,
`Restart=always`) and `systemctl --user enable --now podomation`. Inside cmacs
the engine is also embedded — see `podomation.org` in the cmacs manual.

Example: tell the desktop when the image this machine tracks is repushed.

```
pod image = registry->new("https://quay.io", "immutablue/immutablue", "", 30, "44");
image->on_tag_updated => bash->run_inline("notify-send 'Image updated' '{event->repo}:{event->tag}'");
image->on_poll_failed => log->write_warning("registry poll failed: {event->message}");
```

`registry->new(base_url, repo, [token], [poll_min], [tag_pattern], [username], [password])`
fires `on_new_tag`, `on_tag_updated`, `on_tag_removed`, `on_poll_failed` and
`on_recovered`; the first poll after every start is a silent baseline. Use
the repository and tag from `rpm-ostree status`, not the example's. Put
credentials in `${ENV}` interpolation, never in the file.

AI handlers exist per backend — `ai_chat` (any ai-glib provider via
`provider:`), plus `ai_claude_code`, `ai_codex_cli`, `ai_cursor`,
`ai_antigravity`, `ai_opencode`, `ai_grok_build`. Each CLI backend must already
be installed and logged in ([`packages.md`](packages.md)); podomation never
installs or authenticates one, and `skip_permissions` is opt-in. Module docs are
`deps/podomation/modules/<module>.org` in the cmacs manual, which follows
cmacs's podomation pin rather than the binary's — `podomation help-module` is
the authority for what the installed build accepts.

## Scheduled AI prompts: `/loop` and `/goal`

A recurring prompt for `ai-tui` is a **loop**, not a timer or a hook:

```
/loop 10m check whether CI passed       # every 10 minutes; floor 1m, rounded to cron steps
/loop check the deploy                  # self-paced: the model picks the next delay (1–60m)
/goal the tests pass --turns 10 --time 2h   # turns until met, always bounded
/loop list    /goal list    /goal show 5e6f
```

| Fact | |
|---|---|
| Owner | one session; restored when that session is resumed (`ai-tui -c`, `--workspace-session`) — a fresh `ai-tui` starts with none |
| Lifetime | loops expire after 7 days; goals stop at `--turns` (default 20, max 200) or `--time` (default 2h, max 7d) |
| Never mid-turn | a due loop waits for the running turn, then fires once however many slots it missed |
| State | `$XDG_STATE_HOME/ai-glib/sessions/loops/<session>` (`~/.local/state/…`), JSON, mode 0600 |
| From a shell | `ai loop list`, `ai goal list --json`, `ai loop pause ID\|all --session ID`, `ai goal edit ID --turns 40`, `ai loop add --session ID 10m PROMPT` |
| Kill switch | `AI_LOOP_DISABLE=1` |

A scheduled built-in that would change the session (`/clear`, `/model`, …) is
refused; read-only ones like `/todos` are allowed. `/loop` with no prompt runs
the maintenance prompt from `.ai-glib/loop.md` (or `~/.config/ai-glib/loop.md`).
This needs a running `ai-tui` session; for an unattended job with no session,
use a podomation `ai_*` handler or a hook script calling `ai`.

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
| `immutablue_build_is_<variant>` / `immutablue_build_has_zfs` / `_has_gnome` / `_has_package <regex> <exclude-regex\|null>` | `${TRUE}` or `${FALSE}`, from `/usr/immutablue/build_options` or `rpm -qa`. `_is_kinoite` read the misspelt `kionite` (always `${FALSE}`) on images built from immutablue `f549e2d` or earlier — there, use `immutablue_is_option_in_build_options kinoite` |
| `immutablue_try_command_and_try_again_on_delay <secs> <cmd> [args…]` | runs `cmd`, sleeps and retries once on failure; prints `${TRUE}`/`${FALSE}` — there is no wait-for-network loop, use this around a connectivity check |
| `immutablue_get_terminal_command` | kitty → ptyxis → gnome-terminal, or `header.preferred_terminal` |
| `immutablue_services_enable_setup_for_next_boot` / `immutablue_services_force_setup_to_run_now` | re-arm the first-boot wizard for the next boot / and start it now (both `sudo`) |

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
