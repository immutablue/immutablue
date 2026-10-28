# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Codex, opencode, grok, and others) when working with code in this repository.

## Project Overview

Immutablue is an easy, modular, and customizable implementation of a base Fedora Silverblue (and other Atomic desktops) image with sane defaults. It uses cloud-native container methodology and a layered build system.

Immutablue is the configuration and packages layered on top of a base OS; the base OS is a **backend** (`backends/<name>/`): `fedora-bootc` (default), `gnomeos` (formerly `DISTROLESS=1`), `arch-bootc`, and `freebsd-be` (FreeBSD 15.1, built on a FreeBSD host or the `backends/freebsd-be/builder-vm.sh` VM). See "Backends" below.

**Key Concepts:**
- Immutable base OS with transactional updates
- Container-based image builds (Containerfile/Podman)
- Layered package management (Flatpak, Distrobox, Homebrew, rpm-ostree)
- Pluggable OS backends (`BACKEND=fedora-bootc|gnomeos|arch-bootc|freebsd-be`)
- Modular variant system (Cyan for NVIDIA, Asahi for Apple Silicon, etc.)
- YAML-based configuration (`settings.yaml`, `packages.yaml`)

## Repository Setup

This repo uses git submodules. After cloning, initialize them recursively:

```bash
git submodule update --init --recursive
```

This is required for the Hugo docs theme (`docs/themes/hugo-book`).

## Build Commands

### Basic Build

```bash
make build                    # Build default (Silverblue) image
make build SKIP_TEST=1        # Skip pre/post-build tests
make test                     # Run all post-build tests
make pre_test                 # Run shellcheck validation only
```

### Variant Flags

Combine flags to build specific variants:

| Flag | Description | Image Tag Example |
|------|-------------|-------------------|
| `NUCLEUS=1` | Minimal (no GUI) | `43-nucleus` |
| `KINOITE=1` | KDE Plasma desktop | `43-kinoite` |
| `SERICEA=1` | Sway compositor | `43-sericea` |
| `CYAN=1` | NVIDIA GPU support | `43-cyan` |
| `ASAHI=1` | Apple Silicon (M1/M2/M3) | `43-asahi` |
| `KUBERBLUE=1` | Kubernetes support | `43-kuberblue` |
| `TRUEBLUE=1` | ZFS + LTS kernel | `43-trueblue` |
| `LTS=1` | LTS kernel (6.12) | `43-lts` |
| `ZFS=1` | ZFS modules (no tag change) | `43` (with ZFS) |
| `NIX=1` | Nix package manager | `43-nix` |

**Examples:**
```bash
make CYAN=1 build             # NVIDIA variant
make KUBERBLUE=1 build        # Kubernetes variant
make LTS=1 build              # LTS kernel variant
make CYAN=1 LTS=1 build       # NVIDIA + LTS kernel
```

### Other Build Options

```bash
make BACKEND=arch-bootc NUCLEUS=1 build  # Arch Linux backend -> :arch-nucleus
make ARCHLINUX=1 build        # same as BACKEND=arch-bootc (FREEBSD=1 -> freebsd-be)
make BACKEND=gnomeos build    # GNOME OS backend (same as DISTROLESS=1)
make backend_check            # Is this BACKEND + variant combination possible?
make VERSION=42 build         # Build for Fedora 42
make PLATFORM=linux/arm64 build  # Build for ARM64
make SET_AS_LATEST=1 build    # Also tag as :latest
make push                     # Push to registry
make manifest                 # Create multi-arch manifest
```

### VM Testing

```bash
make lima                     # Generate Lima VM config
make qcow2                    # Generate qcow2 image
```

### ISO Generation

```bash
make iso-config               # Interactive: configure users/SSH keys
make iso                      # Default: bootc-image-builder ISO
make CLASSIC_ISO=1 iso        # Classic: build-container-installer ISO
make TRUEBLUE=1 iso-config    # Configure for variant
make TRUEBLUE=1 iso           # Variant build with bootc-image-builder
make run_iso                  # Test ISO in QEMU
make push_iso                 # Upload ISO to S3
```

The default `make iso` uses `bootc-image-builder` (same tooling as qcow2), producing an install-to-disk ISO. Use `CLASSIC_ISO=1` for the legacy `build-container-installer` approach which supports flatpak bundling and more Anaconda customization.

