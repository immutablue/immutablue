# Recipe Catalogue

Every `immutablue <recipe>` that ships, by justfile. This is the complete list at
the time of writing; the running system is authoritative, so when in doubt:

```bash
immutablue                                    # every recipe, with its one-line comment
grep -n -A 20 '^recipe_name' /usr/libexec/immutablue/just/*.justfile
```

Read a recipe before running it. Some are destructive (`crash_capture_test_panic`
panics the kernel, `clean_system` prunes container storage) and none of them ask
twice unless the comment says so.

## 00-base — install, update, health, services

| Recipe | Does |
|--------|------|
| `bios` | `systemctl reboot --firmware-setup`; refuses on a BIOS-booted install |
| `sysinfo` / `sysinfo_post` | system summary for a bug report; `_post` uploads it to a pastebin |
| `logs_since_boot` / `logs_since_last_boot` | `journalctl -b 0` / `journalctl -b 1` as root |
| `check_local_etc_overrides` | `diff -r` of the deployment's `/etc` against the image's, excluding machine-specific files — shows what this host has changed |
| `install` | post-install: distrobox, flatpaks, brew, services; the pieces are `install_distrobox`, `install_flatpak`, `install_brew`, `install_services`, `post_install`, `post_install_notes` |
| `update` | `immutablue-update`: bootc, distrobox, flatpak, brew per `settings.yaml`; `REBOOT=1` reboots after |
| `initial_setup` | re-run the first-boot wizard (GUI when `$DISPLAY` is set, TUI otherwise) without rebooting |
| `clean_system` | `podman image prune -af`, `podman volume prune -f`, `flatpak uninstall --unused`, `rpm-ostree cleanup -bm` |
| `toggle_firewall` | stop or start `firewalld` — for isolating a connectivity problem, not for leaving off |
| `enable_tailscale` / `disable_tailscale` | Tailscale is on by default |
| `enable_syncthing` / `disable_syncthing` | Syncthing is on by default, exposed over the Tailscale IP when `services.syncthing.tailscale_mode` is true |
| `enable_libvirt` / `disable_libvirt` / `status_libvirt` | libvirt services and group membership; `_dry_run` variants show the plan. Group membership needs a re-login |
| `fix_libvirt_selinux_mislabel` | relabel libvirt state under `/var`; the symptom is "network 'default' is not active" or virtlogd "Permission denied" |
| `doctor` / `doctor_verbose` / `doctor_fix` / `doctor_json` / `doctor_yaml` | health checks; `_json`/`_yaml` are for scripts and agents |
| `choose` | fzf picker over every recipe |

## 03-power — idle suspend

`disable_suspend`, `enable_suspend`, and the `_ac` / `_battery` halves. On a GNOME
session these set gsettings for the current user; they do **not** mask
`sleep.target`, so GDM can still suspend at the login screen and `systemctl
suspend` still works. For an unattended machine mask the targets instead — see
[`crash-capture.md`](crash-capture.md).

## 05-hardware-overrides

`hardware_override_asmedia_prefer_usb_storage_over_uas` and its `_unprefer_` undo.
For ASMedia USB-to-SATA bridges whose UAS implementation is broken; the tell in
`dmesg` is `uas_eh_device_reset_handler` / `uas_eh_abort_handler` lines.

## 06-crash-capture — kernel panic policy

| Recipe | Does |
|--------|------|
| `crash_capture_status` | current posture: sysctls, watchdog, console args, netconsole, pstore |
| `crash_capture_enable_panic_reboot DELAY="30"` | `panic_on_oops=1`, auto-reboot after DELAY |
| `crash_capture_disable_panic_reboot` | opt out, even where the image sets it |
| `crash_capture_reset_local` | drop the local override; image policy applies again |
| `crash_capture_enable_watchdog TIMEOUT="60"` / `_disable_watchdog` | hardware watchdog — mask suspend first |
| `crash_capture_verbose_console` / `_quiet_console` | remove / restore `quiet rhgb` so a panic trace is visible |
| `crash_capture_netconsole TARGET_IP TARGET_PORT="6666" SRC_PORT="6665"` / `_netconsole_disable` | stream kernel messages to another host |
| `crash_capture_test_panic` | **panics the machine on purpose**; asks for `CONFIRM` |

Details and the reasoning behind the two tiers: [`crash-capture.md`](crash-capture.md).

## 07-agents `[group('agents')]`

| Recipe | Does |
|--------|------|
| `list_agents` / `install_agents *names` / `reinstall_agent name` | the vendor-installed harnesses declared in `packages.yaml` |
| `ai_setup` / `ai_defaults` | pick and show the default provider/model for `ai` and `ai-tui` |
| `install_immutablue_skill` / `uninstall_immutablue_skill` | symlink this skill into every harness's skill directory |
| `crashes` / `crashes_all` / `analyze_crash pid=""` | list and analyse coredumps — [`crash-analysis.md`](crash-analysis.md) |
| `crash_watch_enable` / `_disable` / `_status` | the user service that notifies on crashes of image-shipped binaries |

## 08-rollback `[group('rollback')]`

`deployments`, `rollback`, `rebase tag=""`, `snapshots`, `snapshot`,
`restore_snapshot name=""`. Covered in [`updates.md`](updates.md).

## 09-dictation `[group('dictation')]`

`enable_dictation model=""`, `bind_dictation_key`, `dictation_status`,
`disable_dictation`. Covered in [`desktop.md`](desktop.md).

## Variant justfiles

These exist only on the variant that ships them:

| Variant | Recipes |
|---------|---------|
| cyan (`10-cyan`) | `enable_nvidia_kmod` (reboot), `disable_nvidia_kmod` (before rebasing off `-cyan`) |
| asahi (`25-asahi`) | `asahi_enable_notch_render` / `asahi_disable_notch_render` |
| kuberblue (`30-kuberblue`) | `kube_init`, `kube_join *ARGS`, `kube_reset *FLAGS`, `kube_status`, `kube_doctor`, `kube_get_config`, `deploy file_path`, `deploy_all`, `kube_override file`, `kube_sops_setup`, `kube_encrypt` / `kube_decrypt *FILES`, `kube_refresh_token`, `kube_upgrade *ARGS`, `kube_untaint_master`, `kube_add_kuberblue_user`, `kube_mcp_serve`, plus the boot hooks `on_boot`, `on_shutdown`, `first_boot`, `systemd_settings` |

Kuberblue is a Kubernetes node with its own setup flow; read
`/usr/libexec/immutablue/just/30-kuberblue.justfile` and
`/usr/kuberblue/cluster.yaml` before touching any of it.

## Not recipes, but on `PATH`

| Command | Purpose |
|---------|---------|
| `immutablue-settings <jq-path>` | read one key through the settings cascade — [`configuration.md`](configuration.md) |
| `immutablue-doctor` | what `doctor*` wraps |
| `immutablue-update` | what `update` wraps |
| `immutablue-snapshot` | what the snapshot recipes wrap |
| `immutablue-crash` | what the crash recipes wrap |
| `immutablue-agents` | what the agent recipes wrap |
| `immutablue-libvirt-manager` | what the libvirt recipes wrap |
| `immutablue-script-orchestrator <mode>` | runs the hook directories — [`automation.md`](automation.md) |
