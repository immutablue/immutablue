+++
title = 'Systemd Services'
weight = 2
+++

# Systemd Services & Timers

Immutablue includes several systemd services and timers for system automation.

## System Services

| Service | Description |
|---------|-------------|
| `immutablue-first-boot.service` | Runs first-boot setup wizard |
| `immutablue-onboot.service` | Runs on-boot scripts |
| `immutablue-hourly.service` | Hourly maintenance scripts |
| `immutablue-daily.service` | Daily maintenance scripts |
| `immutablue-weekly.service` | Weekly maintenance scripts |
| `immutablue-monthly.service` | Monthly maintenance scripts |
| `lima-guest-ready.service` | Lima VM guest agent |

## System Timers

| Timer | Schedule | Triggers |
|-------|----------|----------|
| `immutablue-hourly.timer` | Every hour | `immutablue-hourly.service` |
| `immutablue-daily.timer` | Daily | `immutablue-daily.service` |
| `immutablue-weekly.timer` | Weekly | `immutablue-weekly.service` |
| `immutablue-monthly.timer` | Monthly | `immutablue-monthly.service` |

## User Services

| Service | Description |
|---------|-------------|
| `immutablue-first-login.service` | First-login user setup |
| `immutablue-onboot.service` | User on-login scripts |
| `syncthing-override.service` | Syncthing with Tailscale integration |

## User Timers

| Timer | Schedule | Triggers |
|-------|----------|----------|
| `immutablue-hourly.timer` | Every hour | `immutablue-hourly.service` |
| `immutablue-daily.timer` | Daily | `immutablue-daily.service` |
| `immutablue-weekly.timer` | Weekly | `immutablue-weekly.service` |
| `immutablue-monthly.timer` | Monthly | `immutablue-monthly.service` |

## Managing Services

### Check service status

```bash
# System service
systemctl status immutablue-onboot.service

# User service
systemctl --user status syncthing-override.service
```

### List all timers

```bash
# System timers
systemctl list-timers --all | grep immutablue

# User timers
systemctl --user list-timers | grep immutablue
```

### View service logs

```bash
# System service logs
journalctl -u immutablue-daily.service

# User service logs
journalctl --user -u immutablue-daily.service

# Follow logs in real-time
journalctl -u immutablue-weekly.service -f
```

### Manually trigger a service

```bash
# Run daily maintenance now
sudo systemctl start immutablue-daily.service

# Run user weekly maintenance now
systemctl --user start immutablue-weekly.service
```

## First Boot Service

The `immutablue-first-boot.service` runs once after installation to:

1. Display the graphical setup wizard (if enabled)
2. Run first-boot scripts
3. Mark first-boot as complete

### Re-running First Boot

To re-run the first boot setup:

```bash
immutablue initial_setup
```

Or to fully reset first-boot state:

```bash
# Remove the completion marker
rm ~/.config/.immutablue_did_first_login

# Re-enable and reboot
sudo systemctl unmask immutablue-first-boot.service
sudo reboot
```

## Syncthing Override Service

The `syncthing-override.service` wraps Syncthing with Tailscale integration:

- Detects Tailscale IP if available
- Configures Syncthing to listen on Tailscale interface
- Falls back to standard binding if Tailscale unavailable

Configuration:
```yaml
# settings.yaml
services:
  syncthing:
    tailscale_mode: true  # Enable Tailscale integration
```

## Quadlet Container Services

Immutablue uses Podman Quadlet for containerized services:

### immutablue-docs.container

Runs the documentation server:

```bash
# Check status
systemctl --user status immutablue-docs.service

# View at http://localhost:1313
```

## Disabling Services

```bash
# Disable a system timer
sudo systemctl disable immutablue-weekly.timer

# Disable a user service
systemctl --user disable syncthing-override.service
```

## See Also

- [Scheduled Scripts](/system-components/scheduled-scripts/)
- [immutablue-script-orchestrator](/cli-reference/immutablue-script-orchestrator/)
