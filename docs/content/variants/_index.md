+++
title = 'Variants'
weight = 5
+++

# Immutablue Variants

Immutablue offers several specialized variants to support different hardware configurations and use cases.

## Available Variants

| Variant | Description | Use Case |
|---------|-------------|----------|
| [Immutablue](overview/) | Base GNOME Silverblue variant | General desktop use |
| [Cyan (NVIDIA)](nvidia-cyan/) | NVIDIA GPU support | Systems with NVIDIA graphics |
| [Asahi (Apple Silicon)](apple-silicon-asahi/) | Apple M1/M2/M3 support | Apple Silicon Macs |
| [Kuberblue](kuberblue/) | Kubernetes-ready variant | Container orchestration |
| [TrueBlue (ZFS)](trueblue-zfs/) | ZFS filesystem support | Advanced storage needs |
| [LTS Kernel](lts/) | Long-Term Support kernel | Maximum stability |
| [Nix](nix/) | Nix package manager integration | Nix ecosystem users |

## Variant Inheritance

All variants inherit from the base Immutablue image:

```
Fedora Silverblue
    └── Immutablue (base)
            ├── Cyan (NVIDIA)
            ├── Asahi (Apple Silicon)
            ├── Kuberblue
            ├── TrueBlue (ZFS + LTS)
            ├── LTS Kernel
            └── Nix
```

## Choosing a Variant

- **NVIDIA GPU?** → Use Cyan
- **Apple Silicon Mac?** → Use Asahi
- **Running Kubernetes?** → Use Kuberblue
- **Need ZFS?** → Use TrueBlue
- **Want maximum stability?** → Use LTS
- **Want Nix packages?** → Use Nix variant
- **None of the above?** → Use base Immutablue

## Custom Variants

You can create your own variant! See [Build Customization](/building/customization/) for details.
