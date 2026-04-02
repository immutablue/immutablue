# Immutablue

An easy, modular, and customizable implementation of a base Fedora Silverblue Image with sane defaults.

## Repository Setup

This repo uses git submodules. After cloning, initialize them recursively:

```bash
git submodule update --init --recursive
```

## Getting Started

This is the base image designed for a general use case. If you're happy with the defaults, feel free to download the [iso](https://gitlab.com/immutablue/immutablue/-/releases) in the releases or `rpm-ostree rebase` off this if Fedora Silverblue is *already* installed. **We highly recommend** just downloading the ISO. It's the easiest way to get started.

### To rebase
```
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:43
```

### Immutablue Flavors
Head over to the [Immutablue Quay Repository](https://quay.io/repository/immutablue/immutablue?tab=tags) and have a look. There are various *flavors* of Immutablue. The images are tagged in the format `<major_version>-[flavors...]`, so `43` tag is just the default image. But `43-nucleus-lts` is version 43 nucleus build with the LTS kernel. An image can have more than one flavor.
- default: `43` — base Silverblue
- lts: `43-lts` — 6.12 LTS kernel + ZFS
- nucleus: `43-nucleus` — headless/server, no GUI
- kuberblue: `43-kuberblue` — Kubernetes-ready OS
- cyan: `43-cyan` — NVIDIA support
- trueblue: `43-trueblue` — ZFS + LTS kernel + Cockpit management
- nix: `43-nix` — Nix package manager
- asahi: `43-asahi` — Apple Silicon

### Customizing

If you want a custom version or have specific needs, this is **not** the repo to fork or modify. We have another repo dedicated for that purpose.

We have taken care to make sure it is easy to modify and build upon, should you want to. This is highly recommended.

Fork the custom repository if you want to make changes. You can find it [here](https://gitlab.com/immutablue/immutablue-custom).

### immutablue commands

Run these with `just` on an installed Immutablue system.

- `install` — Run after rebase to perform initial setup (flatpaks, distroboxes, post-install scripts).
- `update` — Update the system (flatpaks, distroboxes, brew, post-install).
- `install_distrobox` — Install or update existing distroboxes.
- `install_flatpak` — Install flatpaks.
- `install_brew` — Install Homebrew packages.
- `post_install` — Run post-install scripts from downstream images (for immutablue-custom usage).
- `doctor` — Run system health checks. Also: `doctor_verbose`, `doctor_fix`, `doctor_json`, `doctor_yaml`.
- `initial_setup` — Re-run the first-login setup wizard.
- `clean_system` — Prune unused container images, volumes, flatpaks, and rpm-ostree deployments.
- `bios` — Reboot into BIOS/UEFI firmware settings.
- `sysinfo` — Print system info (useful for filing tickets). `sysinfo_post` to paste it.
- `toggle_firewall` — Toggle firewalld on/off.
- `enable_tailscale` / `disable_tailscale` — Manage Tailscale service.
- `enable_syncthing` / `disable_syncthing` — Manage Syncthing service.
- `enable_libvirt` / `disable_libvirt` — Manage libvirt (VM hosting).
- `disable_suspend` / `enable_suspend` — Control system suspend behavior (ac, battery, or both).

## Docs
We have documentation embedded into Immutablue itself. When running Immutablue, navigate to http://localhost:411 in your browser.

These docs are also available to view in the project here under `docs/content/`.

#### Examples

We have some examples of custom builds of Immutablue. These are actual daily driver workstations, not toy examples. If you need some inspiration or are trying to learn how we did something, these can be a great place to look.

- [Hyacinth Macaw](https://gitlab.com/immutablue/hyacinth-macaw)
- [Hawk Blueah](https://gitlab.com/immutablue/hawk-blueah)
- [Blue-Tuxonaut](https://gitlab.com/noahsibai/blue-tuxonaut)

