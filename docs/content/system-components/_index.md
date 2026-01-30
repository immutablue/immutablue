+++
title = 'System Components'
weight = 4
+++

# System Components

This section documents the internal components that make Immutablue work.

## Topics

- [Scheduled Scripts](scheduled-scripts/) - Hourly, daily, weekly, and monthly automation
- [Systemd Services](systemd-services/) - Background services and timers
- [Header Library](header-library/) - Bash utility functions (immutablue-header.sh)
- [Profile Configuration](profile-config/) - Shell profile customization

## Overview

Immutablue includes several system-level components that run automatically:

### Scheduled Scripts

Scripts in `/usr/libexec/immutablue/{system,user}/` run on schedules:

| Schedule | System | User |
|----------|--------|------|
| On Boot | ✓ | ✓ |
| On Shutdown | ✓ | ✓ |
| Hourly | ✓ | ✓ |
| Daily | ✓ | ✓ |
| Weekly | ✓ | ✓ |
| Monthly | ✓ | ✓ |

### Systemd Services

Key services include:
- `immutablue-first-boot.service` - Initial system setup
- `immutablue-onboot.service` - On-boot scripts
- `immutablue-{hourly,daily,weekly,monthly}.timer` - Scheduled automation

### Bash Library

The `immutablue-header.sh` library provides functions for:
- Internet connectivity checks
- Terminal detection
- Settings access
- Common utilities
