+++
date = '2025-04-18T16:00:00-05:00'
draft = false
title = 'Immutablue Variants'
+++

# Immutablue Variants

Immutablue offers several specialized variants to support different hardware configurations and use cases. This document provides detailed information about each variant and when to use them.

## Core Variants

### Base Immutablue

The standard Immutablue image with GNOME desktop environment (Silverblue). This variant is suitable for general desktop use on standard x86_64 hardware with Intel/AMD graphics.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42
```

### Immutablue Cyan

The Immutablue Cyan variant includes preconfigured support for NVIDIA graphics cards, with appropriate drivers and configurations preinstalled.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue-cyan:42
```

Key features:
- NVIDIA driver integration
- CUDA support
- Properly configured kernel modules for NVIDIA GPUs
- Optimized desktop performance for NVIDIA graphics

### Immutablue Asahi

Optimized for Apple Silicon hardware (M1, M2, M3 series), this variant is based on the Fedora Asahi Remix project and brings Immutablue functionality to Apple's ARM-based Macs.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue-asahi:42
```

Key features:
- Support for Apple Silicon hardware
- Optimized drivers for Apple hardware components
- Power management optimizations
- Keyboard and touchpad support for Apple devices

### Immutablue Nucleus

A headless variant with no desktop environment, designed for server or minimal installations.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue-nucleus:42
```

Key features:
- No GUI components
- Minimal footprint
- Server-oriented tools and utilities
- Suitable for containers, VMs, or headless systems

## Desktop Environment Variants

Immutablue supports various desktop environments beyond the default GNOME desktop:

### Immutablue Kinoite

KDE Plasma desktop environment.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42-kinoite
```

### Immutablue Sericea

Sway window manager for a lightweight, tiling window manager experience.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42-sericea
```

### Immutablue Vauxite

XFCE desktop environment for a lightweight but full-featured desktop.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42-vauxite
```

### Immutablue Lazurite

LXQt desktop environment for very lightweight systems.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42-lazurite
```

### Immutablue Cosmic

COSMIC desktop environment from System76.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42-cosmic
```

### Immutablue Onyx

Budgie desktop environment for a modern, minimalist experience.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42-onyx
```

### Immutablue Bazzite

A variant optimized for the Steam Deck and gaming, based on the Bazzite project.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42-bazzite
```

## Specialized Variants

### Immutablue Kuberblue

Designed for Kubernetes development and operations, with Kubernetes tools preinstalled.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue-kuberblue:42
```

Key features:
- Kubernetes CLI tools
- Container development tools
- Network utilities for Kubernetes
- DevOps-focused configuration

### Immutablue TrueBlue

A NAS appliance variant with ZFS support, designed for storage servers.

```bash
# To install:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue-trueblue:42
```

Key features:
- ZFS filesystem support
- NAS management tools
- Storage optimization
- Data integrity features

### Immutablue with LTS Kernel

Any Immutablue variant can be built with an LTS (Long Term Support) kernel by adding `-lts` to the version tag.

```bash
# To install base Immutablue with LTS kernel:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:42-lts

# To install Immutablue Cyan with LTS kernel:
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue-cyan:42-lts
```

Key features:
- Long-term supported kernel for stability
- ZFS support included by default
- Extended maintenance period
- Better hardware compatibility for some systems

## Combining Variants

You can combine multiple variants by building a custom image that inherits from one of the specialized variants and adds additional features.

For example, to create a custom image based on Immutablue Cyan with the KDE desktop:

```bash
make CYAN=1 KINOITE=1 build
```

Or to create a custom image based on Immutablue Asahi with an LTS kernel:

```bash
make ASAHI=1 LTS=1 build
```

## Custom Variants Examples

The Immutablue project provides several examples of custom builds that you can use as inspiration:

### Hyacinth Macaw

A custom variant with specific developer tools and configurations.
- Repository: [gitlab.com/immutablue/hyacinth-macaw](https://gitlab.com/immutablue/hyacinth-macaw)

### Hawk Blueah

Another custom variant with multimedia focus.
- Repository: [gitlab.com/immutablue/hawk-blueah](https://gitlab.com/immutablue/hawk-blueah)

### Blue-Tuxonaut

A custom variant with space-related tools and themes.
- Repository: [gitlab.com/noahsibai/blue-tuxonaut](https://gitlab.com/noahsibai/blue-tuxonaut)

## When to Use Each Variant

- **Base Immutablue**: General desktop use with standard hardware
- **Immutablue Cyan**: Systems with NVIDIA graphics cards
- **Immutablue Asahi**: Apple Silicon Macs
- **Immutablue Nucleus**: Servers, VMs, or headless systems
- **Desktop Variants**: When you prefer a different desktop environment
- **Immutablue Kuberblue**: Kubernetes development or operations
- **Immutablue TrueBlue**: NAS or storage servers
- **LTS Kernel**: Systems that need stability or have hardware compatibility issues

## Creating Your Own Variant

To create your own variant of Immutablue, follow these steps:

1. Fork the `immutablue-custom` repository
2. Customize the `packages.yaml` file to include your preferred packages
3. Add any custom files to `artifacts/overrides/`
4. Build the image with your desired options using `make build`
5. Test and refine your custom image

See the [Build Customization](/pages/build-customization) documentation for more details on customizing your Immutablue variant.
