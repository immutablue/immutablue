+++
title = 'Header Library'
weight = 3
+++

# immutablue-header.sh

The `immutablue-header.sh` bash library provides utility functions for Immutablue scripts.

## Location

```
/usr/libexec/immutablue/immutablue-header.sh
```

## Usage

Source the header in your scripts:

```bash
#!/bin/bash
source /usr/libexec/immutablue/immutablue-header.sh

# Now you can use the functions
if [[ "$(immutablue_has_internet)" == "${TRUE}" ]]; then
    echo "Connected to internet"
fi
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `TRUE` | `"true"` | Boolean true string |
| `FALSE` | `"false"` | Boolean false string |

## Functions

### Internet Connectivity

#### `immutablue_has_internet`

Check if the system has any internet connectivity (IPv4 or IPv6).

```bash
if [[ "$(immutablue_has_internet)" == "${TRUE}" ]]; then
    echo "Online"
fi
```

Settings that affect this:
- `.immutablue.header.force_always_has_internet` - Always return true

#### `immutablue_has_internet_v4`

Check IPv4 connectivity specifically.

```bash
if [[ "$(immutablue_has_internet_v4)" == "${TRUE}" ]]; then
    echo "IPv4 available"
fi
```

Settings:
- `.immutablue.header.force_always_has_internet_v4` - Always return true
- `.immutablue.header.has_internet_host_v4` - Host to ping (default: `9.9.9.9`)

#### `immutablue_has_internet_v6`

Check IPv6 connectivity specifically.

```bash
if [[ "$(immutablue_has_internet_v6)" == "${TRUE}" ]]; then
    echo "IPv6 available"
fi
```

Settings:
- `.immutablue.header.force_always_has_internet_v6` - Always return true
- `.immutablue.header.has_internet_host_v6` - Host to ping (default: `2620:fe::fe`)

### Terminal Detection

#### `immutablue_get_terminal_command`

Get the appropriate terminal emulator command for the current system.

```bash
terminal_cmd="$(immutablue_get_terminal_command)"
if [[ -n "${terminal_cmd}" ]]; then
    ${terminal_cmd} -e "htop"
fi
```

Detection order (unless overridden):
1. kitty
2. ptyxis
3. gnome-terminal

Settings:
- `.immutablue.header.preferred_terminal` - Override detection (`auto`, `kitty`, `ptyxis`, `gnome-terminal`)

### Setup Control

#### `immutablue_services_enable_setup_for_next_boot`

Re-enable the first-boot setup process.

```bash
immutablue_services_enable_setup_for_next_boot
```

This:
- Removes completion markers
- Unmasks the first-boot service
- Setup will run on next boot

#### `immutablue_services_disable_setup_for_next_boot`

Disable the first-boot setup (marks as complete).

```bash
immutablue_services_disable_setup_for_next_boot
```

### Utility Functions

#### `immutablue_wait_for_internet`

Block until internet is available (with optional timeout).

```bash
# Wait up to 30 seconds for internet
immutablue_wait_for_internet 30
```

## Example Script

```bash
#!/bin/bash
set -euo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

echo "Checking connectivity..."

if [[ "$(immutablue_has_internet)" == "${TRUE}" ]]; then
    echo "✓ Internet available"
    
    if [[ "$(immutablue_has_internet_v4)" == "${TRUE}" ]]; then
        echo "  - IPv4: yes"
    fi
    
    if [[ "$(immutablue_has_internet_v6)" == "${TRUE}" ]]; then
        echo "  - IPv6: yes"
    fi
else
    echo "✗ No internet connection"
    exit 1
fi

# Get terminal for GUI operations
terminal="$(immutablue_get_terminal_command)"
echo "Preferred terminal: ${terminal:-none}"
```

## See Also

- [immutablue-settings](/cli-reference/immutablue-settings/)
- [Settings Reference](/user-guide/settings/)
