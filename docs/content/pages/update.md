+++
date = '2025-01-06T20:09:30-05:00'
draft = false
title = 'Updating Immutablue'
+++

# Updating Immutablue

Keeping Immutablue up-to-date (including for all builds inheriting from Immutablue) is straight-forward. It should be noted that there is an autoupdate program that runs weekly (meaning. updates are ran without human intervention) which updates the following things:
- Immutablue Image (via `rpm-ostree`) -- applied on next system boot
- Flatpaks
- Distrobox Images (only the packages, not the version of the container image!)
- Brew (if on x86_64)

It also re-enables the "first-boot" scripts which will kick start the `post_install`. Why is this important? Sometimes the files within the post install change later on, so this ensures nothing breaks. Also, this handles the installation of upstream-configured flatpaks and brew packages which are only possible to install at runtime and cannot be provided at build-time.

## Manual Updates 

I get it, you don't want to wait a week. Perhaps you are waiting for a bug fix upstream, or you want the latest and greatest NOW, and not next week. Simply run:
```bash
immutablue-update
```
Reboot after its done, and the "first-boot" scripts will run again after you login.

