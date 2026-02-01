# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Immutablue is an easy, modular, and customizable implementation of a base Fedora Silverblue (and other Atomic desktops) image with sane defaults. It uses cloud-native container methodology and a layered build system.

**Key Concepts:**
- Immutable base OS with transactional updates
- Container-based image builds (Containerfile/Podman)
- Layered package management (Flatpak, Distrobox, Homebrew, rpm-ostree)
- Modular variant system (Cyan for NVIDIA, Asahi for Apple Silicon, etc.)
- YAML-based configuration (`settings.yaml`, `packages.yaml`)

## Build Commands

### Basic Build

```bash
make build                    # Build default (Silverblue) image
make build SKIP_TEST=1        # Skip pre/post-build tests
make test                     # Run all post-build tests
make pre_test                 # Run shellcheck validation only
```

### Variant Flags

Combine flags to build specific variants:

| Flag | Description | Image Tag Example |
|------|-------------|-------------------|
| `NUCLEUS=1` | Minimal (no GUI) | `43-nucleus` |
| `KINOITE=1` | KDE Plasma desktop | `43-kinoite` |
| `SERICEA=1` | Sway compositor | `43-sericea` |
| `CYAN=1` | NVIDIA GPU support | `43-cyan` |
| `ASAHI=1` | Apple Silicon (M1/M2/M3) | `43-asahi` |
| `KUBERBLUE=1` | Kubernetes support | `43-kuberblue` |
| `TRUEBLUE=1` | ZFS + LTS kernel | `43-trueblue` |
| `LTS=1` | LTS kernel (6.12) | `43-lts` |
| `ZFS=1` | ZFS modules (no tag change) | `43` (with ZFS) |
| `NIX=1` | Nix package manager | `43-nix` |

**Examples:**
```bash
make CYAN=1 build             # NVIDIA variant
make KUBERBLUE=1 build        # Kubernetes variant
make LTS=1 build              # LTS kernel variant
make CYAN=1 LTS=1 build       # NVIDIA + LTS kernel
```

### Other Build Options

```bash
make VERSION=42 build         # Build for Fedora 42
make PLATFORM=linux/arm64 build  # Build for ARM64
make SET_AS_LATEST=1 build    # Also tag as :latest
make push                     # Push to registry
make manifest                 # Create multi-arch manifest
```

### VM Testing

```bash
make lima                     # Generate Lima VM config
make qcow2                    # Generate qcow2 image
```

### ISO Generation

```bash
make iso-config               # Interactive: configure users/SSH keys
make iso                      # Default: bootc-image-builder ISO
make CLASSIC_ISO=1 iso        # Classic: build-container-installer ISO
make TRUEBLUE=1 iso-config    # Configure for variant
make TRUEBLUE=1 iso           # Variant build with bootc-image-builder
make run_iso                  # Test ISO in QEMU
make push_iso                 # Upload ISO to S3
```

The default `make iso` uses `bootc-image-builder` (same tooling as qcow2), producing an install-to-disk ISO. Use `CLASSIC_ISO=1` for the legacy `build-container-installer` approach which supports flatpak bundling and more Anaconda customization.

**Important**: Run `make iso-config` before `make iso` to configure user accounts. Without it, no users are created in the ISO.

Output: `./iso/immutablue-<tag>.iso`
Config: `./iso/config-<tag>.toml`

## Directory Structure

```
immutablue/
├── Containerfile             # Main container build file
├── Makefile                  # Build system (25K+ lines)
├── settings.yaml             # Runtime configuration defaults
├── packages.yaml             # Package definitions by variant/arch
├── artifacts/
│   ├── overrides/            # Files copied to image root
│   ├── overrides_cyan/       # NVIDIA-specific overrides
│   ├── overrides_asahi/      # Apple Silicon overrides
│   ├── overrides_kuberblue/  # Kubernetes overrides
│   ├── overrides_trueblue/   # ZFS overrides
│   └── overrides_nix/        # Nix overrides
├── build/                    # Build scripts (run in order)
│   ├── 00-pre.sh
│   ├── 10-copy.sh
│   ├── 20-add-repos.sh
│   ├── 30-install-packages.sh
│   ├── 40-uninstall-packages.sh
│   ├── 50-remove-files.sh
│   ├── 60-services.sh
│   ├── 90-post.sh
│   └── 99-common.sh          # Shared functions (sourced)
├── scripts/
│   ├── common.sh             # Shared script utilities
│   ├── packages.sh           # Package list generation
│   ├── immutablue-lima-gen   # Lima config generator
│   └── immutablue-qcow2-gen  # qcow2 image generator
├── tests/                    # Test suite
├── docs/                     # Hugo documentation site
└── specs/                    # RPM spec files
```

## Configuration Files

### settings.yaml

Runtime configuration with hierarchical override system:
1. `~/.config/immutablue/settings.yaml` (user, highest priority)
2. `/etc/immutablue/settings.yaml` (system)
3. `/usr/immutablue/settings.yaml` (defaults)

