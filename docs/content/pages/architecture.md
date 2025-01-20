+++
date = '2025-01-19T23:10:10-05:00'
draft = false
title = 'Architecture'
+++

# Immutablue Architecture

Immutablue is an immutable operating system that is built utilizing a cloud-native container methodology. As such, one of the core principles of the Immutablue Project is re-use / inheritance.

## Inheritance

A core concept of containers is doing `FROM <image>` and then making customizations. This pulls in the parent's layers, then appends the customization layers, and then tags the resulting image as a new image. Same goes for Immutablue. Immutablue has the main "base" image: `quay.io/immutablue/immutablue` and then other intermediate images:
- `quay.io/immutablue/immutablue-asahi` (Apple-Silicon support)
- `quay.io/immutablue/immutablue-cyan` (Nvidia support)
- `quay.io/immutablue/immutablue-kuberblue` (Kubernetes support)
- `quay.io/immutablue/immutablue-nucleus` (Headless)
- `quay.io/immutablue/immutablue-trueblue` (NAS appliance with ZFS)

All of the intermediate images are perfectly capable of being ran by themselves as a full-featured Immutablue release, however, the idea is that you base a downstream image off of these images. We take responsibility of doing the hard part of adding Apple-Silicon support, or prebaking in the Nvidia kmod so you don't have to. You can get them "for free".

### Downstream (Custom) Images 

All of the mentioned intermediate images are "custom-images." The cool thing is, since we are just using containers, custom-images can inherit from other custom-images. If you wanted to have `trueblue` inherit from `kuberblue` you can. But where this becomes powerful is building you custom downstream image inheriting from one of these, or in the case of `trueblue` or `kuberblue` add any static configs you want and use that in your deployment.


## Build Process 

Immutablue is build with buildah which builds an OCI compliant container and pushes this to `quay.io`. The container is build in a 2-stage process where a dep-builder container is used to build any binaries we may need, then the real Immutablue container is built. The Immutablue container uses a sub-stage approach consisting of 8 sub-stages:
- `00-pre`
- `10-copy`
- `20-add-repos`
- `30-install-packages`
- `40-uninstall-packages`
- `50-remove-files`
- `60-services`
- `90-post`

The build is kicked off with `make build` which uses the `Containerfile` to describe how to build the Immutablue container. Of which, after the first stage is completed, the second stage kicks off and iterates over each script in `build/` in alphanumeric order, each file (except `99-common.sh`) represents a sub-stage.

### 00-pre 

Any early build stuff can be done here, currently not used. Great place for any workarounds or similar.

### 10-copy 

We mount various other containers (as seen in the `Containerfile`), this is where we have the code to copy the relevant files from other OCI images into our Immutablue. A common thing is things such as binary files (such as `yq`)

### 20-add-repos 

This references `.immutablue.repo_urls` and its derivatives in `packages.yaml`. Basically it downloads the referenced repo files and puts them in place (`/etc/yum.repos.d`)

### 30-install-packages 

This references `.immutablue.rpm`, `.immutablue.rpm_url`, and `.immutablue.pip_packages` and their respective derivatives. All this does is run `rpm-ostree install` with the various packages.

We also have logic here for the `DO_INSTALL_ZFS` and `DO_INSTALL_LTS` build options which are options to the `make build` command:
```bash
make DO_INSTALL_ZFS=true DO_INSTALL_LTS=true build
```
 
### 40-uninstall-packages 

This references `.immutablue.rpm_rm` and its derivatives in the `packages.yaml`. This simply runs `rpm-ostree uninstall` for the various packages.

### 50-remove-files 

This references `.immutablue.file_rm` and its derivatives in the `packages.yaml`. This runs `rm -rf` on each listed entry, so you are able to do full directory pathes here. This is useful for cleanups of temp files that make itself into the build that you don't want/can't have there.

### 60-services 

This references the following from `packages.yaml`:
```yaml
immutablue:
  services_enable_sys:
  services_disable_sys:
  services_mask_sys:
  services_unmask_sys:
  services_enable_user:
  services_disable_user:
  services_mask_user:
  services_unmask_user:
```

### 90-post

This references nothing in `packages.yaml` and is a place to do anything late-build. Currently we do the syncthing service override, build immutablue docs here, and do some permissions tweaks.

### 99-common 

`build/99-common.sh` is a place to share common bash functions that the other 8 sub-stages use.


## Immutablue First Boot (Setup)

On first boot of Immutablue the following services will kickoff:
- `immutablue-first-boot.service` (system)
- `immutablue-first-login.service` (user)

### immutablue-first-boot.service 

`immutablue-first-boot.service` does the following:
- checks for `/etc/immutablue/setup/did_first_boot`
  - if it exists the service exits 
- runs the script `/usr/libexec/immutablue/setup/first_boot.sh`
- create the file `/etc/immutablue/setup/did_first_boot`
- mask the service `immutablue-first-boot.service`

### immutablue-first-login.service

`immutablue-first-boot.service` does the following:
- checks for `/home/${USER}/.config/.immutablue_did_first_login`
  - if it exists the service exits 
- run the script `/usr/libexec/immutablue/setup/first_login.sh`
  - check for the file `/etc/immutablue/setup/did_first_boot_graphical`
    - if the file does not exist it it executes `/usr/libexec/immutablue/setup/first_boot_graphical.sh`
      - after validating internet access this will launch `immutablue install` either in a terminal (if graphical) or in the background if text (nucleus based builds)
        - `immutablue install` installs: flatpaks, distrobox, brew, and runs `post_install.sh` for all custom-images. (see `Makefile`)
      - create `/etc/immutablue/setup/did_first_boot_graphical`
- create the file `/home/${USER}/.config/.immutablue_did_first_login`
- mask the service `immutablue-first-boot.service` 


## File Overrides

We make heavy use of file overrides on the root filesystem. This is done by placing the appropriate file under `artifacts/overrides/`. Example: `artifacts/overrides/usr/bin/my-script` maps to `/usr/bin/my-script` when booting into the Immutablue image. 

Some common things we do:
- binaries (`/usr/bin`)
- systemd units (`/usr/lib/systemd/(system|user)`)
- quadlets (`/usr/share/containers/systemd`)
- libexec (`/usr/libexec/immutablue`)

### systemd and quadlets 

It is important to note that regular systemd unit files **can** be enabled/disabled/masked/unmasked in the builds `packages.yaml` file under the appropriate section. This can be done for both system and user (using `--global`) systemd units.

Quadlets however **cannot** be enabled in `packages.yaml`, rather, we can add these to the file `/usr/libexec/immutablue/system/on_boot/00-on_boot.sh`. 

