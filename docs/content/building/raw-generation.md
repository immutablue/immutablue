+++
date = '2026-01-31T23:30:00-05:00'
draft = false
title = 'Raw Image Generation'
weight = 26
+++

# Raw Image Generation

Immutablue can generate raw disk images using `bootc-image-builder`. Raw images are compressed with zstd for efficient storage and transfer, suitable for:

- Direct writing to USB drives with `dd` (after extraction)
- Cloud provider uploads (AWS, GCP, Azure)
- Bare metal deployments
- Custom virtualization setups

## Quick Start

```bash
# Build the image first
make build
make push

# Configure raw image (optional - adds user account and SSH keys)
make raw-config

# Generate raw image
make raw

# Generate raw for a specific variant
make TRUEBLUE=1 raw-config
make TRUEBLUE=1 raw
```

## Raw Image Configuration

Before building a raw image, you can optionally configure user accounts and SSH keys using `make raw-config`. This creates an interactive wizard that generates a configuration file.

### Usage

```bash
# Configure for default build
make raw-config

# Configure for a specific variant
make TRUEBLUE=1 raw-config
make KINOITE=1 raw-config
```

### What It Configures

The wizard prompts for:

1. **Username**: The account name (default: `immutablue`)
2. **Password**: Required if adding a user
3. **Wheel group**: Whether to add sudo access (default: yes)
4. **SSH public key**: Optional path to an SSH public key for passwordless login

### Configuration Files

Configuration files are stored per-variant:
- Default: `./raw/config-43.toml`
- Trueblue: `./raw/config-43-trueblue.toml`
- Kinoite: `./raw/config-43-kinoite.toml`

### Building Without Configuration

If you run `make raw` without first running `make raw-config`, a minimal configuration is created with no users. This means:

- You'll need console access to log in
- First-boot setup may be available depending on the variant
- Useful for automated deployments where users are configured via cloud-init or similar

## Building Raw Images

### Basic Usage

```bash
# Basic raw image generation
make raw

# With variant flags
make KINOITE=1 raw
make NUCLEUS=1 LTS=1 raw
```

### Output

All raw images are created as zstd-compressed `.img` files:
```
./raw/immutablue-<tag>.img.zst
```

Examples:
- `make raw` → `./raw/immutablue-43.img.zst`
- `make TRUEBLUE=1 raw` → `./raw/immutablue-43-trueblue.img.zst`
- `make KINOITE=1 LTS=1 raw` → `./raw/immutablue-43-kinoite-lts.img.zst`

### How It Works

1. Checks for existing configuration (`./raw/config-<tag>.toml`)
2. If no config exists, creates a minimal one (no users configured)
3. Pulls the target image from the registry
4. Runs `bootc-image-builder` with `--type raw`
5. Compresses the image with `zstd -T4 -5` (multi-threaded, balanced compression)
6. Outputs to `./raw/immutablue-<tag>.img.zst`

### Extracting the Image

To decompress the raw image:

```bash
# Decompress to current directory
zstd -d ./raw/immutablue-43.img.zst -o immutablue-43.img

# Decompress to specific location
zstd -d ./raw/immutablue-43.img.zst -o /path/to/immutablue-43.img
```

This produces `immutablue-43.img` which can be written to disk.

## Testing Raw Images

Test the raw image with QEMU:

```bash
make run_raw

# For variant builds
make TRUEBLUE=1 run_raw
```

This boots the raw image in a QEMU VM with:
- 8 CPU cores
- 8GB RAM
- 64GB disk
- UEFI boot mode
- Web console at http://localhost:8006

## Pushing Raw Images

Upload the raw image to S3 storage:

```bash
make push_raw

# For variant builds
make TRUEBLUE=1 push_raw
```

Requires `S3_ACCESS_KEY` and `S3_SECRET_KEY` environment variables.

## Writing to USB Drive

Decompress and write the raw image to a USB drive:

```bash
# Decompress the image
zstd -d ./raw/immutablue-43.img.zst -o immutablue-43.img

# Find your USB device (be VERY careful to select the right one!)
lsblk

# Write the image (replace /dev/sdX with your USB device)
sudo dd if=immutablue-43.img of=/dev/sdX bs=4M status=progress conv=fsync

# Sync and eject
sync
sudo eject /dev/sdX

# Clean up extracted image (optional)
rm immutablue-43.img
```

Alternatively, decompress and write in one step using `zstdcat`:

```bash
zstdcat ./raw/immutablue-43.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

{{< hint warning >}}
**Warning:** `dd` will overwrite the target device without confirmation. Double-check you have the correct device before running the command!
{{< /hint >}}

## Cloud Provider Usage

### AWS

Decompress and upload to AWS:

```bash
# Decompress the image
zstd -d ./raw/immutablue-43.img.zst -o immutablue-43.img

# Upload to S3 and import as AMI using AWS CLI
aws s3 cp immutablue-43.img s3://your-bucket/
aws ec2 import-image --disk-containers "file://containers.json"
```

### GCP

```bash
# Decompress and recompress for GCP (requires gzip format)
zstd -d ./raw/immutablue-43.img.zst -o immutablue-43.img
gzip -c immutablue-43.img > immutablue-43.raw.gz
gsutil cp immutablue-43.raw.gz gs://your-bucket/

# Create image from the uploaded file
gcloud compute images create immutablue-43 \
  --source-uri=gs://your-bucket/immutablue-43.raw.gz
```

{{< hint info >}}
For cloud deployments, consider using the dedicated cloud image formats instead: `make ami` for AWS, `make gce` for Google Cloud. See [Cloud Images](../cloud-images/) for details.
{{< /hint >}}

## Complete Workflow Example

```bash
# 1. Build and push the image
make TRUEBLUE=1 build
make TRUEBLUE=1 push

# 2. Configure raw image users (interactive)
make TRUEBLUE=1 raw-config

# 3. Build the raw image
make TRUEBLUE=1 raw

# 4. Test the raw image
make TRUEBLUE=1 run_raw

# 5. Push to S3
make TRUEBLUE=1 push_raw
```

## Comparison with Other Formats

| Feature | Raw | ISO | qcow2 |
|---------|-----|-----|-------|
| Use case | USB/Cloud/Bare metal | Installation media | VMs |
| Compression | zstd (tar.zst) | Squashfs | qcow2 native |
| Direct boot | Yes (after extract) | Yes (installer) | Yes |
| Write to USB | Yes (`dd` after extract) | Yes (`dd`) | No |
| Cloud upload | Yes | No | Some providers |
| File size | Small (compressed) | Medium | Smallest |

## Troubleshooting

### Raw build fails with permission errors

Ensure you have sudo access and the container runtime has necessary privileges:

```bash
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest
```

### Raw image doesn't boot

Verify the image was pushed to the registry before building:

```bash
make build
make push
make raw
```

### "No raw image found" when running or pushing

Make sure you've built the raw image first:

```bash
make raw
make run_raw
```

### USB boot fails

1. Verify the write completed successfully:
   ```bash
   sync
   ```

2. Check UEFI boot mode is enabled in BIOS/firmware

3. Ensure Secure Boot is either disabled or the image supports it
