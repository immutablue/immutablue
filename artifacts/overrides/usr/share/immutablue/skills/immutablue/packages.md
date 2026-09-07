# Installing Software

Read this before installing anything on a machine running Immutablue.

There is no `dnf` on the host in the sense that matters, and `rpm-ostree install`
is the *last* option rather than the first. Work down this list and stop at the
first one that fits.

## The decision tree

### 1. GUI application → Flatpak

```bash
flatpak install --user flathub org.example.App
```

`--user` by default. System-wide flatpaks live in `/var` and are shared, which is
occasionally what you want but is also what a `/var` snapshot restore reverts.

### 2. CLI tool → Homebrew

```bash
brew install ripgrep
```

Immutablue ships brew already wired up. This is the right answer for most
developer CLI tools: no layering, no reboot, no effect on update time.

### 3. Anything needing a different distro, a package manager, or system headers → distrobox

```bash
distrobox enter dev
```

Immutablue declares its boxes in `packages.yaml`, so they are reproducible rather
than hand-assembled — image, mount flags, package lists per architecture, npm/pip
lists, and binary/app exports are all data. `immutablue install_distrobox`
assembles them.

This is where build dependencies belong when you are compiling something ad hoc.

### 4. Needs to be part of the OS → change the image

A kernel module, a system service, a shell, anything that has to exist before you
log in — that belongs in `packages.yaml` and a rebuild. See
[`building.md`](building.md). This is the *preferred* answer on this system, not
the exotic one: it survives updates and reaches every machine.

### 5. Last resort → rpm-ostree layering

```bash
rpm-ostree install <package>
systemctl reboot
```

Say what it costs before recommending it:

- Every OS update must rebuild the layered set, so updates get slower.
- A layered package whose dependencies stop resolving **blocks updates entirely**
  until it is removed.
- It is per-machine, so it does not reach anything else you run.

`rpm-ostree uninstall <package>` reverses it. Layering is legitimate for a driver
or an agent that genuinely must be in the image and cannot wait for a rebuild —
it is not a substitute for the four options above.

## What is already installed

The image's package set is data, not mystery:

```bash
cat /usr/immutablue/packages.yaml
rpm -qa | sort                    # what is actually in this deployment
rpm-ostree status                 # including anything layered on top
flatpak list
brew list
distrobox list
```

`packages.yaml` is organised by variant and architecture: `rpm.all`, `rpm_gui`,
`rpm_silverblue`, `rpm_kinoite`, `rpm_nucleus`, `rpm_kuberblue`, `rpm_trueblue`,
`rpm_x86_64`, `rpm_<version>_aarch64`, and so on, plus `rpm_rm*` lists of packages
removed from the base image. If you are asked why some package is or is not
present, that file is the answer.

## Updating what is installed

```bash
immutablue update        # everything: bootc, distrobox, flatpak, brew, per settings.yaml
```

Which components it touches is controlled by the `immutablue.run_*` keys — see
[`configuration.md`](configuration.md). See [`updates.md`](updates.md) for what
happens around an OS update, including the automatic `/var` snapshot.

## AI coding agent harnesses

These are installed on demand rather than baked in, because each installs into the
user's home, self-updates, and authenticates per user — none of which survives a
read-only `/usr` replaced on update.

```bash
immutablue list_agents
immutablue install_agents claude-code codex
immutablue install_agents all
```

The list is data in `packages.yaml` under `.immutablue.agent_harnesses`. Note that
`ai` itself is different: it is a **shipped binary**, part of ai-glib, built into
the image. It is the built-in harness and needs no installation.
