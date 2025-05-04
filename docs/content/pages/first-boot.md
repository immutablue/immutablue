+++
date = '2025-04-21T10:00:00-05:00'
draft = false
type = 'page'
title = 'Enhanced First Boot Experience'
+++

# Enhanced First Boot Experience

Immutablue provides a comprehensive interactive first-boot experience to help you set up your system efficiently when you first install it. This guide explains how the first-boot process works, what features it offers, and how you can customize it.

## Overview

The enhanced first-boot experience provides:

1. A guided setup wizard for both CLI and GUI systems
2. Hardware detection and optimization
3. Network configuration checks
4. Development environment selection and setup
5. Application installation options
6. Desktop environment customization (on graphical variants)

The system automatically determines whether to run a text-based (TUI) or graphical (GUI) setup wizard based on your Immutablue variant (nucleus builds use TUI, graphical builds use GUI).

## First Boot Process

The Immutablue first-boot process consists of several components that work together:

1. **First Boot Service**: A systemd service (`immutablue-first-boot.service`) that runs on the first system boot
2. **First Login Service**: A user-level systemd service (`immutablue-first-login.service`) that runs on first user login
3. **Setup TUI**: A text-based user interface for terminal-only installations
4. **Setup GUI**: A graphical user interface for desktop installations
5. **Configuration System**: YAML-based configuration to customize the setup experience

### First Boot Flow

Here's how the process works when you first boot your Immutablue system:

1. The system boots up and `immutablue-first-boot.service` runs automatically
2. For nucleus (CLI) builds:
   - The TUI setup wizard launches immediately
   - You complete the setup steps in the terminal
   - Your selections are saved to your user settings file
   - The system is configured according to your selections

3. For graphical builds:
   - Initial system setup proceeds in the background
   - When you log in for the first time, `immutablue-first-login.service` runs
   - The GUI setup wizard launches in your desktop session
   - You complete the setup steps in the graphical interface
   - Your selections are saved to your user settings file
   - The system is configured according to your selections

4. After completing setup, the system may reboot to apply all changes

## Setup Wizard Features

The setup wizard guides you through multiple steps to customize your Immutablue experience:

### 1. Introduction

An overview of Immutablue, its immutable design approach, and key features.

### 2. Hardware Detection

Automatically detects your system's hardware and applies optimizations:
- CPU identification and optimization
- Memory detection
- GPU detection and driver setup
- Storage configuration

### 3. Network Configuration

Validates your network connectivity and helps establish a stable connection:
- Connectivity checks
- Network interface configuration
- Network service setup

### 4. Development Environment

Choose development environments to install via Distrobox:
- Basic development tools (compilers, git, etc.)
- Language-specific environments (Python, Node.js, Rust, Go, Java)
- Data science tools
- Container development environments

### 5. Application Installation

Select applications to install via Flatpak:
- Web browsers
- Development tools
- Office applications
- Media applications
- Productivity tools

### 6. Completion

Final steps and system configuration based on your selections.

## Customizing the First Boot Experience

The first-boot experience can be customized in several ways:

### Configuration Files

The setup wizard reads its configuration from a hierarchy of YAML files:

```
${HOME}/.config/immutablue/first_boot_config.yaml  # User-specific config
/etc/immutablue/setup/first_boot_config.yaml       # System-wide config
/usr/immutablue/setup/first_boot_config.yaml       # Default config
```

You can also provide a custom configuration file directly using the `--config` option:

```bash
# Use a custom config file for the TUI setup
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --config /path/to/custom_config.yaml

# Use a custom config file for the GUI setup
/usr/libexec/immutablue/setup/immutablue_setup_gui.py --config /path/to/custom_config.yaml
```

This custom configuration file will override the entire configuration hierarchy, allowing for complete customization without modifying system files.

### Controlling the First Boot Process

You can control whether the first-boot experience runs via settings in the Immutablue settings hierarchy:

```yaml
immutablue:
  # Enable or disable first boot scripts
  run_first_boot_script: true 
  run_first_login_script: true
  run_first_boot_graphical_installer: true
  
  # Enhanced setup configuration
  setup:
    # Enable the enhanced interactive setup
    enabled: true
```

### Default Selections

You can configure default selections for development environments and applications by customizing the configuration file:

```yaml
steps:
  - id: "dev_env"
    options:
      - id: "devbox_python"
        default: true  # Make Python dev environment selected by default
```

### Custom Steps

Organizations deploying Immutablue at scale can customize the setup wizard by:

1. Creating a custom `first_boot_config.yaml` with organization-specific steps
2. Including it in your build via the overrides system
3. Deploying it to `/etc/immutablue/setup/first_boot_config.yaml`

Alternatively, for testing or development purposes, you can create a custom configuration file and use it directly with the `--config` option:

```bash
# Create a custom config file
cat > ~/my_custom_setup.yaml << EOF
welcome:
  title: "Welcome to Custom Immutablue"
  description: "This is a customized setup for our organization."

steps:
  - id: "org_intro"
    title: "Organization Introduction"
    description: "Welcome to our organization's customized Immutablue system."
    type: "info"
  # Add more custom steps here
EOF

# Run the setup with the custom config
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --config ~/my_custom_setup.yaml
```

