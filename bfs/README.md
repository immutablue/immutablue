# Blue From Scratch (BFS)

**Status: Experimental / Scaffold**

BFS is Immutablue's path to a truly distroless build. Instead of layering on top of Fedora Silverblue or GNOME OS, BFS compiles the entire OS from source using [BuildStream](https://buildstream.build/) and [freedesktop-sdk](https://freedesktop-sdk.io/) as the base toolchain.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   OCI Image (bootc)                  │
│           containers.bootc=1, ostree.bootable=1      │
├─────────────────────────────────────────────────────┤
│                 Immutablue Layer                     │
│  overrides, scripts, justfiles, systemd units, etc.  │
├─────────────────────────────────────────────────────┤
│              Application Components                  │
│  podman, distrobox, neovim, fzf, tmux, stow, etc.   │
├─────────────────────────────────────────────────────┤
│              GNOME Desktop Stack                     │
│  (from freedesktop-sdk + gnome-build-meta junction)  │
├─────────────────────────────────────────────────────┤
│               Boot Infrastructure                    │
│        kernel, ostree, bootc, dracut, composefs      │
├─────────────────────────────────────────────────────┤
│              freedesktop-sdk (base)                  │
│    glibc, gcc, systemd, mesa, wayland, glib, etc.    │
└─────────────────────────────────────────────────────┘
```

## How It Works

1. **freedesktop-sdk** provides the foundational toolchain (glibc, GCC, coreutils, systemd, mesa, etc.) -- all compiled from source, no distro packages
2. **BuildStream** orchestrates the entire build in reproducible sandboxes -- each component builds in isolation with only its declared dependencies
3. **Custom elements** build the boot infrastructure (kernel, ostree, bootc, dracut, composefs) and application stack (podman, neovim, fzf, etc.)
4. **OCI output** via BuildStream's `oci` plugin produces a bootc-compatible container image
5. The image can be deployed via `bootc install` to bare metal, VM, or used with the existing `distroless-img` target

## Relationship to Existing Builds

| Build Path | Base | Package Manager | Build Tool | Trigger |
|------------|------|-----------------|------------|---------|
| Standard | Fedora Silverblue | rpm-ostree/dnf | Containerfile | `make build` |
| GNOME OS distroless | GNOME OS nightly | None (static binaries) | Containerfile | `make DISTROLESS=1 build` |
| **BFS** | **freedesktop-sdk** | **None (source-compiled)** | **BuildStream** | **`make DISTROLESS=1 bfs`** |

BFS does **not** replace the existing build paths. The standard Containerfile build remains the primary, production path. BFS is an experimental alternative for maximum control over the package set.

## Prerequisites

```bash
# BuildStream (available as RPM on Fedora)
sudo dnf install buildstream bubblewrap fuse3

# OCI plugin (needed for image export)
pip install buildstream-plugins-community

# BuildStream execution backends
# These are typically bundled with the buildstream RPM, but if not:
# https://buildstream.build/install.html
# - buildbox-casd
# - buildbox-fuse
# - buildbox-run-bubblewrap
```

## Usage

```bash
# Build the full BFS image
make DISTROLESS=1 bfs

# Track latest upstream source versions
make DISTROLESS=1 bfs-track

# Show build status of all elements
make DISTROLESS=1 bfs-status

# Build and export as OCI image (for podman/bootc)
make DISTROLESS=1 bfs-export-oci

# Export raw filesystem tree (for inspection)
make DISTROLESS=1 bfs-export-tree

# Open a debug shell inside the build sandbox
make DISTROLESS=1 bfs-shell

# Clean BFS output
make bfs-clean
```

## Directory Structure

```
bfs/
├── project.conf                 # BuildStream project configuration
├── build.sh                     # Build orchestration script
├── README.md                    # This file
├── elements/
│   ├── freedesktop-sdk.bst      # Junction to freedesktop-sdk
│   ├── base/                    # Boot infrastructure
│   │   ├── kernel.bst           # Linux kernel from source
│   │   ├── systemd.bst          # Init system (from fdo-sdk)
│   │   ├── ostree.bst           # Atomic OS updates
│   │   ├── bootc.bst            # Boot via containers
│   │   ├── dracut.bst           # Initramfs generator
│   │   └── composefs.bst        # Read-only FS composition
│   ├── components/              # Application stack
│   │   ├── gnome-desktop.bst    # GNOME desktop environment
│   │   ├── podman.bst           # Container engine
│   │   ├── distrobox.bst        # Container-based dev envs
│   │   ├── cli-tools.bst        # CLI tool aggregation
│   │   ├── neovim.bst           # Text editor
│   │   ├── fzf.bst              # Fuzzy finder
│   │   ├── tmux.bst             # Terminal multiplexer
│   │   └── stow.bst             # Symlink farm manager
│   ├── immutablue/              # OS composition
│   │   ├── image.bst            # Top-level composition (everything)
│   │   ├── filesystem.bst       # ostree directory layout
│   │   ├── os-release.bst       # OS identification
│   │   └── overrides.bst        # Immutablue configs/scripts
│   └── oci/
│       └── immutablue-bfs.bst   # OCI image output
├── files/                       # Static files for import elements
│   ├── os-release/
│   │   ├── etc/os-release
│   │   └── usr/share/immutablue/image-info.json
│   └── repart-config/           # Partition layout (future)
├── patches/                     # Source patches (if needed)
└── plugins/                     # Custom BuildStream plugins (if needed)
```

## Current Status

This is a **scaffold** -- the BuildStream element definitions are in place but source refs need to be tracked (`bst source track`) and some elements need additional work:

- **Working**: Project structure, element dependency graph, Makefile integration, build script
- **Needs work**: Source ref pinning, kernel config tuning, GNOME desktop junction (gnome-build-meta), Rust toolchain for bootc
- **Future**: Initramfs generation, NVIDIA module support, ARM64 cross-compilation

## How GNOME OS Does It (Reference)

GNOME OS uses the same approach: BuildStream + freedesktop-sdk, compiled from source, deployed via ostree. The key difference is they don't use bootc -- they use ostree directly with systemd-repart for disk images. BFS adds bootc on top for container-native updates.

## Disk Space Warning

Building from source requires significant disk space. The BuildStream CAS (Content-Addressed Storage) cache grows as artifacts are built:

- freedesktop-sdk full build: ~50-100 GB cache
- BFS full build (on top): additional ~10-30 GB
- Remote caching can reduce this significantly

## References

- [BuildStream Documentation](https://docs.buildstream.build/)
- [freedesktop-sdk](https://freedesktop-sdk.io/)
- [gnome-build-meta](https://gitlab.gnome.org/GNOME/gnome-build-meta)
- [bootc Image Layout](https://bootc-dev.github.io/bootc/bootc-images.html)
- [ostree container encapsulate](https://coreos.github.io/rpm-ostree/container/)
