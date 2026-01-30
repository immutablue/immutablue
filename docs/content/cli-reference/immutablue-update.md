+++
title = 'immutablue-update'
weight = 3
+++

# immutablue-update

Update all system components in one command.

## Synopsis

```bash
immutablue-update
```

## Description

`immutablue-update` is a comprehensive update command that updates all components of your Immutablue system. It respects settings in `settings.yaml` to control which components are updated.

## What Gets Updated

By default, `immutablue-update` updates:

| Component | Setting | Default |
|-----------|---------|---------|
| Bootc image | `.immutablue.run_bootc_update` | `true` |
| Distrobox containers | `.immutablue.run_distrobox_upgrade` | `true` |
| System Flatpaks | `.immutablue.run_flatpak_system_update` | `true` |
| User Flatpaks | `.immutablue.run_flatpak_user_update` | `true` |
| Homebrew | `.immutablue.run_brew_update` | `true` |

## Post-Update Behavior

If `.immutablue.run_install_on_update` is `true` (default), the system will run `immutablue install` on the next reboot to ensure all post-install tasks are completed.

## Examples

### Run a full update

```bash
immutablue-update
```

### Using the immutablue command alias

```bash
immutablue update
```

## Disabling Specific Updates

To skip updating a specific component, set its setting to `false`:

```yaml
# ~/.config/immutablue/settings.yaml
immutablue:
  run_brew_update: false  # Don't update Homebrew
```

## Automatic Updates

Immutablue runs automatic updates weekly via the `immutablue-weekly.timer` systemd timer. This includes running `immutablue-update` automatically.

To check timer status:
```bash
systemctl list-timers | grep immutablue
```

## See Also

- [Updating Guide](/user-guide/updating/)
- [Settings Reference](/user-guide/settings/)
- [Systemd Services](/system-components/systemd-services/)
