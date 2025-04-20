+++
date = '2025-04-18T18:30:00-05:00'
draft = false
title = 'Apple Silicon Support'
+++

# Apple Silicon Support

Immutablue provides support for Apple Silicon (M1, M2, M3 series) devices through the "Asahi" variant. For general information about the Asahi variant, see the [Immutablue Variants](/pages/immutablue-variants#immutablue-asahi) page.

Immutablue Asahi supports the same devices as [Asahi Linux](https://asahilinux.org/fedora/#device-support).

## Available Variants

The following Asahi variants are available:

- `quay.io/immutablue/immutablue:42-asahi` - GNOME desktop (Silverblue)
- `quay.io/immutablue/immutablue:42-kinoite-asahi` - KDE desktop (Kinoite)

## Building Custom Asahi Images

If you maintain a downstream image and want to add Apple Silicon support, use:

```bash
make ASAHI=1 build
```

This will produce an Asahi build of your Immutablue image with `-asahi` appended to the tag name.

**Important**: It is strongly recommended to build Asahi images on Apple Silicon hardware. Building from non-Apple ARM64 servers (like Hetzner ARM64 VPS) may cause issues with the resulting image.

## Installation

### Bootstrapping Process

Currently, you must bootstrap an Immutablue Asahi installation from an existing Fedora Asahi Remix installation. Direct ISO installation is not supported due to the requirements of the Linux 16K kernel and specific Apple hardware drivers.

1. **Install Asahi Linux from macOS**:
   ```bash
   curl https://alx.sh | sh
   ```
   Choose the Fedora Asahi Remix GNOME option during installation.

2. **After booting into Fedora Asahi Remix**:
   - Update the system and reboot:
     ```bash
     sudo dnf update -y && sudo reboot
     ```

3. **Prepare for Immutablue**:
   - Install required packages:
     ```bash
     sudo su -
     dnf -y install ostree ostree-grub2 rpm-ostree
     ```

   - Backup boot loader files:
     ```bash
     mv /boot/loader /boot/loader.pre_sb.bak
     mv /boot/grub2/grub.cfg /boot/grub2/grub.cfg.pre_sb.bak
     cp /boot/efi/EFI/fedora/grub.cfg /boot/efi/EFI/fedora/grub.cfg.pre_sb.bak
     ```

   - Initialize ostree:
     ```bash
     ostree admin init-fs /
     ostree remote add fedora https://ostree.fedoraproject.org --set=contenturl=mirrorlist=https://ostree.fedoraproject.org/mirrorlist --no-gpg-verify
     ostree --repo=/ostree/repo pull fedora:fedora/42/aarch64/silverblue
     ostree admin os-init fedora
     ostree admin deploy --os=fedora --karg-proc-cmdline fedora:fedora/42/aarch64/silverblue
     ```

   - Find the deployment ID:
     ```bash
     ls -l /ostree/deploy/fedora/deploy
     ```

   - Rebase to Immutablue Asahi:
     ```bash
     rpm-ostree rebase --os=fedora --sysroot=/ --experimental ostree-unverified-registry:quay.io/immutablue/immutablue:42-asahi
     ```

   - Copy essential configuration files (replace the checksum with your actual deployment ID):
     ```bash
     DEPLOY_ID=$(ls -1 /ostree/deploy/fedora/deploy/ | grep -v ^$(ls -1 /ostree/deploy/fedora/deploy/ | head -1)$ | head -1)
     for i in /etc/fstab /etc/default/grub /etc/locale.conf ; do cp "$i" /ostree/deploy/fedora/deploy/${DEPLOY_ID}/$i; done
     echo 'L /var/home - - - - ../sysroot/home' > /ostree/deploy/fedora/deploy/${DEPLOY_ID}/etc/tmpfiles.d/00rpm-ostree.conf
     ```

4. **Reboot**:
   ```bash
   systemctl reboot
   ```

### Recovery

If you need to reset and reinstall Asahi from macOS, validate your partitions first, then run:

```bash
diskutil apfs deleteContainer disk0s3
diskutil eraseVolume free free disk0s4
diskutil eraseVolume free free disk0s5
diskutil eraseVolume free free disk0s6
curl https://alx.sh | sh
```

**Warning**: Do not blindly copy and paste these commands. Make sure you understand what they do and that they apply to your system's partition layout.

## Post-Install Configuration

### Display Notch Support

By default, the notch area of the display is not used. 

To use the full display including the notch area:
```bash
immutablue asahi_enable_notch_render
sudo systemctl reboot
```

To disable full display rendering and hide the notch area:
```bash
immutablue asahi_disable_notch_render
sudo systemctl reboot
```

### Hardware Support

Immutablue Asahi includes support for:
- GPU acceleration
- Wi-Fi
- Bluetooth
- USB ports
- Display
- Keyboard and trackpad
- Speakers and microphone

Some features like the Touch Bar on MacBook Pro models may have limited functionality.

## Troubleshooting

If you encounter issues with your Asahi installation, see the [Maintenance and Troubleshooting](/pages/maintenance-and-troubleshooting) page for general troubleshooting advice.

For Apple Silicon specific issues, the [Asahi Linux Community](https://asahilinux.org/community/) is a valuable resource.