Key sections:
- `.immutablue.gen.*` - VM generator output paths
- `.immutablue.run_*` - Update behavior flags
- `.immutablue.header.*` - Network/terminal detection settings
- `.immutablue.profile.*` - Shell profile settings (starship, ulimit, completions)
- `.services.syncthing.*` - Syncthing configuration
- `.kuberblue.*` - Kubernetes variant settings

### packages.yaml

Package definitions organized by:
- `immutablue.rpm.all` - Packages for all variants
- `immutablue.rpm.gui` - GUI-specific packages
- `immutablue.rpm.silverblue` - GNOME-specific packages
- `immutablue.rpm_x86_64` / `rpm_aarch64` - Architecture-specific
- Variant-specific sections (cyan, asahi, kuberblue, trueblue)

## Key Scripts & Tools

### Build-time (in build/)
Scripts run in alphanumeric order during container build. Always source `99-common.sh` for helpers.

### Runtime (installed to image)

| Command | Location | Purpose |
|---------|----------|---------|
| `immutablue` | `/usr/bin/` | Main justfile wrapper |
| `immutablue-settings` | `/usr/bin/` | Query settings.yaml values |
| `immutablue-update` | `/usr/bin/` | Update all components |
| `immutablue-doctor` | `/usr/libexec/immutablue/` | System health checks |
| `immutablue-script-orchestrator` | `/usr/bin/` | Scheduled script runner |
| `immutablue-libvirt-manager` | `/usr/bin/` | VM management |
| `immutablue-header.sh` | `/usr/libexec/immutablue/` | Bash utility library |

### Justfiles

Located in `/usr/libexec/immutablue/just/`:
- `00-base.justfile` - Core commands (install, update, doctor, etc.)
- `05-hardware-overrides.justfile` - Hardware-specific commands
- Variant-specific justfiles added during build

## Testing

```bash
./tests/run_tests.sh              # Run all tests
./tests/test_shellcheck.sh        # Validate shell scripts
./tests/test_shellcheck.sh --fix  # Show detailed diagnostics
./tests/test_container.sh         # Container validation
./tests/test_artifacts.sh         # Artifact validation
```

### Kuberblue Testing

```bash
make test_kuberblue               # Full Kuberblue test suite
make test_kuberblue_container     # Container validation
make test_kuberblue_components    # Component tests
make test_kuberblue_security      # Security tests
make test_kuberblue_chainsaw      # Declarative Chainsaw tests
```

Chainsaw tests use `*_test.yaml` files co-located with manifests.

## Documentation

Hugo-based docs in `docs/`:

```bash
cd docs && hugo server             # Local preview at :1313
cd docs && hugo build              # Build static site
```

Structure:
- `getting-started/` - Installation, first-boot, quick-start
- `user-guide/` - Package management, updating, maintenance
- `cli-reference/` - All immutablue-* commands
- `system-components/` - Scheduled scripts, systemd, header library
- `variants/` - Variant-specific documentation
- `building/` - Architecture, customization, testing

## Code Style

### Shell Scripts

- Shebang: `#!/bin/bash`
- Error handling: `set -euo pipefail` (or `set -euxo pipefail` for build scripts)
- Shellcheck: Strict settings per `.shellcheckrc`
- Variables: Use `local` in functions, quote expansions
- Booleans: Use `TRUE="true"` / `FALSE="false"` constants from header
- Comments: Document functions and complex logic

### Build Script Template

```bash
#!/bin/bash
set -euxo pipefail
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then
    source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"
fi
if [ -f "./99-common.sh" ]; then
    source "./99-common.sh"
fi

# Your build logic here
```

### Settings Access Pattern

```bash
# In scripts that use immutablue-settings
value="$(immutablue-settings .some.setting.path 2>/dev/null)"
if [[ -z "${value}" ]] || [[ "${value}" == "null" ]]; then
    value="default_value"
fi
```

## Common Tasks

### Adding a Package

1. Edit `packages.yaml`
2. Add to appropriate section (`rpm.all`, `rpm.gui`, variant-specific, etc.)
3. Rebuild: `make build`

### Adding an Override File

1. Place file in `artifacts/overrides/` mirroring target path
2. Example: `artifacts/overrides/etc/myconfig.conf` → `/etc/myconfig.conf`
3. Variant-specific: use `artifacts/overrides_<variant>/`

### Adding a Setting

1. Add to `settings.yaml` with default value and comment
2. Update scripts to read with `immutablue-settings`
3. Document in `docs/content/user-guide/settings.md`

### Creating a Custom Variant

1. Fork [immutablue-custom](https://gitlab.com/immutablue/immutablue-custom)
2. Add packages to `packages/`
3. Add overrides to `artifacts/overrides/`
4. Customize `build/` scripts as needed
5. Build with `make build`