`arch-bootc` and `freebsd-be` are not supported by bootc-image-builder, so
`make iso` runs their own `backends/<backend>/make-iso.sh` instead
(`make ARCHLINUX=1 iso`, `make FREEBSD=1 iso` — the latter builds in the
FreeBSD builder VM from Linux). Both boot a live system whose text installer
lays the image onto a disk; GNOME's first-login setup creates the user.
`ISO_AUTOINSTALL=<disk>` bakes in an unattended install for tests.

**Important**: Run `make iso-config` before `make iso` to configure user accounts. Without it, no users are created in the ISO.

Output: `./iso/immutablue-<tag>.iso`
Config: `./iso/config-<tag>.toml`

## Directory Structure

```
immutablue/
├── Makefile                  # Build system (25K+ lines)
├── settings.yaml             # Runtime configuration defaults
├── packages.yaml             # Package definitions by variant/arch/backend
├── backends/
│   ├── lib/interface.sh      # The backend contract (backend_* functions)
│   ├── lib/run-stages.sh     # Merges build/NN-*.sh with backend stages
│   ├── fedora-bootc/         # Containerfile, deps.Containerfile, backend.{yaml,sh},
│   │                         #   runtime.sh, stages/ (kernel/ZFS/NVIDIA, codecs)
│   ├── gnomeos/              # Formerly build/distroless/
│   ├── arch-bootc/
│   └── freebsd-be/           # + deliver.sh (ZFS boot environment delivery)
├── variants/                 # <option>.yaml: what a backend must provide
├── artifacts/
│   ├── overrides/            # Files copied to image root
│   ├── overrides_cyan/       # NVIDIA-specific overrides
│   ├── overrides_asahi/      # Apple Silicon overrides
│   ├── overrides_kuberblue/  # Kubernetes overrides
│   ├── overrides_trueblue/   # ZFS overrides
│   └── overrides_nix/        # Nix overrides
├── build/                    # Platform-neutral stages (run in order)
│   ├── 00-pre.sh
│   ├── 10-copy.sh
│   ├── 20-add-repos.sh
│   ├── 30-install-packages.sh
│   ├── 40-uninstall-packages.sh
│   ├── 50-remove-files.sh
│   ├── 60-services.sh
│   ├── 65-crash-capture.sh
│   ├── 80-initramfs.sh
│   ├── 90-post.sh
│   └── 99-common.sh          # Shared functions (sourced)
├── deps-container/00-build.sh  # Shared deps build (per-backend deps.Containerfile)
├── scripts/
│   ├── common.sh             # Shared script utilities
│   ├── packages.sh           # Package list generation
│   ├── immutablue-lima-gen   # Lima config generator
│   └── immutablue-qcow2-gen  # qcow2 image generator
├── tests/                    # Test suite
├── docs/                     # Hugo documentation site
└── specs/                    # RPM spec files
```

## Where a file on the image actually came from

`build/10-copy.sh` writes to `/usr` from several sources **in order**, and
later ones overwrite earlier ones. When a fix does not show up on a built
system, this ordering is usually why:

| Order | Source | Brought in by |
|-------|--------|---------------|
| 1 | `artifacts/overrides/` | `cp -a /mnt-ctx/artifacts/overrides/. /` (line ~85) |
| 1b | `backends/<backend>/overrides/` | same copy step, right after the shared overrides |
| 2 | in-house C projects (yaml-glib, crispy, gst, **gowl**, mcp-glib, …) | `cp -a /mnt-build-deps/<p>/usr/. /usr/` (line ~172) |
| 3 | **cmacs** | `install_usr_tree /mnt-cmacs/usr` (a `cp -a` that routes `lib64` through the symlink on Arch) — **last, so it wins** |

Consequences worth knowing:

- **The cmacs container is authoritative for anything it ships.** It is built
  out-of-tree by cmacs's own `./build-container` and pulled as
  `quay.io/zachpodbielniak/cmacs:${FEDORA_VERSION}` (`:arch` for arch-bootc). It ships not only
  `/usr/share/wayland-sessions/cmacs.desktop` but also
  `/usr/share/xdg-desktop-portal/gowl-portals.conf` and `portals/` — so those
  are fixed by rebuilding and pushing the cmacs image, **not** by an
  `artifacts/overrides/` entry, and an override there would be overwritten
  anyway.
