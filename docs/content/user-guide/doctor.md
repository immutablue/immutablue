+++
date = '2026-01-28T21:00:00-05:00'
draft = false
title = 'Doctor - System Health Checks'
+++

# Immutablue Doctor

The `immutablue doctor` command performs comprehensive health checks on your system to verify everything is working correctly. Similar to `brew doctor` or `flutter doctor`, it helps you quickly identify and resolve issues.

## Quick Start

Run a basic health check:

```bash
immutablue doctor
```

## Usage

```bash
immutablue doctor [OPTIONS]
```

### Available Commands

| Command | Description |
|---------|-------------|
| `immutablue doctor` | Run all health checks |
| `immutablue doctor_verbose` | Run with detailed output |
| `immutablue doctor_fix` | Run and attempt to fix issues |
| `immutablue doctor_json` | Output results as JSON (for scripting) |
| `immutablue doctor_yaml` | Output results as YAML (for scripting) |

### Command Line Options

You can also run the doctor script directly with options:

```bash
/usr/libexec/immutablue/immutablue-doctor [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--verbose`, `-v` | Show detailed output for each check |
| `--fix` | Attempt to automatically fix issues where possible |
| `--json` | Output results in JSON format |
| `--yaml` | Output results in YAML format |
| `--help`, `-h` | Show help message |
| `--version` | Show version information |

## Example Output

```
Immutablue Doctor v1.0.0
Checking system health...

OSTree / Bootc Status
─────────────────────────────────────
  ✓ OSTree deployment healthy
  ✓ No pending deployments
  ✓ Bootc status healthy

System Services
─────────────────────────────────────
  ✓ Tailscale VPN daemon
  ✓ SSH daemon

User Services
─────────────────────────────────────
  ✓ Syncthing file sync

Network Connectivity
─────────────────────────────────────
  ✓ IPv4 connectivity
  ✓ IPv6 connectivity
  ✓ Container registry (quay.io)
  ✓ Tailscale connected

Disk Space
─────────────────────────────────────
  ✓ Root filesystem
  ✓ Variable data
  ✓ Home directories

Homebrew
─────────────────────────────────────
  ✓ Homebrew installed
  ✓ Homebrew functional
  ✓ Brew packages up to date

Flatpak
─────────────────────────────────────
  ✓ Flatpak installed
  ✓ Flathub remote configured

Distrobox
─────────────────────────────────────
  ✓ Distrobox installed
  ✓ Distrobox containers

─────────────────────────────────────
Summary
─────────────────────────────────────
  ✓ Passed:   15
  ✗ Failed:   0
  ⚠ Warnings: 0

All checks passed! Your system is healthy.
```

## Health Checks Performed

### OSTree / Bootc Status

- **Deployment health**: Verifies `rpm-ostree status` works correctly
- **Pending updates**: Checks if a reboot is needed to apply updates
- **Bootc status**: Validates bootc container status (if available)

### System Services

Checks that expected system services are running:

- `tailscaled.service` - Tailscale VPN daemon
- `sshd.service` - SSH daemon

**Variant-specific services:**
- **Trueblue**: `cockpit.socket`
- **Kuberblue**: `cockpit.socket`, `crio.service`, `kubelet.service`

### User Services

- `syncthing.service` - Syncthing file synchronization

### Network Connectivity

- **IPv4 connectivity**: Pings configured IPv4 test host
- **IPv6 connectivity**: Pings configured IPv6 test host (optional)
- **Container registry**: Verifies quay.io is reachable
- **Tailscale**: Checks Tailscale connection status

### Disk Space

Monitors disk usage on critical mount points:

| Location | Warning | Critical |
|----------|---------|----------|
| `/var` | 85% | 95% |
| `/home` | 85% | 95% |

> **Note:** The root filesystem (`/`) is skipped because on Silverblue/composefs it's a small overlay that always shows 100% used — not meaningful for health checks.

### Homebrew (x86_64 only)

- **Installation**: Checks if Homebrew is installed at `/home/linuxbrew/.linuxbrew`
- **Functionality**: Verifies the `brew` command works
- **Updates**: Counts outdated packages

### Flatpak

- **Installation**: Verifies Flatpak is available
- **Flathub**: Checks if the Flathub remote is configured

### Distrobox

- **Installation**: Verifies Distrobox is available
- **Containers**: Lists configured containers

### Variant-Specific Checks

