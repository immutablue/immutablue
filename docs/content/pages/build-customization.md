+++
date = '2025-04-18T14:30:00-05:00'
draft = false
title = 'Build Customization'
+++

# Immutablue Build Customization

This guide provides detailed information on customizing the Immutablue build process to create your own variants of the system.

## Understanding The Build Process

Immutablue uses a multistage build process to create OCI-compliant container images. The build is structured in a way that makes it easy to customize and extend.

### Build Stages

The Immutablue build process consists of the following stages, each represented by a script in the `build/` directory:

1. **00-pre**: Early build preparation
2. **10-copy**: Copy files from mounted containers
3. **20-add-repos**: Add package repositories
4. **30-install-packages**: Install RPM packages
5. **40-uninstall-packages**: Remove unwanted packages
6. **50-remove-files**: Remove unwanted files
7. **60-services**: Configure systemd services
8. **90-post**: Final post-build tasks

Additionally, there's a **99-common.sh** script that provides common functions used by the other scripts.

### Build Options

Immutablue supports various build options that can be combined to create custom builds:

#### Desktop Environment Options

Each of these options selects a different desktop environment:

- **silverblue**: GNOME desktop (default)
- **kinoite**: KDE Plasma desktop
- **sericea**: Sway window manager
- **onyx**: Budgie desktop
- **vauxite**: XFCE desktop
- **lazurite**: LXQt desktop
- **cosmic**: COSMIC desktop
- **nucleus**: No desktop environment (headless)

#### Feature Options

These options add specific features to the build:

- **asahi**: Support for Apple Silicon hardware
- **cyan**: Support for NVIDIA graphics
- **lts**: Use LTS kernel (automatically includes ZFS)
- **zfs**: Include ZFS filesystem support
- **bazzite**: Optimized for Steam Deck
- **build_a_blue_workshop**: Special build for n8n automation

### Customizing Your Build

To customize your Immutablue build, you can use the following approaches:

#### Command Line Options

The `make build` command accepts various options to customize the build:

```bash
# Build with NVIDIA support
make CYAN=1 build

# Build with LTS kernel
make LTS=1 build

# Build a KDE Plasma version with NVIDIA support
make KINOITE=1 CYAN=1 build

# Build a headless version
make NUCLEUS=1 build
```

You can combine multiple options to create a build that meets your specific needs.

#### Modifying packages.yaml

The `packages.yaml` file is the central configuration file that controls what packages are installed, what repositories are added, and what services are enabled/disabled in the build.

Key sections include:

- **repo_urls**: Package repositories to add
- **rpm**: RPM packages to install
- **rpm_url**: URLs to RPM packages to download
- **rpm_rm**: RPM packages to remove
- **file_rm**: Files to remove
- **services_enable_sys**: System services to enable
- **services_disable_sys**: System services to disable
- **services_mask_sys**: System services to mask
- **services_unmask_sys**: System services to unmask
- **flatpaks**: Flatpaks to install
- **flatpaks_rm**: Flatpaks to remove

You can add architecture-specific and flavor-specific variants using suffixes:

- **_x86_64**: Only for x86_64 architecture
- **_aarch64**: Only for aarch64 architecture
- **_gui**: Only for GUI builds
- **_silverblue**: Only for GNOME builds
- **_kinoite**: Only for KDE builds
- And so on for other flavors

#### File Overrides

File overrides allow you to add or replace files in the final image. Place your files in the `artifacts/overrides/` directory, maintaining the same directory structure as the root filesystem.

For example:

- `artifacts/overrides/etc/profile.d/my-profile.sh` will be placed at `/etc/profile.d/my-profile.sh`
- `artifacts/overrides/usr/bin/my-script` will be placed at `/usr/bin/my-script`

This is particularly useful for adding custom scripts, configuration files, or replacing existing files with customized versions.

You can also use specialized override directories for specific variants:

- `artifacts/overrides_asahi/`: Files specific to Asahi builds
- `artifacts/overrides_cyan/`: Files specific to NVIDIA builds

## Creating A Custom Image

To create your own custom Immutablue image:

1. Fork the `immutablue-custom` repository (recommended over forking the main repository)
2. Modify the `packages.yaml` file to add/remove packages as needed
3. Add any custom files to `artifacts/overrides/`
4. Update the `settings.yaml` file with your custom settings
5. Build the image using `make build` with your desired options

### Example: Creating a Developer Workstation

Here's an example of creating a custom image optimized for software development:

1. Start with a base Immutablue image with NVIDIA support:
   ```bash
   make CYAN=1 build
   ```

2. Add development packages to `packages.yaml`:
   ```yaml
   immutablue:
     rpm:
     - basemount
     - cmake
     - gcc-c++
     - git
     - golang
     - java-latest-openjdk-devel
     - nodejs
     - python3-devel
     - rust
     - code
   ```

3. Add custom VS Code settings through file overrides:
   ```
   artifacts/overrides/etc/skel/.config/Code/User/settings.json
   ```

4. Build and test your custom image.

## Advanced Build Customization

### Custom Build Scripts

For advanced customization, you can modify or add to the build scripts in the `build/` directory. This allows you to customize the build process itself, rather than just the packages and files.

For example, to add a custom post-build step:

1. Create a `custom-post.sh` script in your fork
2. Add it to the build sequence in `Containerfile`

### Using Custom Repositories

To add custom repositories:

1. Add the repository URL to `packages.yaml`:
   ```yaml
   immutablue:
     repo_urls:
     - name: my-custom-repo.repo
       url: https://example.com/my-custom-repo.repo
   ```

2. The build process will download and install this repository file.

### Building For Different Architectures

Immutablue supports both x86_64 and aarch64 architectures. Use the `PLATFORM` variable to specify the target architecture:

```bash
make PLATFORM=linux/aarch64 build
```

Note that some features (like homebrew) are only available on specific architectures, and the build process will adjust accordingly.