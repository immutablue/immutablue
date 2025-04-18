+++
date = '2025-04-18T17:45:00-05:00'
draft = false
title = 'Build Reference'
+++

# Immutablue Build Reference

This page provides technical reference information about the build system, build options, and the package configuration mechanism. For a more comprehensive guide on customizing builds, see the [Build Customization](build-customization.md) page.

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

The `packages.yaml` file supports a flexible configuration system with architecture and build option specific variants.

### Key Format

The general format for keys in `packages.yaml` is:
```
<key>[_<build_option>][_<architecture>]
```

Where:
- `<key>` is the base key (e.g., `rpm`, `rpm_url`)
- `<build_option>` is an optional build option (e.g., `silverblue`, `kinoite`, `cyan`)
- `<architecture>` is an optional architecture specifier (e.g., `x86_64`, `aarch64`)

### Examples

```yaml
immutablue: 
  rpm:                 # Base packages for all variants and architectures
  rpm_aarch64:         # Packages only for ARM architecture
  rpm_silverblue:      # Packages only for GNOME/Silverblue variants
  rpm_kinoite_x86_64:  # Packages only for KDE/Kinoite variants on x86_64
```

The architecture is determined at build time using `$(uname -m)`.

For a full guide on customizing your build, including how to add packages, repositories, and file overrides, see the [Build Customization](build-customization.md) page.

