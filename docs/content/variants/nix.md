+++
title = 'Nix Variant'
weight = 6
+++

# Nix Variant

The Nix variant of Immutablue integrates the Nix package manager for users who want access to the Nix ecosystem.

## Overview

This variant includes:

- Nix package manager
- Nix store mounted at `/nix`
- Systemd service for Nix store mounting

## Installation

```bash
sudo bootc switch ghcr.io/immutablue/immutablue-nix:latest
sudo reboot
```

## Using Nix

### Install Packages

```bash
# Install a package
nix-env -iA nixpkgs.ripgrep

# Search for packages
nix search nixpkgs firefox

# Run without installing
nix-shell -p ripgrep --run "rg --version"
```

### Nix Flakes

Enable flakes in `~/.config/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

Then use:
```bash
# Run from flake
nix run nixpkgs#hello

# Development shell
nix develop
```

## Systemd Integration

| Service | Description |
|---------|-------------|
| `mount-nix.service` | Mounts the Nix store |

The Nix store is mounted automatically at boot.

## Comparison with Other Package Managers

| Feature | Nix | Flatpak | Distrobox | Homebrew |
|---------|-----|---------|-----------|----------|
| Reproducibility | ✓✓✓ | ✓ | ✓ | ✓ |
| Rollback | ✓✓✓ | ✗ | ✗ | ✗ |
| GUI Apps | ✓ | ✓✓✓ | ✓ | ✗ |
| Development | ✓✓✓ | ✗ | ✓✓ | ✓ |
| Disk Usage | High | Medium | Low | Medium |

## When to Use Nix

**Good for:**
- Reproducible development environments
- Specific package versions
- Declarative system configuration
- NixOS users transitioning to Immutablue

**Consider alternatives for:**
- Simple GUI app installation (use Flatpak)
- Quick CLI tools (use Homebrew)
- Isolated environments (use Distrobox)

## Configuration

### Multi-user vs Single-user

The Nix variant uses multi-user installation by default, which provides:
- Builds run as unprivileged users
- Multiple users can share the Nix store
- Better security

### Garbage Collection

Clean up old packages:

```bash
# Remove old generations
nix-collect-garbage -d

# Remove packages older than 30 days
nix-collect-garbage --delete-older-than 30d
```

## Troubleshooting

### Nix commands not found

Ensure the Nix profile is sourced:

```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Store not mounted

```bash
# Check service status
systemctl status mount-nix.service

# Manual mount
sudo systemctl start mount-nix.service
```

## See Also

- [Immutablue Variants](/variants/)
- [Package Management](/user-guide/package-management/)
- [Nix Manual](https://nixos.org/manual/nix/stable/)
