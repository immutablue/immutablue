+++
date = '2025-01-06T10:47:37-05:00'
draft = false
type = 'page'
title = 'Installation Guide'
+++

# Installing Immutablue

Currently (as of Jan 6th 2024) the built ISOs have a bug and fails to install. To work around this: 
- Download the latest
[Silverblue iso here](https://download.fedoraproject.org/pub/fedora/linux/releases/41/Silverblue/x86_64/iso/Fedora-Silverblue-ostree-x86_64-41-1.4.iso)
- dd to a flash drive (`dd if=/path/to/iso of=/dev/flashdrivedevice bs=1M && sync`) or boot in a VM and run through the install.
- After install, do the initial user login and setup then open a command prompt
  - Use following command 
```bash
sudo rpm-ostree cancel && sudo rpm-ostree ostree-unverified-registry:quay.io/immutablue/immutablue:41 -r
```
  - if you use Nvidia GPUs then use the `immutablue-cyan` (`immutablue-cyan:41`)
  - if you want the LTS kernel (and don't use Nvidia) then append `-lts` to the `41` tag (`immutablue:41-lts`)
- After the command succeeds it will automatically reboot your system.
- After first login, after approximately 15 seconds, the entire Immutablue post-install system will kick in and install anything else (such as brew packages, distrobox and such)

## Need to re-run the installer?
You may want to re-run the installer because something went wrong during or after the installation, perhaps some new features were added you would like to have, or some other reason. If one of these occurred, then do the following:
```bash
sudo rm /etc/immutablue/setup/did_first_boot /etc/immutablue/setup/did_first_boot_graphical
rm $HOME/.config/.immutablue_did_first_login
sudo systemctl unmask immutablue-first-boot.service
systemctl --user unmask immutablue-first-login.service 
sudo reboot
```
At the next boot-up and login the installers will re-run.

