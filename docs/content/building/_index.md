+++
title = 'Building & Customizing'
weight = 6
+++

# Building & Customizing Immutablue

This section covers the architecture of Immutablue and how to create custom builds.

## Topics

- [Architecture](architecture/) - System architecture and design principles
- [Build Reference](build-reference/) - Build system technical reference
- [ISO Generation](iso-generation/) - Generate bootable ISO images
- [Customization Guide](customization/) - Create your own Immutablue variant
- [Build Scripts](build-scripts/) - Understanding the build script structure
- [Testing](testing/) - Testing framework and validation
- [DevContainers](devcontainers/) - Development container setup

## Quick Start: Custom Build

1. Fork [immutablue-custom](https://gitlab.com/immutablue/immutablue-custom)
2. Modify `packages/` to add your packages
3. Add files to `artifacts/overrides/`
4. Run `make build`

See [Customization Guide](customization/) for full details.

## Build System Overview

Immutablue uses a layered build system:

```
Containerfile
    ├── Base image (Fedora Silverblue)
    ├── Immutablue layer
    │   ├── packages/*.txt (RPM packages)
    │   ├── artifacts/overrides/ (file overlays)
    │   └── build/*.sh (build scripts)
    └── Custom layer (your additions)
```

## Key Concepts

- **Immutability**: Base system is read-only
- **Layering**: Each variant builds on previous layers
- **Overrides**: Files in `artifacts/overrides/` are copied to the image
- **Build scripts**: `build/*.sh` run during image creation