- **Standalone gowl is a different artifact from the gowl inside cmacs.** It is
  built here from the `deps/gowl` submodule (`backends/<backend>/deps.Containerfile`
  copies it to `/build/gowl`). `gowl.desktop` comes from
  it, because the cmacs image does not ship one. Fixing gowl therefore means
  bumping that submodule, and a fix pushed to gowl reaches no image until you do.
- **The submodule pin is the version.** `git submodule status deps/` shows how
  far behind each in-house project is. The commit that actually produced the
  running binaries is recorded on the machine in
  `/usr/immutablue/deps/dep_info.json`; the source itself is not shipped.

### gowl and the two wlroots versions

`deps/00-build.sh` installs plain `wlroots-devel` — whatever the Fedora
release ships as its default. That means **both** wlroots versions are live
depending on which image you build: 0.20 on F44+, 0.19 on F42/F43. gowl's
`config.mk` picks the newest `wlroots-*.pc` present, so each build gets its
release's version with no flag.

That is convenient and it hides a real failure mode. The two versions differ
in how wlroots' public headers reach generated protocol headers: 0.19
includes them by bare name, so the consumer must produce them with
`wayland-scanner`, while 0.20 uses a header wayland-protocols installs. A
gowl missing one of those generated headers builds fine on F44 and cannot
build at all on F43 — and since a developer box with both versions always
compiles the 0.20 path, nothing catches it before the image build does.

Before bumping the gowl submodule, build it against 0.19 in the gowl checkout:

```bash
make clean && make WLROOTS=0.19
```

gowl's `make test` also runs `tests/test-protocol-headers.sh`, which checks
every *installed* wlroots version rather than the selected one, for exactly
this reason. The same shape applies to libeis (`EIS_EVENT_SEAT_DEVICE_REQUESTED`
is 1.6-only; F43 ships 1.5), which the portal Makefile probes for rather than
requiring.

## Configuration Files

### settings.yaml

Runtime configuration with hierarchical override system:
1. `~/.config/immutablue/settings.yaml` (user, highest priority)
2. `/etc/immutablue/settings.yaml` (system)
3. `/usr/immutablue/settings.yaml` (defaults)

Key sections:
- `.immutablue.gen.*` - VM generator output paths
- `.immutablue.run_*` - Update behavior flags
- `.immutablue.header.*` - Network/terminal detection settings
- `.immutablue.profile.*` - Shell profile settings (starship, ulimit, completions)
- `.services.syncthing.*` - Syncthing configuration
- `.kuberblue.*` - Kubernetes variant settings

### packages.yaml

Package definitions organized by:
- `immutablue.pkg.all` - Packages for every backend, by logical name. An entry is a plain name, or `{name: fd-find, pacman: fd, freebsd: null}` overriding only the backends where it differs (`null` = not there, a list = several packages)
- `immutablue.pkg_gui`, `pkg_silverblue`, `pkg_<arch>`, `.<version>` - Same suffix composition as always (`get_yaml_array` in `build/99-common.sh`)
- `immutablue.rpm*` / `pacman*` / `freebsd*` - Backend-native lists (the key is `pkg_key` in `backend.yaml`); Fedora-only variants (`rpm_kuberblue.<ver>`, `rpm_trueblue`, ...) live here
- `immutablue.build_deps` - What the deps container installs, same logical schema
- `immutablue.services_*` - Unit names; entries may map `{name: sshd.service, rc: sshd}` for rc(8) backends

When adding a name override, check it exists in that distribution's repository; `tests/test_pkg_resolve.sh` rejects unknown override fields.

## Key Scripts & Tools

### Build-time (in build/)
Scripts run in alphanumeric order during container build, merged by name with the selected backend's `backends/<backend>/stages/` by `backends/lib/run-stages.sh` (build/ first on a tie; `skip_stages` in `backend.yaml` drops neutral stages a backend cannot run). Always source `99-common.sh` for helpers. **Never call dnf5/rpm/pacman/pkg/systemctl/sysrc directly in `build/`** — use `backend_pkg_install`, `backend_svc`, etc. (`backends/lib/interface.sh`), and test capabilities with `backend_has <cap>` rather than the backend's name. OS-only steps belong in that backend's `stages/`.

