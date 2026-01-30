+++
title = 'TrueBlue (ZFS)'
weight = 5
+++

# TrueBlue (ZFS)

TrueBlue is the ZFS-enabled variant of Immutablue, providing advanced storage features.

## Overview

TrueBlue includes:

- ZFS kernel modules
- ZFS userspace tools (zpool, zfs)
- Automatic ARC memory tuning
- Key loading services for encrypted pools

## Installation

```bash
sudo bootc switch ghcr.io/immutablue/trueblue:latest
sudo reboot
```

## ZFS Features

TrueBlue enables all standard ZFS features:

- **Copy-on-write** - Data integrity and snapshots
- **Compression** - Transparent data compression
- **Deduplication** - Block-level deduplication
- **Encryption** - Native ZFS encryption
- **Snapshots** - Instant, space-efficient snapshots
- **RAID-Z** - Software RAID with various parity levels

## Basic Usage

### Create a Pool

```bash
# Simple pool (single disk)
sudo zpool create mypool /dev/sdb

# Mirror (RAID1)
sudo zpool create mypool mirror /dev/sdb /dev/sdc

# RAID-Z1 (single parity)
sudo zpool create mypool raidz /dev/sdb /dev/sdc /dev/sdd
```

### Create Datasets

```bash
# Create a dataset
sudo zfs create mypool/data

# With compression
sudo zfs create -o compression=zstd mypool/compressed

# With encryption
sudo zfs create -o encryption=aes-256-gcm -o keyformat=passphrase mypool/encrypted
```

### Snapshots

```bash
# Create snapshot
sudo zfs snapshot mypool/data@backup-2024-01-15

# List snapshots
zfs list -t snapshot

# Rollback
sudo zfs rollback mypool/data@backup-2024-01-15
```

## Systemd Services

| Service | Description |
|---------|-------------|
| `zfs-arc-max.service` | Tunes ARC memory limits |
| `zfs-load-keys.service` | Loads encryption keys at boot |

### ARC Memory Tuning

The `zfs-arc-max.service` automatically sets the ARC (Adaptive Replacement Cache) maximum based on system memory:

```bash
# Check current ARC max
cat /sys/module/zfs/parameters/zfs_arc_max

# Manual override (in bytes)
echo 8589934592 | sudo tee /sys/module/zfs/parameters/zfs_arc_max
```

### Encrypted Pools

For encrypted datasets, the `zfs-load-keys.service` can load keys at boot:

1. Store key in `/etc/zfs/keys/`
2. Service loads keys automatically

Or load manually:
```bash
sudo zfs load-key mypool/encrypted
sudo zfs mount mypool/encrypted
```

## Importing Pools

### At Boot

Pools are imported automatically if they were previously imported.

### Manual Import

```bash
# Scan for pools
sudo zpool import

# Import specific pool
sudo zpool import mypool

# Import with different name
sudo zpool import oldname newname
```

## Best Practices

### Memory

ZFS uses RAM for caching (ARC). Recommended:
- Minimum: 8GB RAM
- Recommended: 16GB+ for large pools

### ECC Memory

While not required, ECC RAM is recommended for data integrity.

### Scrubbing

Regular scrubs detect and repair data corruption:

```bash
# Start scrub
sudo zpool scrub mypool

# Check scrub status
zpool status mypool

# Schedule weekly scrub (add to cron/timer)
```

### Snapshots Strategy

```bash
# Automated snapshots with sanoid/syncoid
# Or create a scheduled script:
# /etc/immutablue/scripts/system/daily/10-zfs-snapshot.sh

#!/bin/bash
zfs snapshot -r mypool@auto-$(date +%Y-%m-%d)
# Keep only last 7 daily snapshots
zfs list -t snapshot -o name | grep "auto-" | head -n -7 | xargs -r zfs destroy
```

## Troubleshooting

### Pool won't import

```bash
# Force import (use carefully)
sudo zpool import -f mypool

# Import with recovery
sudo zpool import -F mypool
```

### Check pool health

```bash
zpool status mypool
zpool list
```

### Repair degraded pool

```bash
# Replace failed disk
sudo zpool replace mypool /dev/sdb /dev/sdd

# Clear errors after replacement
sudo zpool clear mypool
```

## Combining with Kuberblue

TrueBlue can provide ZFS-backed storage for Kubernetes:

1. Install TrueBlue + Kuberblue features
2. Create ZFS datasets for persistent volumes
3. Use local-path-provisioner or ZFS CSI driver

## See Also

- [Immutablue Variants](/variants/)
- [Kuberblue](/variants/kuberblue/) - Kubernetes variant
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
