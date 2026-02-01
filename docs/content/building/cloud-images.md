+++
date = '2026-01-31T23:40:00-05:00'
draft = false
title = 'Cloud Images'
weight = 27
+++

# Cloud Images

Immutablue supports generating images for major cloud providers and virtualization platforms using `bootc-image-builder`. Each format has its own configuration and build target.

## Supported Formats

| Format | Target | Make Command |
|--------|--------|--------------|
| AMI | AWS EC2 | `make ami` |
| GCE | Google Compute Engine | `make gce` |
| VHD | Azure / Hyper-V | `make vhd` |
| VMDK | VMware vSphere | `make vmdk` |
| Anaconda ISO | Unattended installer | `make anaconda-iso` |

## Quick Start

```bash
# Build the container image first
make build
make push

# Generate cloud image (example: AWS AMI)
make ami-config    # Optional: configure users
make ami           # Build the image
```

## Configuration

Each image type has a corresponding `-config` target that runs an interactive wizard:

```bash
make ami-config
make gce-config
make vhd-config
make vmdk-config
make anaconda-iso-config
```

### What It Configures

The wizard prompts for:

1. **Username**: The account name (default: `immutablue`)
2. **Password**: Required if adding a user
3. **Wheel group**: Whether to add sudo access (default: yes)
4. **SSH public key**: Optional path to an SSH public key

### Configuration Files

Configuration files are stored per-variant in each format's directory:

```
./ami/config-43.toml
./ami/config-43-trueblue.toml
./gce/config-43-kinoite.toml
...
```

---

## AMI (Amazon Machine Image)

Generate images for AWS EC2.

### Build

```bash
# Configure (optional)
make ami-config

# Build
make ami

# For variants
make TRUEBLUE=1 ami
```

### Output

```
./ami/immutablue-<tag>.ami.raw
```

### Upload to AWS

```bash
# Push to S3 (Linode Object Storage)
make push_ami

# Or upload to AWS S3 and import as AMI
aws s3 cp ./ami/immutablue-43.ami.raw s3://your-bucket/

# Import as AMI
aws ec2 import-image \
  --disk-containers "Format=raw,UserBucket={S3Bucket=your-bucket,S3Key=immutablue-43.ami.raw}"
```

{{% notice note %}}
AWS import requires the [vmimport service role](https://docs.aws.amazon.com/vm-import/latest/userguide/required-permissions.html) configured on your account.
{{% /notice %}}

---

## GCE (Google Compute Engine)

Generate images for Google Cloud.

### Build

```bash
# Configure (optional)
make gce-config

# Build
make gce

# For variants
make TRUEBLUE=1 gce
```

### Output

```
./gce/immutablue-<tag>.gce.tar.gz
```

### Upload to Google Cloud

```bash
# Push to S3 (Linode Object Storage)
make push_gce

# Or upload to Google Cloud Storage
gsutil cp ./gce/immutablue-43.gce.tar.gz gs://your-bucket/

# Create image from the uploaded file
gcloud compute images create immutablue-43 \
  --source-uri=gs://your-bucket/immutablue-43.gce.tar.gz
```

---

## VHD (Virtual Hard Disk)

Generate images for Azure, Hyper-V, or Virtual PC.

### Build

```bash
# Configure (optional)
make vhd-config

# Build
make vhd

# For variants
make TRUEBLUE=1 vhd
```

### Output

```
./vhd/immutablue-<tag>.vhd
```

### Upload to Azure

```bash
# Push to S3 (Linode Object Storage)
make push_vhd

# Or upload to Azure Blob Storage
az storage blob upload \
  --account-name youraccount \
  --container-name vhds \
  --name immutablue-43.vhd \
  --file ./vhd/immutablue-43.vhd

# Create image from VHD
az image create \
  --resource-group myResourceGroup \
  --name immutablue-43 \
  --os-type Linux \
  --source https://youraccount.blob.core.windows.net/vhds/immutablue-43.vhd
```

### Use with Hyper-V

1. Copy the VHD file to your Hyper-V host
2. Create a new VM in Hyper-V Manager
3. Select "Use an existing virtual hard disk"
4. Browse to the VHD file

---

## VMDK (VMware Disk)

Generate images for VMware vSphere, Workstation, or Fusion.

### Build

```bash
# Configure (optional)
make vmdk-config

# Build
make vmdk

# For variants
make TRUEBLUE=1 vmdk
```

### Output

```
./vmdk/immutablue-<tag>.vmdk
```

### Upload to vSphere

```bash
# Push to S3 (Linode Object Storage)
make push_vmdk

# Or use govc to upload to vSphere
govc import.vmdk ./vmdk/immutablue-43.vmdk

# Or use the vSphere web client to upload manually
```

### Use with VMware Workstation/Fusion

1. Create a new VM
2. Select "Use an existing disk"
3. Browse to the VMDK file

---

## Anaconda ISO

Generate an unattended Anaconda installer ISO. Unlike the standard ISO (`make iso`), this creates an RPM-based installer that automatically installs to the first disk.

### Build

```bash
# Configure (optional)
make anaconda-iso-config

# Build
make anaconda-iso

# For variants
make TRUEBLUE=1 anaconda-iso
```

### Output

```
./anaconda-iso/immutablue-<tag>-anaconda.iso
```

### When to Use

Use `anaconda-iso` when you need:

- Fully automated, unattended installation
- Traditional Anaconda installer behavior
- RPM-based installation (vs bootc container deployment)

Use regular `make iso` for:

- Interactive installation with GNOME Initial Setup
- bootc-native container deployment
- More modern bootc workflow

---

## Comparison

| Feature | AMI | GCE | VHD | VMDK | Anaconda ISO |
|---------|-----|-----|-----|------|--------------|
| Target | AWS | Google Cloud | Azure/Hyper-V | VMware | Bare metal |
| Format | raw | tar.gz | vhd | vmdk | iso |
| Output dir | `./ami/` | `./gce/` | `./vhd/` | `./vmdk/` | `./anaconda-iso/` |
| Push target | `push_ami` | `push_gce` | `push_vhd` | `push_vmdk` | - |

## Complete Workflow Example

```bash
# 1. Build and push the container image
make TRUEBLUE=1 build
make TRUEBLUE=1 push

# 2. Generate all cloud images
make TRUEBLUE=1 ami-config
make TRUEBLUE=1 ami

make TRUEBLUE=1 gce-config  
make TRUEBLUE=1 gce

make TRUEBLUE=1 vhd-config
make TRUEBLUE=1 vhd

make TRUEBLUE=1 vmdk-config
make TRUEBLUE=1 vmdk

# 3. Push to storage
make TRUEBLUE=1 push_ami
make TRUEBLUE=1 push_gce
make TRUEBLUE=1 push_vhd
make TRUEBLUE=1 push_vmdk
```

## Troubleshooting

### Build fails with permission errors

Ensure you have sudo access and the container runtime has necessary privileges:

```bash
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest
```

### Image doesn't boot in cloud provider

1. Verify the image was pushed to the registry before building
2. Check cloud provider's specific requirements for custom images
3. Ensure UEFI boot mode is supported/configured

### "No image found" when pushing

Build the image first:

```bash
make ami       # Build first
make push_ami  # Then push
```