## Backends

| Backend | Base | Packages | Init | Delivery | Status |
|---------|------|----------|------|----------|--------|
| `fedora-bootc` | Fedora Atomic (silverblue, base-atomic, asahi, ...) | dnf5 (`rpm` key) | systemd | bootc/ostree | default |
| `gnomeos` | GNOME OS nightly | none | systemd | bootc/composefs | as before (DISTROLESS=1) |
| `arch-bootc` | archlinux:latest + bootc v1.17.1 (no SELinux) | pacman | systemd | bootc/ostree | new; boots in QEMU; ships the in-house C projects (local deps image until `:arch-deps` is published) and cmacs (`cmacs:arch`) |
| `freebsd-be` | FreeBSD 15.1 pkgbase OCI | pkg | rc | ZFS boot environment (`deliver.sh`) | early; builds, passes `make test`, delivers and boots on a FreeBSD 15.1 VM (`backends/freebsd-be/builder-vm.sh`); FreeBSD build host only |

A backend is `backend.yaml` (facts and `provides` capabilities), `backend.sh` (the build contract), `runtime.sh` (verbs for `immutablue-backend`), a `Containerfile` and `deps.Containerfile`, and optionally `backend.mk` (Make defaults), `stages/` and `overrides/`. `tests/test_backend_contract.sh` checks every backend against the contract. Variants declare what they need in `variants/<option>.yaml` (`requires:`), enforced by `make backend_check` / `scripts/check-backend.sh`.

### Runtime (installed to image)

| Command | Location | Purpose |
|---------|----------|---------|
| `immutablue` | `/usr/bin/` | Main justfile wrapper |
| `immutablue-settings` | `/usr/bin/` | Query settings.yaml values |
| `immutablue-update` | `/usr/bin/` | Update all components |
| `immutablue-doctor` | `/usr/libexec/immutablue/` | System health checks |
| `immutablue-script-orchestrator` | `/usr/bin/` | Scheduled script runner |
| `immutablue-libvirt-manager` | `/usr/bin/` | VM management |
| `immutablue-header.sh` | `/usr/libexec/immutablue/` | Bash utility library |
| `immutablue-backend` | `/usr/bin/` | OS operations (upgrade, rollback, rebase, kargs, package queries) for the image's backend; runtime code calls this, never rpm-ostree/bootc directly |
| `immutablue-linux` | `/usr/bin/` (freebsd-be only) | Linux compatibility: a Fedora/Arch userland in `/compat/linux` for the Linuxulator, `brew` inside it, podman Linux `box`es; no Flatpak (needs namespaces) |

### Justfiles

Located in `/usr/libexec/immutablue/just/`:
- `00-base.justfile` - Core commands (install, update, doctor, etc.)
- `05-hardware-overrides.justfile` - Hardware-specific commands
- Variant-specific justfiles added during build

## Testing

```bash
./tests/run_tests.sh              # Run all tests
./tests/test_shellcheck.sh        # Validate shell scripts
./tests/test_shellcheck.sh --fix  # Show detailed diagnostics
./tests/test_justfile_syntax.sh   # Parse all shipped justfiles
./tests/test_package_presence.sh  # Assert packages.yaml matches the image (per backend)
./tests/test_pkg_resolve.sh       # Logical package resolution per backend
./tests/test_backend_dispatch.sh  # immutablue-backend verbs against stub tools
./tests/test_backend_contract.sh  # Every backend implements the interface
./tests/test_container.sh         # Container validation
./tests/test_artifacts.sh         # Artifact validation
```

### Kuberblue Testing

```bash
make test_kuberblue               # Full Kuberblue test suite
make test_kuberblue_container     # Container validation
make test_kuberblue_components    # Component tests
make test_kuberblue_security      # Security tests
make test_kuberblue_chainsaw      # Declarative Chainsaw tests
```

Chainsaw tests use `*_test.yaml` files co-located with manifests.

## Documentation

Hugo-based docs in `docs/`:

```bash
cd docs && hugo server             # Local preview at :1313
cd docs && hugo build              # Build static site
```

Structure:
- `getting-started/` - Installation, first-boot, quick-start
- `user-guide/` - Package management, updating, maintenance
- `cli-reference/` - All immutablue-* commands
- `system-components/` - Scheduled scripts, systemd, header library
- `variants/` - Variant-specific documentation
- `building/` - Architecture, customization, testing

