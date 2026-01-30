+++
title = 'immutablue-qcow2-gen'
weight = 8
+++

# immutablue-qcow2-gen

Generate qcow2 disk images from Immutablue container images.

## Synopsis

```bash
immutablue-qcow2-gen [OPTIONS]
```

## Description

`immutablue-qcow2-gen` converts Immutablue container images to qcow2 disk images suitable for use with QEMU, libvirt, or Lima VMs.

## Options

| Option | Description |
|--------|-------------|
| `--output-dir <PATH>` | Output directory (default: from settings) |
| `--variant <NAME>` | Generate image for specific variant |
| `--list` | List available variants |
| `--help`, `-h` | Show help message |

## Default Output Directory

The default output directory is configured via settings:

```yaml
# settings.yaml
immutablue:
  gen:
    qcow2:
      path: "~/.local/share/immutablue/images"
```

## Examples

### Generate image for default variant

```bash
immutablue-qcow2-gen
```

### Generate image for specific variant

```bash
immutablue-qcow2-gen --variant cyan
```

### List available variants

```bash
immutablue-qcow2-gen --list
```

### Custom output directory

```bash
immutablue-qcow2-gen --output-dir ~/vm-images
```

## Using Generated Images

### With QEMU directly

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -drive file=~/.local/share/immutablue/images/immutablue.qcow2,format=qcow2
```

### With virt-manager

1. Open virt-manager
2. Create new VM → Import existing disk image
3. Select the generated qcow2 file
4. Configure CPU/memory as needed

### With Lima

Use `immutablue-lima-gen` instead for Lima-specific configs that reference qcow2 images.

## Requirements

- Podman or Docker
- Sufficient disk space for images (~10GB per variant)

## See Also

- [immutablue-lima-gen](immutablue-lima-gen/)
- [Lima VM Testing](/advanced/lima-testing/)
- [Settings Reference](/user-guide/settings/)
