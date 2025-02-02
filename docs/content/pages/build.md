+++
date = '2025-02-01T20:45:41-05:00'
draft = false
title = 'Build'
+++

# Building Immutablue

Immutablue is built in multiple stages (see [architecture](/pages/architecture/#build-process)). Classically there existed mid-stream immutablue-custom builds that added simple things like nvidia, or apple-silicon support but these have since been merged into the upstream repo so its easier to build these.

The simplest way to build Immutablue is the following:
```bash
make build
```

## Build Options

Build options, simply put, is a CSV of "options" that the Immutablue build system understands. It can iterate over them and make decisions. Current build options are:
- gui - all gui based builds (basically anything not nucleus)
- asahi - apple silicon support
- cyan - nvidia support
- nucleus - barebones image, no gui (also no pip package support)
- silverblue - uses upstream silverblue (gnome)
- kinoite - uses upstream kinoite (kde)

The default build option is: `gui,silverblue` which can be seen in the `Makefile`.

Passing different options to the `make build` command will change the build options. For example:
- `make CYAN=1 build` will change the build option to `gui,silverblue,cyan`
- `make NUCLEUS=1 build` will change the build option to just `nucleus`

Depending on the build option, some will also change the image that is pulled from as the base (such as kinoite).

By default, the system pulls from upstream Silverblue (quay.io/fedora-ostree-desktops/silverblue)

### Reading build options

During build-time you can evaluate the build options through the environment variable `${IMMUTABLUE_BUILD_OPTIONS}`

During build the configured build options are written to a file at `/usr/immutablue/build_options` so it can be known at runtime and not just build-time. So at runtime just read `/usr/immutablue/build_options`


### build-time helper functions

There exist two build-time helper functions (from `/usr/immutablue/build/99-common.sh`):
- `get_immutablue_build_options` - returns an array that can be easily consumed in a while loop (see implementation of `is_option_in_build_options`) without having to modify the `IFS`
- `is_option_in_build_options` - checks to see if that passed argument, which should be a valid build option, exists in the build options. Can be used to build option detection at build-time to do special configs (such as we do for cyan)



## packages.yaml and the build options

Classically we supported just two types of keys in the `packages.yaml`:
```yaml
immutablue: 
  rpms:
  rpms_aarch64:
```
That is `<key>` and `<key>_<architecture>`.

Immutablue now supports:
```yaml
immutablue: 
  rpms:
  rpms_aarch64:
  rpms_silverblue:
  rpms_kinoite_x86_64:
```
So the same as above, but also including `<key>_<build_option>` and `<key>_<build_option>_<architecture>`.

It is important to note that `<architecture>` is the same as running `$(uname -m)` which is how its evaluated internally at build-time.