## The /immutablue agent skill

`artifacts/overrides/usr/share/immutablue/skills/immutablue/` is an agent skill
shipped in the image and symlinked into every agent harness by
`immutablue install_immutablue_skill`. `SKILL.md` is the router; topic guides live
in `references/` and follow the skill file-structure convention: `SKILL.md` links
a guide as `references/<guide>.md`, and guides link each other by bare filename.
Keep the table of guides in `docs/content/user-guide/agent-skill.md` in step when
adding or removing one. A skill-only change needs no image build to verify —
check that every relative link resolves.

### The baseline is maintained

The full review-and-rebaseline procedure is the repo skill
`.claude/skills/skill-update-immutable-skill/` (`/skill-update-immutable-skill` in Claude
Code); its `scripts/drift-report.sh` prints the baseline against the current pins.

`SKILL.md` records, between the `skill-baseline` markers, the commit of
immutablue and of every `deps/` submodule that the skill was last written
against, plus the cmacs commit its cmacs material was checked against. On a
machine, an agent compares that list with `/usr/immutablue/deps/dep_info.json` and
reads whatever changed between the two from source, in either direction. That
only works if the list is honest:

- **Update it in the same commit as the skill change it covers**, along with the
  review date in the start marker.
- **Change a line only for a component whose changes you actually reviewed into
  the skill.** A pin that moved without being reviewed keeps its old line — that
  gap is exactly what the drift check exists to surface. A full review of the
  skill updates every line.
- cmacs is not a submodule — it arrives from `quay.io/zachpodbielniak/cmacs` — so
  its commit is recorded in the prose under the block, not in the list.

The current values, to copy from:

```bash
git rev-parse HEAD
git submodule status deps/ | awk '{sub(/^[-+U ]/, "", $1); print $2, $1}' | sed 's|^deps/||' | column -t
git -C ../cmacs rev-parse HEAD
```

And what a component gained since the skill last covered it — read this before
deciding whether the skill needs more:

```bash
git -C deps/<name> log --oneline <baseline>..HEAD
git -C deps/<name> diff --stat <baseline>..HEAD -- docs '*.org' '*.md'
```

## Code Style

### Shell Scripts

- Shebang: `#!/bin/bash`
- Error handling: `set -euo pipefail` (or `set -euxo pipefail` for build scripts)
- Shellcheck: Strict settings per `.shellcheckrc`
- Variables: Use `local` in functions, quote expansions
- Booleans: Use `TRUE="true"` / `FALSE="false"` constants from header
- Comments: Document functions and complex logic

### Build Script Template

```bash
#!/bin/bash
set -euxo pipefail
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then
    source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"
fi
if [ -f "./99-common.sh" ]; then
    source "./99-common.sh"
fi

# Your build logic here
```

### Settings Access Pattern

```bash
# In scripts that use immutablue-settings
value="$(immutablue-settings .some.setting.path 2>/dev/null)"
if [[ -z "${value}" ]] || [[ "${value}" == "null" ]]; then
    value="default_value"
fi
```

## Common Tasks

### Adding a Package

1. Edit `packages.yaml`
2. Add to `pkg.all` / `pkg_gui` / variant-specific `pkg_<option>` — with `pacman:`/`freebsd:` (or `null`) where the name differs — or to a backend-native list (`rpm*`, `pacman*`, `freebsd*`) if it only makes sense there
3. Rebuild: `make build` (and `make BACKEND=arch-bootc build` if it affects Arch)

### Adding an Override File

1. Place file in `artifacts/overrides/` mirroring target path
2. Example: `artifacts/overrides/etc/myconfig.conf` → `/etc/myconfig.conf`
3. Variant-specific: use `artifacts/overrides_<variant>/`

### Adding a Setting

1. Add to `settings.yaml` with default value and comment
2. Update scripts to read with `immutablue-settings`
3. Document in `docs/content/user-guide/settings.md`

### Creating a Custom Variant

1. Fork [immutablue-custom](https://gitlab.com/immutablue/immutablue-custom)
2. Add packages to `packages/`
3. Add overrides to `artifacts/overrides/`
4. Customize `build/` scripts as needed
5. Build with `make build`
