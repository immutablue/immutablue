+++
date = '2025-04-18T15:00:00-05:00'
draft = false
title = 'Package Management'
+++

# Immutablue Package Management

Immutablue combines several package management approaches to offer flexibility while maintaining the immutability of the core system. This document explains the package management strategies used in Immutablue and how to manage software effectively.

## Layered Package Management

Immutablue uses a layered approach to package management, combining:

1. **Immutable Base**: The core OS image, modified through `rpm-ostree`
2. **Flatpaks**: For GUI applications
3. **Distrobox**: For containerized development environments
4. **Homebrew**: For CLI tools (primarily on x86_64)

This layered approach allows you to maintain the immutability benefits of OSTree while still having flexibility to install and update applications.

## Core System Packages with rpm-ostree

The core system is managed using `rpm-ostree`, which follows a transactional, image-based approach. Changes to the core system, such as installing or removing packages, are applied as atomic operations that create a new system image.

### Viewing Installed Packages

To see what packages are currently installed in the system image:

```bash
rpm-ostree status --verbose
```

### Installing Packages

To install additional packages to the core system:

```bash
sudo rpm-ostree install <package-name>
```

This operation creates a new deployment with the additional packages layered on top of the base image. A reboot is required to switch to the new deployment.

### Removing Packages

To remove installed packages:

```bash
sudo rpm-ostree uninstall <package-name>
```

### Updating the System

To update the core system:

```bash
sudo rpm-ostree update
```

This fetches and applies any available updates to the base image. After the operation completes, a reboot is required to boot into the updated system.

### Rebasing to a Different Image

To switch to a different Immutablue variant or version:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:quay.io/immutablue/immutablue:<version>
```

Replace `<version>` with the desired version tag (e.g., `42`, `42-lts`, `42-cyan`).

## GUI Applications with Flatpak

Flatpak is the recommended way to install graphical applications in Immutablue. These applications run in sandboxed environments and are independent of the core system.

### Finding Applications

To search for available Flatpak applications:

```bash
flatpak search <search-term>
```

### Installing Applications

To install a Flatpak application:

```bash
flatpak install --user <app-id>
```

The `--user` flag installs the application for the current user only.

### Updating Applications

To update all installed Flatpak applications:

```bash
flatpak update --user
```

### Removing Applications

To remove a Flatpak application:

```bash
flatpak uninstall --user <app-id>
```

## Development Environments with Distrobox

Distrobox creates containerized environments where you can install and use tools without affecting the immutable base system.

### Immutablue's Preconfigured Distroboxes

Immutablue comes with two preconfigured Distrobox containers:

1. **util**: A basic utility container with essential tools
2. **dev**: A development environment with compilers and development tools

### Entering a Distrobox

To enter a Distrobox container:

```bash
distrobox enter <container-name>
```

For example, to enter the dev container:

```bash
distrobox enter dev
```

### Installing Software in a Distrobox

Once inside a Distrobox, you can use the container's native package manager to install software. For example, in the Fedora-based containers that Immutablue uses:

```bash
sudo dnf install <package-name>
```

### Exporting Applications from Distrobox

To make an application installed in a Distrobox available on the host system:

```bash
distrobox-export --app <application-name>
```

For binaries:

```bash
distrobox-export --bin <path-to-binary>
```

### Creating Custom Distroboxes

To create a custom Distrobox container:

```bash
distrobox create --name <container-name> --image <container-image>
```

## CLI Tools with Homebrew

On x86_64 systems, Immutablue uses Homebrew to provide additional CLI tools. Homebrew is installed in the `/home/linuxbrew` directory and is accessible to all users.

### Installing Packages with Homebrew

To install a package with Homebrew:

```bash
brew install <package-name>
```

### Updating Homebrew Packages

To update all Homebrew packages:

```bash
brew update && brew upgrade
```

### Removing Homebrew Packages

To remove a Homebrew package:

```bash
brew uninstall <package-name>
```

## Automated Package Management in Immutablue

Immutablue provides several automation commands to simplify package management:

### immutablue install

The `immutablue install` command performs the initial setup after installation, including:

- Installing configured Flatpaks
- Setting up Distrobox containers
- Installing Homebrew and configured packages
- Running post-installation scripts

### immutablue update

The `immutablue update` command updates the entire system, including:

- Updating the core system with `rpm-ostree update`
- Updating Flatpaks
- Updating Distrobox containers
- Updating Homebrew packages
- Running post-update scripts

### immutablue upgrade

The `immutablue upgrade` command is similar to `update` but includes a system reboot to apply core system updates.

## Customizing Package Selection

### During Build Time

The packages installed during the build process are defined in the `packages.yaml` file. This file includes sections for:

- RPM packages for the core system
- Flatpak applications
- Distrobox configurations
- Homebrew packages

You can customize this file in your own fork of Immutablue to include the packages you need.

### Post-Installation

After installation, you can use any of the package management tools described above to install additional software according to your needs.

#### Temporary Package Installation with bootc usr-overlay

For temporary package installations that won't persist across reboots, you can use the `bootc usr-overlay` command. This creates a writable overlay on top of the normally read-only `/usr` directory:

```bash
# Create a writable overlay of /usr
sudo bootc usr-overlay create

# Now you can install packages directly with dnf
sudo dnf install some-package

# Use the package temporarily
some-package --help

# On reboot, the overlay is discarded and all changes are lost
```

This approach is excellent for:
- Testing packages before permanently layering them with rpm-ostree
- Installing dependencies needed only temporarily
- Experimenting with system configurations
- Debugging issues that require specific tools

Remember that all changes made through the overlay will be lost on reboot, returning the system to its pristine state.

For more permanent customizations, consider creating your own custom image with the desired packages included in the build.