This approach is particularly useful for:
- Testing new steps before deploying them system-wide
- Creating specialized setup flows for different users or departments
- Quickly iterating on setup designs without rebuilding the system

Example of a custom step:

```yaml
steps:
  - id: "org_setup"
    title: "Organization Setup"
    description: "Configure organization-specific settings"
    type: "options"
    option_type: "checkbox"
    options:
      - id: "org_vpn"
        label: "Configure VPN"
        description: "Set up secure VPN access to organization resources"
        default: true
```

## Re-running the Setup

If you need to re-run the first-boot setup:

```bash
# Remove the flag files
sudo rm /etc/immutablue/setup/did_first_boot /etc/immutablue/setup/did_first_boot_graphical /etc/immutablue/setup/did_first_boot_setup
rm $HOME/.config/.immutablue_did_first_login

# Unmask the services
sudo systemctl unmask immutablue-first-boot.service
systemctl --user unmask immutablue-first-login.service 

# Reboot
sudo reboot
```

Alternatively, you can use the built-in helper function:

```bash
immutablue_services_enable_setup_for_next_boot
```

## Technical Implementation

The enhanced first-boot experience consists of several components:

1. **TUI Application**: A Python application using the `curses` library for text-based interfaces
2. **GUI Application**: A Python application using GTK4 for graphical interfaces
3. **Configuration System**: YAML-based definition of setup steps and options
4. **Integration Scripts**: Bash scripts that integrate with systemd and the Immutablue services framework

The implementation follows these design principles:

- **Configuration-driven**: Steps and options are defined in YAML, not hardcoded
- **Separation of UI and logic**: Core functions are separated from presentation
- **Consistent experience**: Similar steps and flow in both TUI and GUI
- **Extensibility**: Easy to add new steps or modify existing ones
- **Fallback mechanisms**: If enhanced setup fails, fall back to basic setup

## Advanced Options

The setup applications support several command-line options for advanced usage. To see all available options, you can run either script with the `--help` flag:

```bash
# TUI version help
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --help

# GUI version help
/usr/libexec/immutablue/setup/immutablue_setup_gui.py --help
```

Available options include:

### Dry Run Mode

You can run the setup applications in "dry run" mode to see what actions would be performed without actually making any changes to the system:

```bash
# TUI version
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --dry-run

# GUI version
/usr/libexec/immutablue/setup/immutablue_setup_gui.py --dry-run
```

In dry run mode, the applications will:
- Load configuration files
- Show steps that would be executed
- Print what settings would be saved
- Print what files would be created
- Not make any actual changes to the filesystem

This is useful for:
- Testing configuration changes
- Debugging problems with the setup process
- Understanding what the setup process will do before running it
- Verifying custom configurations

### Custom Configuration File

You can provide a custom configuration file that overrides the default configuration hierarchy:

```bash
# TUI version
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --config /path/to/custom_config.yaml

# GUI version
/usr/libexec/immutablue/setup/immutablue_setup_gui.py --config /path/to/custom_config.yaml
```

When using the `--config` option:
- The specified configuration file will be used exclusively
- It overrides the entire configuration hierarchy (user, system, and default settings)
- If the file doesn't exist, the application will use built-in defaults

This is useful for:
- Organization-specific setup scenarios
- Testing new setup configurations without modifying system files
- Deploying standardized configuration across multiple systems
- Development and testing of custom setup flows

The custom configuration file must follow the same YAML structure as the default configuration.

### Force Mode

You can force the setup to run again even if it has already been completed:

```bash
# TUI version
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --force

# GUI version
/usr/libexec/immutablue/setup/immutablue_setup_gui.py --force
```

### Skip Reboot

You can run the setup without automatically rebooting at the end:

```bash
# TUI version
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --no-reboot

# GUI version
/usr/libexec/immutablue/setup/immutablue_setup_gui.py --no-reboot
```

### Combining Options

You can combine multiple command-line options for more complex scenarios:

```bash
# Run with a custom config in dry-run mode
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --config /path/to/custom_config.yaml --dry-run

# Force run with a custom config and skip reboot
sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --config /path/to/custom_config.yaml --force --no-reboot
```

## Troubleshooting

If you encounter issues with the first-boot experience:

1. **Logs**: Check journalctl for errors:
   ```bash
   sudo journalctl -u immutablue-first-boot.service
   journalctl --user -u immutablue-first-login.service
   ```

2. **Dry Run Test**: Run the setup in dry run mode to see what would happen:
   ```bash
   # TUI version
   sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --dry-run
   
   # GUI version
   /usr/libexec/immutablue/setup/immutablue_setup_gui.py --dry-run
   ```

3. **Manual Launch**: Run the setup applications directly:
   ```bash
   # TUI version
   sudo /usr/libexec/immutablue/setup/immutablue_setup_tui.py --force
   
   # GUI version
   /usr/libexec/immutablue/setup/immutablue_setup_gui.py --force
   ```

4. **Reset Configuration**: Remove any custom configurations:
   ```bash
   rm -f ~/.config/immutablue/first_boot_config.yaml
   sudo rm -f /etc/immutablue/setup/first_boot_config.yaml
   ```

5. **Flag Files**: Check if the flag files exist:
   ```bash
   ls -la /etc/immutablue/setup/did_first_boot*
   ls -la $HOME/.config/.immutablue_did_first_login
   ```