+++
date = '2025-04-18T18:15:00-05:00'
draft = false
title = 'NVIDIA Support'
+++

# NVIDIA Support on Immutablue

Immutablue provides NVIDIA support through the "Cyan" variant. For general information about the Cyan variant, see the [Immutablue Variants](immutablue-variants.md#immutablue-cyan) page.

## Installation

To install Immutablue with NVIDIA support, you need to:

1. Rebase to the Cyan variant:
   ```bash
   sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue-cyan:42
   ```

2. Reboot your system:
   ```bash
   sudo systemctl reboot
   ```

3. Activate the NVIDIA kernel module:
   ```bash
   immutablue enable_nvidia_kmod
   ```

4. Reboot again to load the kernel module:
   ```bash
   sudo systemctl reboot
   ```

## Verification

You can verify that the NVIDIA kernel module is loaded correctly by running:

```bash
lsmod | grep -i nvidia
```

You should see several NVIDIA-related modules listed in the output.

## Troubleshooting

If you experience issues with NVIDIA support:

1. Check if the NVIDIA kernel module is loaded:
   ```bash
   lsmod | grep -i nvidia
   ```

2. Check the NVIDIA driver status:
   ```bash
   nvidia-smi
   ```

3. If the module isn't loading, check the DKMS status:
   ```bash
   dkms status
   ```

4. Try rebuilding the kernel module:
   ```bash
   sudo dkms autoinstall
   ```

See the [Maintenance and Troubleshooting](maintenance-and-troubleshooting.md#nvidia-specific-issues) page for more detailed guidance on troubleshooting NVIDIA issues.

