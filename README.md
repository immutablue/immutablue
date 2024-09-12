# Immutablue

An easy, modular, and customizable implementation of a base Fedora Silverblue Image with sane defaults.

## Getting Started

This is the base image designed for a general use case. If you're happy with the defaults, feel free to download the [iso](https://gitlab.com/immutablue/immutablue/-/releases) in the releases or `rpm-ostree rebase` off this if Fedora Silverblue is *already* installed. **We highly recommend** just downloading the ISO. It's the easiest way to get started.

### To rebase
```
sudo rpm-ostree rebase ostree-unverified-registry:registry.gitlab.com/immutablue/immutablue:40
```

### Customizing 

If you want a custom version or have specific needs, this is **not** the repo to fork or modify. We have another repo dedicated for that purpose.

We have taken care to make sure it is easy to modify and build upon, should you want to. This is highly recommended.

Fork the custom repository if you want to make changes. You can find it [here](https://gitlab.com/immutablue/immutablue-custom).

### immutablue commands
    - install:
        - Should be used after rebase to perform initial install.
    - upgrade:
        - Upgrades the system image. *Requires* system reboot to take affect.
    - update:
        - Updates system, by installing new brew packages, flatpaks, updates distroboxes and runs post_install.sh
    - install_distrobox:
        - Installs/update exisiting distroboxes. May be required to account for upstream changes.
    - post_install:
        - Runs post_install.sh

### Reboot
When running immutablue `install|upgrade|update` you can add the optional `REBOOT=1` flag. This will prompt a `systemctl reboot` call after all steps are executed for the respective targets.

> By default `REBOOT=0`

#### Examples

We have some examples of custom builds of Immutablue. These are our actual daily driver workstations. Not just toy examples.
If you need some inspiration or trying to learn how we did something, these can be a great place to look.
They follow the exact same process as here. ISOs are also included. 

- [Hyacinth Macaw](https://gitlab.com/immutablue/hyacinth-macaw)
- [Hawk Blueah](https://gitlab.com/immutablue/hawk-blueah)
- [Blue-Tuxonaut](https://gitlab.com/noahsibai/blue-tuxonaut)



