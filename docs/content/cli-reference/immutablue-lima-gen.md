+++
title = 'immutablue-lima-gen'
weight = 7
+++

# immutablue-lima-gen

Generate Lima VM configuration files for Immutablue images.

## Synopsis

```bash
immutablue-lima-gen [OPTIONS]
```

## Description

`immutablue-lima-gen` creates Lima configuration files for testing Immutablue images locally in VMs. It detects available images and generates appropriate Lima YAML configs.

## Options

| Option | Description |
|--------|-------------|
| `--output-dir <PATH>` | Output directory (default: from settings) |
| `--variant <NAME>` | Generate config for specific variant |
| `--list` | List available variants |
| `--help`, `-h` | Show help message |

## Default Output Directory

The default output directory is configured via settings:

```yaml
# settings.yaml
immutablue:
  gen:
    lima:
      path: "~/.local/share/immutablue/lima"
```

## Examples

### Generate configs for all variants

```bash
immutablue-lima-gen
```

### Generate config for specific variant

```bash
immutablue-lima-gen --variant immutablue
```

### List available variants

```bash
immutablue-lima-gen --list
```

### Custom output directory

```bash
immutablue-lima-gen --output-dir ~/my-lima-configs
```

## Using Generated Configs

After generating configs:

```bash
# Start the VM
limactl start ~/.local/share/immutablue/lima/immutablue.yaml

# Shell into the VM
limactl shell immutablue

# Stop the VM
limactl stop immutablue

# Delete the VM
limactl delete immutablue
```

## Requirements

- Lima must be installed (`brew install lima`)
- QEMU for virtualization

## See Also

- [Lima VM Testing](/advanced/lima-testing/)
- [immutablue-qcow2-gen](immutablue-qcow2-gen/)
- [Settings Reference](/user-guide/settings/)
