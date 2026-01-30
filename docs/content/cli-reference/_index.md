+++
title = 'CLI Reference'
weight = 3
+++

# CLI Reference

Immutablue provides several command-line tools for system management.

## Primary Commands

| Command | Description |
|---------|-------------|
| [immutablue](immutablue/) | Main command (justfile wrapper) for common tasks |
| [immutablue-update](immutablue-update/) | Update all system components |
| [immutablue-doctor](immutablue-doctor/) | System health checks and diagnostics |
| [immutablue-settings](immutablue-settings/) | Query configuration values |

## System Management

| Command | Description |
|---------|-------------|
| [immutablue-libvirt-manager](immutablue-libvirt-manager/) | Enable/disable libvirt virtualization |
| [immutablue-script-orchestrator](immutablue-script-orchestrator/) | Run scheduled scripts (internal) |

## VM & Testing

| Command | Description |
|---------|-------------|
| [immutablue-lima-gen](immutablue-lima-gen/) | Generate Lima VM configurations |
| [immutablue-qcow2-gen](immutablue-qcow2-gen/) | Generate qcow2 VM images |

## Quick Examples

```bash
# Run system health check
immutablue doctor

# Update everything
immutablue update

# Check a setting value
immutablue-settings .immutablue.profile.enable_starship

# Enable virtualization
immutablue enable_libvirt
```
