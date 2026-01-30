+++
title = 'LTS Kernel'
weight = 7
+++

# LTS Kernel Variant

The LTS variant of Immutablue uses a Long-Term Support kernel instead of the standard Fedora kernel.

## Overview

The LTS variant includes:

- Linux 6.12 LTS kernel (instead of Fedora's rolling kernel)
- Extended support lifecycle
- More conservative updates
- Automatically includes ZFS support

## When to Use LTS

**Choose LTS if:**

- You need maximum stability
- You have hardware that works better with older kernels
- You're running production workloads
- You want predictable kernel behavior over time

**Choose standard kernel if:**

- You need the latest hardware support
- You want the newest kernel features
- You're running newer hardware that requires recent drivers

## Installation

### Fresh Install

```bash
sudo bootc switch ghcr.io/immutablue/immutablue:latest-lts
sudo reboot
```

### From Existing Immutablue

```bash
# Switch to LTS variant
sudo bootc switch ghcr.io/immutablue/immutablue:43-lts
sudo reboot
```

## Image Tags

LTS images follow the naming convention `<version>-lts`:

| Tag | Description |
|-----|-------------|
| `43-lts` | Fedora 43 with LTS kernel |
| `42-lts` | Fedora 42 with LTS kernel |
| `latest-lts` | Latest stable with LTS kernel |

### Combined Variants

LTS can be combined with other variants:

| Tag | Description |
|-----|-------------|
| `43-cyan-lts` | NVIDIA + LTS kernel |
| `43-nucleus-lts` | Minimal + LTS kernel |
| `43-trueblue` | ZFS + LTS (LTS implied with TrueBlue) |

## ZFS Included

The LTS variant automatically includes ZFS support. This is because:

1. ZFS modules need to be compiled against a specific kernel
2. LTS kernels have stable ABIs, making ZFS more reliable
3. TrueBlue variant always uses LTS for this reason

## Kernel Version

Check your current kernel:

```bash
uname -r
```

LTS kernel will show something like `6.12.x-xxx` instead of Fedora's `6.x.x-xxx.fc43`.

## Updating

Updates work the same as standard Immutablue:

```bash
immutablue update
```

The LTS kernel receives:
- Security patches
- Bug fixes
- Stable backports

But NOT:
- New features
- Major version bumps (until next LTS release)

## Building Custom LTS Images

To build your own LTS variant:

```bash
make LTS=1 build
```

Or in your custom Makefile:

```makefile
include immutablue/Makefile

# Force LTS for your build
LTS := 1
```

## Comparing Kernels

| Aspect | Standard Kernel | LTS Kernel |
|--------|-----------------|------------|
| Updates | Frequent | Conservative |
| Features | Latest | Stable subset |
| Hardware | Newest support | Proven support |
| Lifecycle | ~6 months | ~2-6 years |
| ZFS | Optional | Included |

## Troubleshooting

### Hardware not working on LTS

Some newer hardware may require the standard kernel:

```bash
# Switch back to standard
sudo bootc switch ghcr.io/immutablue/immutablue:43
sudo reboot
```

### Checking available kernels

```bash
rpm-ostree status
```

## See Also

- [Immutablue Variants](/variants/)
- [TrueBlue (ZFS)](/variants/trueblue-zfs/) - Always uses LTS
- [Build Reference](/building/build-reference/)
