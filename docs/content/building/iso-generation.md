+++
date = '2026-01-31T21:00:00-05:00'
draft = false
title = 'ISO Generation'
weight = 25
+++

# ISO Generation

Immutablue supports two methods for generating bootable ISO images. The default method uses `bootc-image-builder` (the same tooling used for qcow2 generation), while the classic method uses `build-container-installer` for more Anaconda configuration options.

## Quick Start

```bash
# Build the image first
make build
make push

# Configure ISO (optional - adds user account and SSH keys)
make iso-config

# Generate ISO (default: bootc-image-builder)
make iso

# Generate ISO for a specific variant
make TRUEBLUE=1 iso-config
make TRUEBLUE=1 iso
```

## ISO Configuration

Before building an ISO, you can optionally configure user accounts and SSH keys using `make iso-config`. This creates an interactive wizard that generates a configuration file.

### Usage

```bash
# Configure for default build
make iso-config

# Configure for a specific variant
make TRUEBLUE=1 iso-config
make KINOITE=1 iso-config
```

### What It Configures

The wizard prompts for:

1. **Username**: The account name (default: `immutablue`)
2. **Password**: Required if adding a user
3. **Wheel group**: Whether to add sudo access (default: yes)
4. **SSH public key**: Optional path to an SSH public key for passwordless login

### Configuration Files

Configuration files are stored per-variant:
- Default: `./iso/config-43.toml`
- Trueblue: `./iso/config-43-trueblue.toml`
- Kinoite: `./iso/config-43-kinoite.toml`

### Building Without Configuration

If you run `make iso` without first running `make iso-config`, the ISO enables **interactive first-boot setup** (GNOME Initial Setup). After installation completes and the system reboots, you'll be guided through:

- Language and region selection
- Keyboard layout
- Timezone configuration
- User account creation
- Password setup

This is the recommended approach for ISOs distributed to end users, as it provides a familiar setup experience.

## Default Method: bootc-image-builder

The default `make iso` command uses `bootc-image-builder`, providing several benefits:

- **Unified tooling**: Same container and configuration as qcow2 generation
- **Consistent results**: ISO is generated directly from the OCI image
- **Less maintenance**: No separate ISO-specific configuration to maintain
- **Modern approach**: Uses bootc's native ISO generation capabilities

### Usage

```bash
# Basic ISO generation (uses existing config or blank)
make iso

# With variant flags
make KINOITE=1 iso
make NUCLEUS=1 LTS=1 iso
```

### Output

All ISOs are created at a consistent location:
```
./iso/immutablue-<tag>.iso
```

Examples:
- `make iso` → `./iso/immutablue-43.iso`
- `make TRUEBLUE=1 iso` → `./iso/immutablue-43-trueblue.iso`
- `make KINOITE=1 LTS=1 iso` → `./iso/immutablue-43-kinoite-lts.iso`

### How It Works

1. Checks for existing configuration (`./iso/config-<tag>.toml`)
2. If no config exists, creates a blank one (no users configured)
3. Pulls the target image from the registry
4. Runs `bootc-image-builder` with `--type iso`
5. Moves the resulting ISO to `./iso/immutablue-<tag>.iso`

## Classic Method: build-container-installer

The classic method uses `build-container-installer` and provides more Anaconda configuration options, including flatpak bundling.

### Usage

```bash
# Classic ISO generation
make CLASSIC_ISO=1 iso

# With variant flags
make CLASSIC_ISO=1 KINOITE=1 iso
```

### When to Use Classic

Use the classic method when you need:

- Bundled flatpak applications in the ISO
- Custom Anaconda kickstart configurations
- Specific installer customizations not supported by bootc-image-builder

## Testing ISOs

Test the ISO with QEMU:

```bash
make run_iso

# For variant builds
make TRUEBLUE=1 run_iso
```

This boots the ISO in a QEMU VM with:
- 8 CPU cores
- 8GB RAM
- 64GB disk
- UEFI boot mode
- Web console at http://localhost:8006

## Pushing ISOs

Upload the ISO to S3 storage:

```bash
make push_iso

# For variant builds
make TRUEBLUE=1 push_iso
```

Requires `S3_ACCESS_KEY` and `S3_SECRET_KEY` environment variables.

## Complete Workflow Example

```bash
# 1. Build and push the image
make TRUEBLUE=1 build
make TRUEBLUE=1 push

# 2. Configure ISO users (interactive)
make TRUEBLUE=1 iso-config

# 3. Build the ISO
make TRUEBLUE=1 iso

# 4. Test the ISO
make TRUEBLUE=1 run_iso

# 5. Push to S3
make TRUEBLUE=1 push_iso
```

## Comparison

| Feature | bootc-image-builder (default) | build-container-installer (classic) |
|---------|------------------------------|-------------------------------------|
| Tooling | Same as qcow2 | Separate tooling |
| User configuration | `make iso-config` | Kickstart |
| Flatpak bundling | No | Yes (optional) |
| Anaconda customization | Limited | Full |
| Output location | `./iso/immutablue-<tag>.iso` | `./iso/immutablue-<tag>.iso` |
| Maintenance | Lower | Higher |

## Troubleshooting

### ISO build fails with permission errors

Ensure you have sudo access and the container runtime has necessary privileges:

```bash
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest
```

### ISO doesn't boot

Verify the image was pushed to the registry before building the ISO:

```bash
make build
make push
make iso
```

### "No ISO found" when running or pushing

Make sure you've built the ISO first:

```bash
make iso
make run_iso
```

### First-boot setup doesn't appear

If GNOME Initial Setup doesn't appear after installation:
1. Verify `gnome-initial-setup` package is installed in your image
2. Check that the ISO was built without a pre-configured user (`make iso` without `make iso-config`)
3. The setup only runs once - if skipped or completed, it won't appear again
