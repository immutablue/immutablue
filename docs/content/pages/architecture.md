+++
date = '2025-04-18T17:30:00-05:00'
draft = false
title = 'System Architecture'
+++

# Immutablue System Architecture

Immutablue is an immutable operating system that is built utilizing a cloud-native container methodology. As such, one of the core principles of the Immutablue Project is re-use / inheritance.

This page provides an overview of the high-level architecture and build process of Immutablue. For details about the component architecture and internal workings, see the [Component Architecture](component-architecture.md) page.

## Container-based Inheritance Model

A core concept of containers is doing `FROM <image>` and then making customizations. This pulls in the parent's layers, then appends the customization layers, and then tags the resulting image as a new image. Same goes for Immutablue. Immutablue has the main "base" image: `quay.io/immutablue/immutablue` and then other intermediate images:
- `quay.io/immutablue/immutablue-asahi` (Apple-Silicon support)
- `quay.io/immutablue/immutablue-cyan` (Nvidia support)
- `quay.io/immutablue/immutablue-kuberblue` (Kubernetes support)
- `quay.io/immutablue/immutablue-nucleus` (Headless)
- `quay.io/immutablue/immutablue-trueblue` (NAS appliance with ZFS)

All of the intermediate images are perfectly capable of being ran by themselves as a full-featured Immutablue release. However, the idea is that you can base a downstream image off of these images. We take responsibility of doing the hard part of adding Apple-Silicon support, or prebaking in the Nvidia kmod so you don't have to. You can get them "for free".

For more details about the different variants and their use cases, see the [Immutablue Variants](immutablue-variants.md) page.

### Downstream (Custom) Images 

All of the mentioned intermediate images are "custom-images." The cool thing is, since we are just using containers, custom-images can inherit from other custom-images. If you wanted to have `trueblue` inherit from `kuberblue` you can. But where this becomes powerful is building your custom downstream image inheriting from one of these, or in the case of `trueblue` or `kuberblue` add any static configs you want and use that in your deployment.

## Build Process 

Immutablue is built with buildah which builds an OCI compliant container and pushes this to `quay.io`. The container is built in a 2-stage process where a dep-builder container is used to build any binaries we may need, then the real Immutablue container is built.

The build process is described in more detail in the [Build Customization](build-customization.md) page, but here's a high-level overview of the build stages.

The Immutablue container uses a sub-stage approach consisting of 8 sub-stages:
- `00-pre`: Early build preparation
- `10-copy`: Copy files from mounted containers
- `20-add-repos`: Add package repositories
- `30-install-packages`: Install RPM packages
- `40-uninstall-packages`: Remove unwanted packages
- `50-remove-files`: Remove unwanted files
- `60-services`: Configure systemd services
- `90-post`: Final post-build tasks

The build is kicked off with `make build` which uses the `Containerfile` to describe how to build the Immutablue container. After the first stage is completed, the second stage kicks off and iterates over each script in `build/` in alphanumeric order, each file (except `99-common.sh`) represents a sub-stage.

## File Overrides

Immutablue makes extensive use of file overrides on the root filesystem. These overrides are placed in the `artifacts/overrides/` directory during build time and are copied to their corresponding locations in the root filesystem.

Example: `artifacts/overrides/usr/bin/my-script` maps to `/usr/bin/my-script` in the final image.

Common override locations include:
- Binaries: `/usr/bin/`
- Systemd units: `/usr/lib/systemd/(system|user)/`
- Quadlets: `/usr/share/containers/systemd/`
- Libexec scripts: `/usr/libexec/immutablue/`

### Systemd Units and Quadlets 

Regular systemd unit files **can** be enabled/disabled/masked/unmasked in the build's `packages.yaml` file under the appropriate section. This can be done for both system and user (using `--global`) systemd units.

Quadlets however **cannot** be enabled in `packages.yaml`, rather, we can add these to the file `/usr/libexec/immutablue/system/on_boot/00-on_boot.sh`.

## First Boot and Initialization Process

For details about the system initialization, first boot process, and service management, see the [Component Architecture](component-architecture.md#system-initialization) page.

