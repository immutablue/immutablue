+++
title = 'immutablue-libvirt-manager'
weight = 5
+++

# immutablue-libvirt-manager

Manage libvirt virtualization services.

## Synopsis

```bash
immutablue-libvirt-manager [OPTIONS] <COMMAND>
```

## Description

`immutablue-libvirt-manager` provides an easy way to enable or disable libvirt virtualization on your Immutablue system. It handles:

- Starting/stopping libvirt services
- Managing socket activation
- Setting up user group membership (for non-root VM management)

## Commands

| Command | Description |
|---------|-------------|
| `enable` | Enable libvirt services and add user to libvirt group |
| `disable` | Disable libvirt services |
| `status` | Show current libvirt status |

## Options

| Option | Description |
|--------|-------------|
| `-s`, `--sudo` | Run with sudo (required for enable/disable) |
| `--dry-run` | Show what would be done without making changes |

## Examples

### Check libvirt status

```bash
immutablue-libvirt-manager status
```

### Enable virtualization

```bash
immutablue-libvirt-manager -s enable
```

After enabling, you'll need to log out and back in for group membership to take effect.

### Disable virtualization

```bash
immutablue-libvirt-manager -s disable
```

### Preview changes (dry run)

```bash
immutablue-libvirt-manager -s --dry-run enable
```

## Using via immutablue command

```bash
# Enable libvirt
immutablue enable_libvirt

# Disable libvirt
immutablue disable_libvirt

# Check status
immutablue status_libvirt

# Dry run enable
immutablue enable_libvirt_dry_run
```

## Services Managed

When enabled, the following services are activated:

- `libvirtd.service` - Main libvirt daemon
- `libvirtd.socket` - Socket activation
- `virtlogd.service` - Virtual machine logging
- `virtlockd.service` - Virtual machine locking

## Group Membership

When enabled, your user is added to the `libvirt` group, allowing you to manage VMs without root privileges. A logout/login is required for this to take effect.

## See Also

- [Lima VM Testing](/advanced/lima-testing/) - Alternative VM testing approach
