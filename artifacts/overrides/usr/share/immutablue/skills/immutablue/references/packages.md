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

`packages.yaml` is organised by variant and architecture: `rpm`, `rpm_gui`,
`rpm_silverblue`, `rpm_kinoite`, `rpm_nucleus`, `rpm_kuberblue`, `rpm_trueblue`,
`rpm_x86_64`, and so on, each split into `all`, `<version>`, `all_<arch>` and
`<version>_<arch>` sub-keys (`.immutablue.rpm.all`, `.immutablue.rpm_gui.all`),
plus `rpm_rm*` lists of packages removed from the base image. If you are asked
why some package is or is not present, that file is the answer.

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

### Updating `ai` and `ai-tui`: update the image, not the binary

ai-glib ships a self-updater — `ai --check-update`, `ai --update`, and `/update`
in `ai-tui` — that fast-forwards the git checkout the binary was built from,
rebuilds, and `sudo make install`s into the build's prefix. **None of that
applies here.** The image builds `ai` from a submodule copy under `/build`
inside the dependency container: there is no checkout on the machine, the
binary records no commit, and its prefix is the read-only `/usr`. The updater
reports the state `unavailable` ("the source checkout /build/ai-glib does not
exist", or "not built from a git checkout") and refuses; `ai --update` exits 1.
That is the correct outcome, not a fault to fix.

Do not work around it — no `AI_GLIB_SOURCE_DIR` pointed at a clone, no
`make install` into `/usr`, no `bootc usr-overlay` to make it stick. A newer
`ai` arrives with a newer image (`immutablue update`), and a pin bump in the
immutablue repository is how it gets there ([`building.md`](building.md)). To
try a newer ai-glib before the image has it, build and run it inside a
distrobox, never over the host's copy.

What does work:

```bash
ai --version            # "ai (ai-glib) 0.4.0 (built …)": no git describe on an image build
jq '.deps[] | select(.name == "ai-glib")' /usr/immutablue/deps/dep_info.json   # the commit it was built from
```

The background update check is off unless `updates.check: true` is set (or
`ai --setup` scope `4` answered yes); leave it off. `ai-gui`, the GTK4 client,
is not built into the image — the dependency container has no `gtk4-devel` or
`libadwaita-devel`, so ai-glib's build skips it.
