+++
title = 'Build Scripts'
weight = 4
+++

# Build Scripts

Immutablue uses a series of numbered bash scripts in the `build/` directory to customize images during the container build process.

## Script Execution Order

Scripts run in alphanumeric order:

| Script | Purpose |
|--------|---------|
| `00-pre.sh` | Pre-build setup |
| `10-copy.sh` | Copy overlay files |
| `20-add-repos.sh` | Add package repositories |
| `30-install-packages.sh` | Install RPM packages |
| `40-uninstall-packages.sh` | Remove unwanted packages |
| `50-remove-files.sh` | Remove unwanted files |
| `60-services.sh` | Configure systemd services |
| `90-post.sh` | Post-build customization |
| `99-common.sh` | Shared functions (sourced, not executed) |

## Script Environment

All scripts have access to:

```bash
CUSTOM_INSTALL_DIR    # Path to the build directory
```

Scripts should source `99-common.sh` for shared functions:

```bash
#!/bin/bash
set -euxo pipefail
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then
    source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"
fi
if [ -f "./99-common.sh" ]; then
    source "./99-common.sh"
fi
```

## Common Functions (99-common.sh)

The `99-common.sh` file provides helper functions:

| Function | Description |
|----------|-------------|
| `install_packages()` | Install packages from a file |
| `uninstall_packages()` | Remove packages from a file |
| `add_repos()` | Add repository files |

## Script Details

### 00-pre.sh

Runs before any other build steps. Use for:
- Setting environment variables
- Pre-flight checks
- Initializing build state

### 10-copy.sh

Copies files from `artifacts/overrides/` to the image:

```bash
# Copy all override files to root
cp -r "${CUSTOM_INSTALL_DIR}/artifacts/overrides/"* /
```

### 20-add-repos.sh

Adds package repositories:

```bash
# Copy repo files
cp "${CUSTOM_INSTALL_DIR}/packages/repos/"*.repo /etc/yum.repos.d/

# Import GPG keys
rpm --import https://example.com/key.gpg
```

### 30-install-packages.sh

Installs RPM packages from package list files:

```bash
# Install packages from packages/rpm.txt
install_packages "${CUSTOM_INSTALL_DIR}/packages/rpm.txt"
```

### 40-uninstall-packages.sh

Removes unwanted packages:

```bash
# Remove packages from packages/uninstall.txt
uninstall_packages "${CUSTOM_INSTALL_DIR}/packages/uninstall.txt"
```

### 50-remove-files.sh

Removes unwanted files from the image:

```bash
# Remove specific files
rm -f /etc/some-unwanted-file

# Remove directories
rm -rf /usr/share/doc/*
```

### 60-services.sh

Configures systemd services:

```bash
# Enable services
systemctl enable my-service.service

# Mask unwanted services
systemctl mask unwanted.service
```

### 90-post.sh

Final customizations:

```bash
# Run dconf update for GNOME settings
dconf update

# Build documentation
cd /usr/immutablue/docs && hugo build

# Any final cleanup
```

## Creating Custom Scripts

For your own Immutablue variant:

1. Create scripts in `build/` with appropriate numbering
2. Use existing scripts as templates
3. Always start with shebang and error handling:

```bash
#!/bin/bash
set -euxo pipefail
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then
    source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"
fi
```

## Package Files

Package lists are stored in `packages/`:

| File | Format | Purpose |
|------|--------|---------|
| `rpm.txt` | One package per line | RPM packages to install |
| `rpm_aarch64.txt` | One package per line | ARM64-specific packages |
| `rpm_x86_64.txt` | One package per line | x86_64-specific packages |
| `uninstall.txt` | One package per line | Packages to remove |

### Example rpm.txt

```
# Core packages
vim-enhanced
htop
tmux

# Development
git
make
gcc
```

## Overlay Files

Files in `artifacts/overrides/` are copied to the image root:

```
artifacts/overrides/
├── etc/
│   ├── dconf/
│   └── immutablue/
├── usr/
│   ├── bin/
│   ├── lib/
│   └── libexec/
└── ...
```

## Debugging Builds

```bash
# Build with verbose output
make build 2>&1 | tee build.log

# Enter failed build container
podman run -it --rm <image-id> /bin/bash
```

## See Also

- [Build Reference](/building/build-reference/)
- [Customization Guide](/building/customization/)
- [Architecture](/building/architecture/)
