+++
title = 'Quick Start'
weight = 3
+++

# Quick Start Guide

TL;DR for experienced users. Get up and running fast.

## Install

```bash
# From existing Fedora Atomic/Silverblue
sudo bootc switch ghcr.io/immutablue/immutablue:latest

# Reboot
sudo reboot
```

## First Boot

1. Complete the setup wizard
2. Reboot when prompted

## Install Software

```bash
# GUI apps → Flatpak
flatpak install flathub org.mozilla.firefox

# CLI tools → Homebrew
brew install ripgrep fzf bat

# Dev environments → Distrobox
distrobox create -n dev -i fedora:latest
distrobox enter dev
```

## Update Everything

```bash
immutablue update
```

## Check System Health

```bash
immutablue doctor
```

## Common Tasks

| Task | Command |
|------|---------|
| Update system | `immutablue update` |
| Health check | `immutablue doctor` |
| Reboot to BIOS | `immutablue bios` |
| System info | `immutablue sysinfo` |
| Enable VMs | `immutablue enable_libvirt` |
| Clean system | `immutablue clean_system` |

## Configure

```bash
# Create user config
mkdir -p ~/.config/immutablue
cat > ~/.config/immutablue/settings.yaml << 'EOF'
immutablue:
  profile:
    enable_starship: true
EOF
```

## Key Directories

| Path | Purpose |
|------|---------|
| `~/.config/immutablue/` | User settings |
| `/etc/immutablue/` | System settings |
| `/usr/immutablue/` | Default settings |
| `/etc/immutablue/scripts/` | Custom automation scripts |

## Useful Commands

```bash
# Query settings
immutablue-settings .immutablue.profile.enable_starship

# List timers
systemctl list-timers | grep immutablue

# View update logs
journalctl -u immutablue-weekly.service

# Test in VM
immutablue-lima-gen && limactl start immutablue
```

## Need Help?

- [Full Documentation](/)
- [GitLab Issues](https://gitlab.com/immutablue/immutablue/-/issues)
- Run `immutablue doctor` for diagnostics