#### Kuberblue

- `kubectl` installation
- Kubernetes cluster accessibility

#### Trueblue

- ZFS installation and pool health
- Cockpit web console availability

## Using --fix Mode

The `--fix` flag attempts to automatically resolve certain issues:

```bash
immutablue doctor_fix
```

**What --fix can do:**
- Start stopped services that are enabled but not running
- (More auto-fix capabilities may be added in future versions)

**What --fix cannot do:**
- Install missing packages
- Configure services
- Fix hardware issues

Always review the output before and after running with `--fix`.

## Machine-Readable Output

For scripting and automation, use JSON or YAML output:

### JSON Output

```bash
immutablue doctor_json
```

Example JSON output:

```json
{
  "version": "1.0.0",
  "image": "immutablue:43-lts",
  "timestamp": "2026-01-28T21:30:00-05:00",
  "summary": {
    "passed": 15,
    "failed": 0,
    "warnings": 1
  },
  "results": [
    {"check":"OSTree deployment healthy","status":"pass","message":"Current image: immutablue:43-lts"},
    {"check":"No pending deployments","status":"pass","message":""}
  ]
}
```

### Using with jq

```bash
# Get just the summary
immutablue doctor_json | jq '.summary'

# Check if any failures
immutablue doctor_json | jq '.summary.failed > 0'

# List failed checks
immutablue doctor_json | jq '.results[] | select(.status == "fail")'
```

### YAML Output

```bash
immutablue doctor_yaml
```

Example YAML output:

```yaml
---
version: "1.0.0"
image: "immutablue:43-lts"
timestamp: "2026-01-28T21:30:00-05:00"
summary:
  passed: 15
  failed: 0
  warnings: 1
results:
  - check: "OSTree deployment healthy"
    status: "pass"
    message: "Current image: immutablue:43-lts"
  - check: "No pending deployments"
    status: "pass"
```

### Using with yq

```bash
# Get just the summary
immutablue doctor_yaml | yq '.summary'

# Check if any failures
immutablue doctor_yaml | yq '.summary.failed > 0'

# List failed checks
immutablue doctor_yaml | yq '.results[] | select(.status == "fail")'
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed |

## Troubleshooting Common Issues

### "OSTree deployment" failed

```
✗ OSTree deployment
  rpm-ostree status failed
```

**Solution:** Run `rpm-ostree status` manually to see the error. This may indicate a corrupted deployment.

### "Container registry (quay.io)" failed

```
✗ Container registry (quay.io)
  Cannot reach quay.io
```

**Possible causes:**
- No internet connection
- Firewall blocking HTTPS
- DNS resolution issues

**Solutions:**
1. Check your network connection
2. Verify DNS: `dig quay.io`
3. Check firewall: `immutablue toggle_firewall`

### "Tailscale not connected"

```
⚠ Tailscale not connected
  Run 'tailscale up' to connect
```

**Solution:**
```bash
tailscale up
```

### Disk space warnings

```
⚠ Root filesystem
  87% used, 5.2G available
```

**Solutions:**
1. Clean unused containers: `podman image prune -af`
2. Clean flatpaks: `flatpak uninstall --unused`
3. Clean rpm-ostree: `sudo rpm-ostree cleanup -m`
4. Run: `immutablue clean_system`

### Homebrew not in PATH

```
⚠ Homebrew not in PATH
  Source /etc/profile.d/brew.sh or restart shell
```

**Solution:** Start a new shell session or run:
```bash
source /etc/profile.d/brew.sh
```

## Integration with Monitoring

You can integrate the doctor command with monitoring systems:

### Cron job for daily checks

```bash
# /etc/cron.daily/immutablue-doctor
#!/bin/bash
/usr/libexec/immutablue/immutablue-doctor --json > /var/log/immutablue-doctor.json
```

### Systemd timer

Create a periodic health check with systemd:

```ini
# /etc/systemd/system/immutablue-doctor.timer
[Unit]
Description=Daily Immutablue health check

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/immutablue-doctor.service
[Unit]
Description=Immutablue health check

[Service]
Type=oneshot
ExecStart=/usr/libexec/immutablue/immutablue-doctor
```

## See Also

- [Maintenance and Troubleshooting](/pages/maintenance-and-troubleshooting/)
- [Update Guide](/pages/update/)
- [Justfiles and the Immutablue Command](/pages/justfiles-and-the-immutablue-command/)
