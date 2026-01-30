+++
title = 'User Guide'
weight = 2
+++

# User Guide

This section covers day-to-day usage of your Immutablue system.

## Topics

- [Package Management](package-management/) - Installing and managing software
- [Updating](updating/) - Keeping your system up to date
- [Maintenance](maintenance/) - System maintenance and troubleshooting
- [Doctor](doctor/) - System health checks and diagnostics
- [Settings Reference](settings/) - Configuring Immutablue via settings.yaml

## Quick Tips

### Installing Software

Immutablue supports multiple package management approaches:

| Method | Best For | Command Example |
|--------|----------|-----------------|
| Flatpak | GUI apps | `flatpak install flathub org.mozilla.firefox` |
| Distrobox | CLI tools, dev environments | `distrobox enter dev` |
| Homebrew | CLI tools | `brew install ripgrep` |
| rpm-ostree | System packages (rare) | `rpm-ostree install vim` |

### Updating Everything

```bash
immutablue update
```

This updates: bootc image, distrobox containers, flatpaks, and homebrew packages.

### Checking System Health

```bash
immutablue doctor
```

Runs diagnostics and reports any issues with your system.
