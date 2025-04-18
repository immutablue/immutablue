+++
date = '2025-04-18T18:00:00-05:00'
draft = false
title = 'Settings YAML Reference'
+++

# Settings YAML Reference

The Immutablue settings system is described in the [Component Architecture](component-architecture.md#settings-system) page. This page provides more detailed reference information about the settings system and examples of common settings.

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
immutablue-settings .services.syncthing.tailscale-mode
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

## Common Settings

Here are some important settings that control Immutablue's behavior:

```yaml
immutablue:
  # Control whether to run 'immutablue install' after updating
  run_install_on_update: true

  # Control which components to update with 'immutablue-update'
  run_bootc_update: true
  run_distrobox_upgrade: true 
  run_flatpak_system_update: true 
  run_flatpak_user_update: true 
  run_brew_update: true

  # Control first boot behavior
  run_first_boot_graphical_installer: true
  run_first_boot_script: true 
  run_first_login_script: true

  # Network connectivity check settings
  header:
    force_always_has_internet: false
    force_always_has_internet_v4: false
    force_always_has_internet_v6: false
    has_internet_host_v4: "9.9.9.9"
    has_internet_host_v6: "2620:fe::fe"

  # Shell environment settings
  profile:
    enable_starship: true 
    enable_brew_bash_completions: true
    enable_sourcing_fzf_git: true

# Service-specific settings
services:
  syncthing:
    tailscale_mode: true
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

