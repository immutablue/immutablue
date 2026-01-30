+++
title = 'Scheduled Scripts'
weight = 1
+++

# Scheduled Scripts

Immutablue provides a framework for running scripts on various schedules, both at the system level (as root) and user level.

## Overview

Scripts are organized in directories under `/usr/libexec/immutablue/` and can be extended via `/etc/immutablue/scripts/`.

## Directory Structure

### Built-in Scripts

```
/usr/libexec/immutablue/
├── system/                    # Run as root
│   ├── on_boot/              # At system startup
│   ├── on_shutdown/          # At system shutdown
│   ├── hourly/               # Every hour
│   ├── daily/                # Every day
│   ├── weekly/               # Every week
│   └── monthly/              # Every month
│
└── user/                      # Run as current user
    ├── on_boot/              # At user login (first login after boot)
    ├── on_shutdown/          # At user logout
    ├── hourly/               # Every hour
    ├── daily/                # Every day
    ├── weekly/               # Every week
    └── monthly/              # Every month
```

### Custom Scripts

Add your own scripts to:
```
/etc/immutablue/scripts/
├── system/<schedule>/        # Custom system scripts
└── user/<schedule>/          # Custom user scripts
```

## How It Works

1. Systemd timers trigger `immutablue-script-orchestrator` at scheduled intervals
2. The orchestrator runs all scripts in the corresponding directory
3. Scripts run in alphabetical order (use numeric prefixes like `00-`, `10-`, `20-`)

## Schedule Timing

| Schedule | System Timer | User Timer |
|----------|--------------|------------|
| On Boot | `immutablue-onboot.service` | `immutablue-onboot.service` (user) |
| Hourly | `immutablue-hourly.timer` | `immutablue-hourly.timer` (user) |
| Daily | `immutablue-daily.timer` | `immutablue-daily.timer` (user) |
| Weekly | `immutablue-weekly.timer` | `immutablue-weekly.timer` (user) |
| Monthly | `immutablue-monthly.timer` | `immutablue-monthly.timer` (user) |

## Writing Custom Scripts

### Basic Template

```bash
#!/bin/bash
set -euo pipefail

# Your script logic here
echo "Running my custom script at $(date)"
```

### Example: Daily Backup Script

```bash
#!/bin/bash
# /etc/immutablue/scripts/user/daily/10-backup-documents.sh
set -euo pipefail

BACKUP_DIR="${HOME}/Backups/documents"
SOURCE_DIR="${HOME}/Documents"

mkdir -p "${BACKUP_DIR}"
rsync -av --delete "${SOURCE_DIR}/" "${BACKUP_DIR}/"

echo "Documents backed up at $(date)"
```

### Example: Weekly Cleanup Script

```bash
#!/bin/bash
# /etc/immutablue/scripts/user/weekly/20-cleanup-downloads.sh
set -euo pipefail

# Remove files older than 30 days from Downloads
find "${HOME}/Downloads" -type f -mtime +30 -delete

echo "Downloads cleaned at $(date)"
```

## Script Requirements

1. **Must be executable**: `chmod +x script.sh`
2. **Should use a shebang**: `#!/bin/bash`
3. **Recommended**: Use `set -euo pipefail` for safety
4. **Naming**: Use numeric prefixes for ordering (e.g., `10-`, `20-`)

## Checking Timer Status

```bash
# List all immutablue timers
systemctl list-timers --all | grep immutablue

# Check specific timer
systemctl status immutablue-daily.timer

# Check user timers
systemctl --user list-timers | grep immutablue
```

## Manually Running Scripts

```bash
# Run all daily system scripts
sudo immutablue-script-orchestrator daily

# Run all hourly user scripts
immutablue-script-orchestrator hourly
```

## Logging

Script output is captured by journald:

```bash
# View system script logs
journalctl -u immutablue-daily.service

# View user script logs
journalctl --user -u immutablue-daily.service
```

## Default Scripts

### System On-Boot (`00-on_boot.sh`)
- Basic system initialization tasks

### System On-Shutdown (`00-on_shutdown.sh`)
- Cleanup tasks before shutdown

### User On-Login (`00-on_login.sh`)
- User session initialization

### User On-Logout (`00-on_logout.sh`)
- User session cleanup

### User Weekly (`00_weekly.sh`)
- Runs `immutablue-update` for automatic updates

## See Also

- [immutablue-script-orchestrator](/cli-reference/immutablue-script-orchestrator/)
- [Systemd Services](/system-components/systemd-services/)
