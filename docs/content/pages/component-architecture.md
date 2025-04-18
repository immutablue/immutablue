+++
date = '2025-04-18T14:00:00-05:00'
draft = false
title = 'Component Architecture'
+++

# Immutablue Component Architecture

Immutablue is built on a modular foundation that follows the principles of containerization and inheritance. This document describes the core components that make up the Immutablue system and how they interact.

## Core Components

### Settings System

Immutablue uses a hierarchical settings system that allows for both system-wide and user-specific configurations. Settings are stored in YAML files at three different locations, evaluated in the following order:

1. `${HOME}/.config/immutablue/settings.yaml` - User-specific settings
2. `/etc/immutablue/settings.yaml` - System-wide settings
3. `/usr/immutablue/settings.yaml` - Default settings

The settings cascade in a fall-through manner, with more specific settings (user level) taking precedence over more general ones (system/default level). This allows for flexible configuration at different levels of the system.

Settings are accessed via the `immutablue-settings` tool, which takes a YAML key path as an argument:

```bash
immutablue-settings .services.syncthing.tailscale-mode
```

### System Initialization

Immutablue employs several systemd services to manage system initialization:

#### System-Level Services

- `immutablue-first-boot.service`: Runs on the first boot of the system
- `immutablue-onboot.service`: Runs on every boot
- `immutablue-hourly.timer`: Runs scheduled tasks hourly
- `immutablue-daily.timer`: Runs scheduled tasks daily
- `immutablue-weekly.timer`: Runs scheduled tasks weekly
- `immutablue-monthly.timer`: Runs scheduled tasks monthly

#### User-Level Services

- `immutablue-first-login.service`: Runs on the first login of a user
- `immutablue-onboot.service`: Runs when a user logs in
- `immutablue-hourly.timer`: Runs user-specific scheduled tasks hourly
- `immutablue-daily.timer`: Runs user-specific scheduled tasks daily
- `immutablue-weekly.timer`: Runs user-specific scheduled tasks weekly
- `immutablue-monthly.timer`: Runs user-specific scheduled tasks monthly

### Script Directory Structure

Immutablue organizes its scripts into a hierarchical structure based on when they should run:

```
/usr/libexec/immutablue/
├── system/
│   ├── daily/
│   ├── hourly/
│   ├── monthly/
│   ├── on_boot/
│   │   └── 00-on_boot.sh
│   ├── on_shutdown/
│   │   └── 00-on_shutdown.sh
│   └── weekly/
└── user/
    ├── daily/
    ├── hourly/
    ├── monthly/
    ├── on_boot/
    │   └── 00-on_login.sh
    ├── on_shutdown/
    │   └── 00-on_logout.sh
    └── weekly/
        └── 00_weekly.sh
```

Scripts placed in these directories are executed by the corresponding systemd services. For example, scripts in `/usr/libexec/immutablue/system/daily/` are executed by the `immutablue-daily.service` system service.

## Extending Immutablue

### File Overrides

Immutablue makes extensive use of file overrides to customize the root filesystem. These overrides are placed in the `artifacts/overrides/` directory during build time and are copied to their corresponding locations in the root filesystem.

For example, a file at `artifacts/overrides/usr/bin/my-script` will be placed at `/usr/bin/my-script` in the final image.

Common override locations include:

- Binaries: `/usr/bin/`
- Systemd units: `/usr/lib/systemd/system/` and `/usr/lib/systemd/user/`
- Quadlets: `/usr/share/containers/systemd/`
- Libexec scripts: `/usr/libexec/immutablue/`

### Custom Images

One of the key design principles of Immutablue is the ability to create custom images that inherit from the base image or one of the intermediate images. This follows the container pattern of doing `FROM <image>` and then making customizations.

Custom images can be created by:

1. Forking the `immutablue-custom` repository
2. Modifying the `packages.yaml` file to add or remove packages
3. Adding file overrides in the `artifacts/overrides/` directory
4. Building the image with `make build`

This allows for a high degree of customization while still benefiting from the base Immutablue functionality.

## Helper Functions

Immutablue provides a set of helper functions through the `/usr/libexec/immutablue/immutablue-header.sh` script. These functions can be used in your own scripts to interact with the Immutablue system.

Some useful helper functions include:

- `immutablue_get_image_full`: Returns the full image name
- `immutablue_get_image_tag`: Returns the image tag
- `immutablue_get_image_base`: Returns the base image name
- `immutablue_build_is_*`: Functions to check what build options were used
- `immutablue_has_internet`: Check if the system has internet connectivity
- `immutablue_services_enable_setup_for_next_boot`: Enable setup services for the next boot

To use these functions, source the header file at the beginning of your script:

```bash
#!/bin/bash
source /usr/libexec/immutablue/immutablue-header.sh

# Your script code here
```