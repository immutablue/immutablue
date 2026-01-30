+++
date = '2025-04-18T18:00:00-05:00'
draft = false
title = 'Settings YAML Reference'
+++

# Settings YAML Reference

The Immutablue settings system is described in the [Component Architecture](/pages/component-architecture#settings-system) page. This page provides more detailed reference information about the settings system and examples of common settings.

## Hierarchical Settings Files

Immutablue uses a hierarchical settings system with three possible locations for settings files:

```
${HOME}/.config/immutablue/settings.yaml  # User-specific settings
/etc/immutablue/settings.yaml             # System-wide settings
/usr/immutablue/settings.yaml             # Default settings
```

Settings are evaluated in that order, with more specific settings (higher in the list) taking precedence over more general ones. This provides a "fall-through" approach where user settings override system settings, and system settings override defaults.

## Accessing Settings Programmatically

### Command Line Access

You can query settings using the `immutablue-settings` command-line tool:

```bash
immutablue-settings .services.syncthing.tailscale_mode
```

### Bash Script Access

In bash scripts, you can access settings by sourcing the immutablue-header.sh file and using the provided functions:

```bash
#!/bin/bash
source /usr/libexec/immutablue/immutablue-header.sh

# Example: Check if a setting is enabled
if [[ "$(immutablue-settings .immutablue.run_first_boot_script)" == "true" ]]
then
    echo "First boot script is enabled"
else
    echo "First boot script is disabled"
fi
```

## Complete Settings Reference

Below is the complete reference for all available settings with their default values.

### Generator Settings

Output paths for `immutablue-lima-gen` and `immutablue-qcow2-gen` scripts:

| Setting | Default | Description |
|---------|---------|-------------|
| `.immutablue.gen.lima.path` | `~/.local/share/immutablue/lima` | Output directory for Lima VM config files |
| `.immutablue.gen.qcow2.path` | `~/.local/share/immutablue/images` | Output directory for qcow2 VM images |

### Update Settings

Control behavior of `immutablue-update`:

| Setting | Default | Description |
|---------|---------|-------------|
| `.immutablue.run_install_on_update` | `true` | Run `immutablue install` after updating |
| `.immutablue.run_bootc_update` | `true` | Run bootc update |
| `.immutablue.run_distrobox_upgrade` | `true` | Upgrade distrobox containers |
| `.immutablue.run_flatpak_system_update` | `true` | Update system flatpaks |
| `.immutablue.run_flatpak_user_update` | `true` | Update user flatpaks |
| `.immutablue.run_brew_update` | `true` | Update Homebrew packages |

### First Boot Settings

Control first boot and login behavior:

| Setting | Default | Description |
|---------|---------|-------------|
| `.immutablue.run_first_boot_graphical_installer` | `true` | Run the graphical first boot installer |
| `.immutablue.run_first_boot_script` | `true` | Run the first boot script |
| `.immutablue.run_first_login_script` | `true` | Run the first login script |

### Header Settings

Settings for `immutablue-header.sh` utility functions:

| Setting | Default | Description |
|---------|---------|-------------|
| `.immutablue.header.force_always_has_internet` | `false` | Always report internet as available |
| `.immutablue.header.force_always_has_internet_v4` | `false` | Always report IPv4 internet as available |
| `.immutablue.header.force_always_has_internet_v6` | `false` | Always report IPv6 internet as available |
| `.immutablue.header.has_internet_host_v4` | `9.9.9.9` | IPv4 host to ping for connectivity check |
| `.immutablue.header.has_internet_host_v6` | `2620:fe::fe` | IPv6 host to ping for connectivity check |
| `.immutablue.header.preferred_terminal` | `auto` | Preferred terminal emulator: `auto`, `kitty`, `ptyxis`, `gnome-terminal` |

### Profile Settings

Settings for the bash profile (`/etc/profile.d/25-immutablue.sh`):

| Setting | Default | Description |
|---------|---------|-------------|
| `.immutablue.profile.enable_starship` | `true` | Enable Starship prompt |
| `.immutablue.profile.enable_brew_bash_completions` | `true` | Enable Homebrew bash completions |
| `.immutablue.profile.enable_sourcing_fzf_git` | `true` | Source fzf-git integration |
| `.immutablue.profile.ulimit_nofile` | `524288` | File descriptor limit for non-root users |

### Service Settings

Settings for specific services:

| Setting | Default | Description |
|---------|---------|-------------|
| `.services.syncthing.tailscale_mode` | `true` | Expose Syncthing WebUI over Tailscale IP |

### Kuberblue Settings

Settings specific to Kuberblue builds:

| Setting | Default | Description |
|---------|---------|-------------|
| `.kuberblue.install_dir` | `/usr/immutablue-build-kuberblue` | Kuberblue build artifacts directory |
| `.kuberblue.config_dir` | `/etc/kuberblue` | Kuberblue configuration directory |
| `.kuberblue.uid` | `970` | UID for the kuberblue system user |

## Example Settings File

Here is a complete example `settings.yaml` showing all available options:

```yaml
immutablue:
  # Generator output paths
  gen:
    lima:
      path: "~/.local/share/immutablue/lima"
    qcow2:
      path: "~/.local/share/immutablue/images"

  # Update behavior
  run_install_on_update: true
  run_bootc_update: true
  run_distrobox_upgrade: true 
  run_flatpak_system_update: true 
  run_flatpak_user_update: true 
  run_brew_update: true

  # First boot behavior
  run_first_boot_graphical_installer: true
  run_first_boot_script: true 
  run_first_login_script: true

  # Header utilities
  header:
    force_always_has_internet: false
    force_always_has_internet_v4: false
    force_always_has_internet_v6: false
    has_internet_host_v4: "9.9.9.9"
    has_internet_host_v6: "2620:fe::fe"
    preferred_terminal: "auto"

  # Shell profile
  profile:
    enable_starship: true 
    enable_brew_bash_completions: true
    enable_sourcing_fzf_git: true
    ulimit_nofile: 524288

# Services
services:
  syncthing:
    tailscale_mode: true

# Kuberblue (only used in Kuberblue builds)
kuberblue:
  install_dir: "/usr/immutablue-build-kuberblue"
  config_dir: "/etc/kuberblue"
  uid: 970
```

## Customizing Settings

### Default Settings

To customize the default settings in a custom build:

1. Create a custom `settings.yaml` file
2. Place it in your overrides directory: `artifacts/overrides/usr/immutablue/settings.yaml`
3. This file will be installed to `/usr/immutablue/settings.yaml` during the build

### System-wide Overrides

To create system-wide overrides that affect all users:

1. Create a file at `/etc/immutablue/settings.yaml`
2. Add your custom settings
3. These will override the default settings

### User-specific Overrides

For individual user settings:

1. Create a file at `~/.config/immutablue/settings.yaml`
2. Add your custom settings
3. These will override both system and default settings

### Example: Custom Terminal Preference

To always use kitty as your terminal:

```yaml
# ~/.config/immutablue/settings.yaml
immutablue:
  header:
    preferred_terminal: "kitty"
```

### Example: Disable Starship

To disable the Starship prompt:

```yaml
# ~/.config/immutablue/settings.yaml
immutablue:
  profile:
    enable_starship: false
```

### Example: Custom Lima Output Path

To store Lima configs in a different location:

```yaml
# ~/.config/immutablue/settings.yaml
immutablue:
  gen:
    lima:
      path: "~/vms/lima"
```
