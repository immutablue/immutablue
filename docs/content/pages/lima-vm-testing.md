+++
date = '2026-01-28T23:58:00-05:00'
draft = false
title = 'Lima VM Testing'
+++

# Lima VM Testing

Immutablue supports local VM testing using [Lima](https://lima-vm.io/), a lightweight VM manager that provides a seamless experience for running Linux VMs with automatic SSH, port forwarding, and file mounts.

## Prerequisites

- Lima installed: `brew install lima`
- QEMU installed: `dnf install qemu-system-x86` (or via your package manager)
- A built and pushed Immutablue container image

## Quick Start

```bash
# Build qcow2 with Lima SSH key support
make LIMA=1 qcow2

# Generate Lima configuration
make lima

# Start the VM
make lima-start

# Shell into the VM
make lima-shell

# Stop the VM when done
make lima-stop
```

## Build Options

### Basic qcow2 Build

Build a qcow2 without Lima SSH keys (password auth only):

```bash
make qcow2
```

Default credentials: `immutablue` / `immutablue`

### Lima-enabled qcow2 Build

Build a qcow2 with SSH keys for Lima access:

```bash
make LIMA=1 qcow2
```

This automatically adds your SSH key to the image:
1. Lima key (`~/.lima/_config/user.pub`) - preferred
2. ED25519 key (`~/.ssh/id_ed25519.pub`) - fallback
3. RSA key (`~/.ssh/id_rsa.pub`) - fallback

### Building Variants

All build options work with Lima:

```bash
# Trueblue variant with Lima support
make TRUEBLUE=1 LIMA=1 qcow2

# Kinoite (KDE) with LTS kernel
make KINOITE=1 LTS=1 LIMA=1 qcow2

# Kuberblue variant
make KUBERBLUE=1 LIMA=1 qcow2
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make qcow2` | Build qcow2 image (add `LIMA=1` for SSH key support) |
| `make lima` | Generate Lima YAML configuration |
| `make lima-start` | Start the Lima VM |
| `make lima-shell` | Open a shell in the running VM |
| `make lima-stop` | Stop the Lima VM |
| `make lima-delete` | Delete the Lima VM instance |

## Lima Configuration

The `make lima` target generates a Lima YAML configuration at `.lima/immutablue-<TAG>.yaml` with:

- **VM Type**: QEMU with KVM acceleration
- **Resources**: 4 CPUs, 4GB RAM, 100GB disk
- **User**: `immutablue`
- **Mounts**: Home directory (read-only)
- **SSH**: Auto-assigned port with key-based auth
- **Mode**: Plain mode (skips Lima provisioning for pre-built images)

### Generated Configuration

```yaml
minimumLimaVersion: "2.0.0"
vmType: qemu
arch: x86_64

user:
  name: immutablue

images:
- location: "/path/to/images/qcow2/43/qcow2/disk.qcow2"
  arch: "x86_64"

cpus: 4
memory: "4GiB"
disk: "100GiB"

mounts:
- location: "~"
  writable: false

ssh:
  localPort: 0
  loadDotSSHPubKeys: true
  overVsock: false  # Required for Fedora 43 SELinux compatibility

containerd:
  system: false
  user: false

plain: true  # Skip Lima provisioning for pre-built images
```

## Alternative: Raw QEMU

If you prefer raw QEMU without Lima:

```bash
# Build qcow2
make qcow2

# Run with QEMU directly
make run_qcow2
```

This starts QEMU with:
- SSH on port 2222
- Serial console (exit with `Ctrl-A X`)
- KVM acceleration

SSH access: `ssh -p 2222 immutablue@localhost` (password: `immutablue`)

## Workflow Examples

### Testing a New Build

```bash
# Build and push the image
make build push

# Create qcow2 with Lima support
make LIMA=1 qcow2

# Start Lima VM
make lima lima-start

# Shell in and test
make lima-shell

# Inside VM: verify the build
rpm-ostree status
cat /etc/immutablue-release

# Exit and stop
exit
make lima-stop
```

### Testing Multiple Variants

```bash
# Test default Silverblue
make LIMA=1 qcow2 lima lima-start
make lima-shell
# ... test ...
make lima-stop
make lima-delete

# Test Trueblue
make TRUEBLUE=1 LIMA=1 qcow2 lima lima-start
make TRUEBLUE=1 lima-shell
# ... test ...
make TRUEBLUE=1 lima-stop
```

### Cleaning Up

```bash
# Delete specific VM
make lima-delete

# Or with variant
make TRUEBLUE=1 lima-delete

# Clean all generated files
make clean
```

## Troubleshooting

### SSH Connection Issues

If Lima hangs on "Waiting for ssh":

1. Ensure you built with `LIMA=1`:
   ```bash
   make LIMA=1 qcow2
   ```

2. Verify the SSH key was added:
   ```bash
   cat ./images/qcow2/43/config.toml | grep key
   ```

3. Delete and recreate the VM:
   ```bash
   make lima-delete
   make lima lima-start
   ```

### VM Won't Start

1. Check if KVM is available:
   ```bash
   ls /dev/kvm
   ```

2. Verify QEMU is installed:
   ```bash
   which qemu-system-x86_64
   ```

3. Check Lima logs:
   ```bash
   cat ~/.lima/immutablue-43/serial*.log
   ```

### User Session Issues

If Lima hangs on "user session is ready":

The `plain: true` setting should prevent this. If you still see it:

1. Regenerate the Lima config:
   ```bash
   make lima
   ```

2. Verify `plain: true` is in the YAML:
   ```bash
   grep plain .lima/immutablue-43.yaml
   ```

### File Permission Issues

After `make qcow2`, if files are owned by root:

```bash
sudo chown -R $(id -u):$(id -g) ./images/
```

This is normally handled automatically by the Makefile.

## Architecture Notes

### Why Plain Mode?

Immutablue qcow2 images are pre-built bootc images, not cloud images with cloud-init. Lima's normal provisioning workflow expects to inject SSH keys and set up the user environment via cloud-init, which doesn't apply to our images.

Setting `plain: true` tells Lima:
- Skip user session requirement checks
- Skip cloud-init provisioning
- Skip containerd setup
- Just boot the VM and provide SSH access

### SSH Key Injection

Since we can't use cloud-init, SSH keys are baked into the qcow2 at build time via the bootc-image-builder config. The `LIMA=1` flag triggers this:

1. Makefile generates a temporary `config.toml` with your SSH public key
2. bootc-image-builder creates the qcow2 with the `immutablue` user and your SSH key
3. Lima can then SSH in using your private key

### Image Location

qcow2 images are stored at:
```
./images/qcow2/<TAG>/qcow2/disk.qcow2
```

Lima configurations are stored at:
```
./.lima/immutablue-<TAG>.yaml
```

Both directories are gitignored as they contain machine-specific paths and large binary files.
