+++
date = '2025-04-18T17:45:00-05:00'
draft = false
title = 'Build Reference'
+++

# Immutablue Build Reference

This page provides technical reference information about the build system, build options, and the package configuration mechanism. For a more comprehensive guide on customizing builds, see the [Build Customization](/pages/build-customization) page.

## Basic Build Command

The simplest way to build Immutablue is:
```bash
make build
```

This will build the default variant (GNOME desktop/Silverblue) for the current architecture.

## Reading Build Options

### During Build Time

During build time, you can evaluate the build options through the environment variable `${IMMUTABLUE_BUILD_OPTIONS}`.

### At Runtime

During build, the configured build options are written to a file at `/usr/immutablue/build_options` so they can be known at runtime. To access build options at runtime, simply read this file.

## Build Helper Functions

Immutablue provides helper functions in `/usr/immutablue/build/99-common.sh` to work with build options:

- `get_immutablue_build_options`: Returns an array of build options that can be easily consumed in a while loop without having to modify the `IFS`.

- `is_option_in_build_options`: Checks if a specific build option exists in the current build. This can be used for conditional build-time configurations (as is done for the Cyan variant to include NVIDIA support).

## packages.yaml Configuration

The `packages.yaml` file supports a flexible configuration system with version, architecture, and build option specific variants.

### Key Format

The general format for keys in `packages.yaml` is:
```
<key>[_<build_option>][_<architecture>]
```

Where:
- `<key>` is the base key (e.g., `rpm`, `rpm_url`)
- `<build_option>` is an optional build option (e.g., `silverblue`, `kinoite`, `cyan`)
- `<architecture>` is an optional architecture specifier (e.g., `x86_64`, `aarch64`)

### Version-Specific Configuration

Starting with Immutablue, packages can be configured per Fedora version. Each package section supports:

- `all`: Packages that apply to all versions
- `<version>`: Packages specific to a Fedora version (e.g., `42`, `43`)

The lookup priority is:
1. Version + build option + architecture specific
2. Version + build option specific
3. Version + architecture specific
4. Version specific
5. Build option + architecture specific
6. Build option specific
7. Architecture specific
8. All versions

### Examples

```yaml
immutablue:
  # Version-specific configurations
  lts_version:
    41: "6.6"
    42: "6.12"
    43: "6.12"

  # Package configurations with version support
  rpm:
    all:                 # Base packages for all variants and architectures
    - bashmount
    - git
    43:                  # Additional packages only for Fedora 43
    - new-package-for-f43

  rpm_aarch64:
    all:                 # Packages only for ARM architecture
    - package-for-arm

  rpm_silverblue:
    all:                 # Packages only for GNOME/Silverblue variants
    - gnome-tweaks

  rpm_kinoite_x86_64:
    all:                 # Packages only for KDE/Kinoite variants on x86_64
    - kate

  # Repository URLs with version support
  repo_urls:
    all:
    - name: tailscale.repo
      url: https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    43:
    - name: fedora-43-specific.repo
      url: https://example.com/f43-repo.repo
```

The architecture is determined at build time using `$(uname -m)`, and the version is determined by the `VERSION` build argument or defaults to `FEDORA_VERSION`.

For a full guide on customizing your build, including how to add packages, repositories, and file overrides, see the [Build Customization](/pages/build-customization) page.

