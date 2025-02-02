+++
date = '2025-02-02T12:34:22-05:00'
draft = false
title = 'Asahi'
+++

# Immutablue Asahi
A special build of Immutablue that adds apple silicon support. Whatever devices (Asahi Linux)[https://asahilinux.org/fedora/#device-support] supports, we support.

## Usage
If you want to just use plain Immutablue you can use `quay.io/immutablue/immutablue:41-asahi` or `quay.io/immutablue/immutablue:41-kinoite-asahi`.

If you maintain a downstream image then in your downstream images all you need to do is do:
```bash
make ASAHI=1 all
```
and voila, you will have an asahi build of your Immutablue image. It will be tagged with `-asahi` appended to the end of the tag name.

It is **HIGHLY** recommended you build this with Apple Silicon hardware as to not break anything. It seems from my own testing that if this is built from Hetzner Arm64 VPS instances for whatever reason that it soft-bricks your install.

## Bootstrapping
As of right now, as far as I know from my testing, you **must** bootstrap your Asahi Immutablue install with regular Fedora Asahi Remix (or I guess any other Asahi flavor). I have not tested or tried building an ISO file to boot, with the requirement of the `linux-16k` kernel having the drivers I highly doubt it will work.

### Bootstrapping Process
- Install asahi linux with `curl https://alx.sh | sh` from macos (I did Gnome)
- After booting into asahi for the first time do a full update:
  - `sudo dnf update -y && sudo reboot`
- Now we need to bootstrap with an ostree repo, then use that to `rpm-ostree rebase` on top of. Follow these instructions exactly or you will need to restart from scratch.
  - **NOTE**: The following is a relatively destructive operation. Your system will be "reset" in terms of configs, but your home *should* be preserved. Regardless be responsible and have a backup before doing this. I warned you and take no responsibility.
```bash 
sudo su -
dnf -y install ostree ostree-grub2 rpm-ostree

# Move boot loader stuff (honestly much just be able to be deleted)
mv /boot/loader /boot/loader.pre_sb.bak
mv /boot/grub2/grub.cfg /boot/grub2/grub.cfg.pre_sb.bak
cp /boot/efi/EFI/fedora/grub.cfg /boot/efi/EFI/fedora/grub.cfg.pre_sb.bak

# ostree init
ostree admin init-fs /

ostree remote add fedora https://ostree.fedoraproject.org --set=contenturl=mirrorlist=https://ostree.fedoraproject.org/mirrorlist --no-gpg-verify

ostree --repo=/ostree/repo pull fedora:fedora/40/aarch64/silverblue

ostree admin os-init fedora

# use a base fedora silverblue to get things started
ostree admin deploy --os=fedora --karg-proc-cmdline fedora:fedora/40/aarch64/silverblue

# Find the first id (so we know not to use it)
# Make note of this as its for the above Fedora id
ls -l /ostree/deploy/fedora/deploy

# Now we rebase to an immutablue-asahi build (such as hyacinth-macaw) 
# This gives us a second id
rpm-ostree rebase --os=fedora --sysroot=/ --experimental ostree-unverified-registry:registry.gitlab.com/immutablue/hyacinth-macaw:40-asahi

# Note cf7f7a6e62c5353223d16c9d6fab0c9e0191c2c6848f6fcf7773180d0152d18d.0 is the checksum of the deployment in this case for my hyacinth-macaw
for i in /etc/fstab /etc/default/grub /etc/locale.conf ; do cp "$i" /ostree/deploy/fedora/deploy/cf7f7a6e62c5353223d16c9d6fab0c9e0191c2c6848f6fcf7773180d0152d18d.0/$i; done

# Add in your home dir
echo 'L /var/home - - - - ../sysroot/home' > /ostree/deploy/fedora/deploy/cf7f7a6e62c5353223d16c9d6fab0c9e0191c2c6848f6fcf7773180d0152d18d.0/etc/tmpfiles.d/00rpm-ostree.conf

```
- And then reboot and hope it works. If it doesn't -- you didn't follow this exactly and will have to start over (likely) with a fresh Asahi install from macos.
- Enjoy

#### What about bootc?
In theory it may be possible with bootc to install Immutablue Asahi to disk, however this is untested. Proceed at your own risk. If it does work for you, feel free to open up a pull request to update this doc with what you did.

#### You need to reset and reinstall asahi from macos:
Validate your partitions -- **DO NOT BLINDLY COPY AND PASTE BELOW COMMANDS**
```bash
diskutil apfs deleteContainer disk0s3
diskutil eraseVolume free free disk0s4
diskutil eraseVolume free free disk0s5
diskutil eraseVolume free free disk0s6
curl https://alx.sh | sh
```

## Post Install 

### Use full display 
By default the notch part of the display is not used. If you would like to use this you can do that with the following:
```bash
immutablue asahi_enable_notch_render
```
After doing so reboot, and the full screen (including notched part) should be used.

#### Disable
Run the following
```bash
immutablue asahi_disable_notch_render
```


