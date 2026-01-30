+++
title = 'immutablue-script-orchestrator'
weight = 6
+++

# immutablue-script-orchestrator

Execute scheduled scripts for system and user automation.

## Synopsis

```bash
immutablue-script-orchestrator <MODE>
```

## Description

`immutablue-script-orchestrator` is an internal command that runs scripts from designated directories based on a schedule. It's typically invoked by systemd timers and services, not directly by users.

## Modes

| Mode | Description |
|------|-------------|
| `on_boot` | Scripts run at system boot |
| `on_shutdown` | Scripts run at system shutdown |
| `hourly` | Scripts run every hour |
| `daily` | Scripts run daily |
| `weekly` | Scripts run weekly |
| `monthly` | Scripts run monthly |

## Script Directories

Scripts are organized by scope (system vs user) and schedule:

### System Scripts (run as root)
```
/usr/libexec/immutablue/system/
├── on_boot/
├── on_shutdown/
├── hourly/
├── daily/
├── weekly/
└── monthly/
```

### User Scripts (run as current user)
```
/usr/libexec/immutablue/user/
├── on_boot/
├── on_shutdown/
├── hourly/
├── daily/
├── weekly/
└── monthly/
```

### Custom Scripts
You can add custom scripts in:
```
/etc/immutablue/scripts/system/<mode>/
/etc/immutablue/scripts/user/<mode>/
```

## Writing Custom Scripts

1. Create a script in the appropriate directory
2. Make it executable: `chmod +x script.sh`
3. Name it with a numeric prefix for ordering (e.g., `10-my-script.sh`)

Example custom daily script:
```bash
#!/bin/bash
# /etc/immutablue/scripts/user/daily/10-backup-notes.sh

rsync -av ~/Documents/notes/ ~/Backups/notes/
```

## Systemd Integration

The orchestrator is invoked by these systemd units:

| Timer/Service | Mode |
|---------------|------|
| `immutablue-onboot.service` | on_boot |
| `immutablue-hourly.timer` | hourly |
| `immutablue-daily.timer` | daily |
| `immutablue-weekly.timer` | weekly |
| `immutablue-monthly.timer` | monthly |

Check timer status:
```bash
systemctl list-timers --all | grep immutablue
```

## See Also

- [Scheduled Scripts](/system-components/scheduled-scripts/)
- [Systemd Services](/system-components/systemd-services/)
