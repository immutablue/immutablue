# Changing the Image

Read this when the change should be true on every machine, survive updates, or
ship to someone else. On an atomic system this is the *normal* way to change
things, not the advanced one.

The repository is at **https://gitlab.com/immutablue/immutablue**. The components
it builds are git submodules under `deps/`, and the machine records which commit
of each produced the running binaries in
`/usr/immutablue/deps/dep_info.json`.

## The build

```bash
make build                    # default Silverblue image
make build SKIP_TEST=1        # skip the build's prechecks
make pre_test                 # shellcheck + justfile syntax, before building
make test                     # full suite, including prechecks; requires a built image
```

Variants are flags, and they compose:

```bash
make CYAN=1 build             # NVIDIA
make KUBERBLUE=1 build        # Kubernetes node
make TRUEBLUE=1 build         # ZFS + LTS kernel
make CYAN=1 LTS=1 build       # NVIDIA on the LTS kernel
make VERSION=43 build         # a different Fedora base
make PLATFORM=linux/arm64 build
```

`NUCLEUS=1` (headless), `KINOITE=1`/`SERICEA=1` (other desktops), `ASAHI=1`
(Apple Silicon), `NIX=1`, `ZFS=1`, `LTS=1` are the rest.

### Backends: the OS underneath

Immutablue is the configuration and packages on top; the operating system
underneath is a **backend** under `backends/<name>/`, chosen with `BACKEND=`.
This machine's is in `/usr/immutablue/backend` (or `immutablue-backend name`).

| Backend | Base | Packages | Init | Delivered as | Status |
|---------|------|----------|------|--------------|--------|
| `fedora-bootc` | Fedora Atomic | dnf5 | systemd | bootc/ostree | default |
| `gnomeos` | GNOME OS nightly | none | systemd | bootc/composefs | `DISTROLESS=1` is the same build |
| `arch-bootc` | Arch Linux + bootc v1.17.1 | pacman | systemd | bootc/ostree | in-house projects ship (`make BACKEND=arch-bootc build-deps` first); no cmacs yet |
| `freebsd-be` | FreeBSD 15.1 pkgbase | pkg | rc | ZFS boot environment | experimental; builds only on a FreeBSD host |

```bash
make BACKEND=arch-bootc NUCLEUS=1 build   # -> :arch-nucleus
make BACKEND=arch-bootc backend_check     # can this backend do these variants?
```

`make backend_check` (run by `build`) refuses impossible combinations before
podman starts: each `variants/<option>.yaml` lists what it `requires` of the
backend (cyan, asahi, trueblue, LTS, ZFS and the Fedora desktop bases need
`pkg_key: rpm`; kuberblue needs Linux, systemd and rpm). A backend is
`backend.yaml` (facts and `provides` capabilities), `backend.sh` (the build
contract in `backends/lib/interface.sh`), `runtime.sh`, a `Containerfile`, a
`deps.Containerfile`, and optionally `backend.mk`, `stages/` and `overrides/`;
`tests/test_backend_contract.sh` checks each one.

### Cyan (NVIDIA) on Fedora 44+

The image consumes a separate **cyan-deps** container holding two prebuilt
driver stacks, `open` and `580`, each compiled against the *exact* kernel the
image will boot. Build it first, with the same flags as the image:

```bash
make VERSION=44 CYAN=1 build-cyan-deps
make VERSION=44 CYAN=1 build
make VERSION=44 CYAN=1 TRUEBLUE=1 build-cyan-deps   # LTS/Trueblue: kernel-longterm, tag <ver>-cyan-deps-lts
make VERSION=44 CYAN=1 TRUEBLUE=1 build
```

| Knob | Effect |
|------|--------|
| `CYAN_KERNEL_VERSION=<ver-rel.arch>` | skip resolution (`scripts/cyan-kernel-version.sh` reads the base image's `kernel`, or the newest `kernel-longterm` in the kwizart COPR for LTS) |
| `CYAN_DEPS_IMAGE=<ref>` | which cyan-deps the image build pulls; default `quay.io/immutablue/immutablue:<ver>-cyan-deps`, auto-switched to the `-lts` tag under `CYAN=1` + LTS. Pass it explicitly with a custom `IMAGE` |

`deps-container/cyan/` builds each branch in its own stage (`build-stack.sh`), turns
the RPM payload into a sysext tree (`export-stack.sh`) and records
`manifest.json`, `supported-gpus.json` (filtered by `supported-gpus.jq`) and
`requirements.txt`. In the image, the fedora-bootc stage
`backends/fedora-bootc/stages/29-kernel-zfs-nvidia.sh` calls
`75-nvidia.sh install` (same directory) (copies stacks to `/usr/lib/immutablue/nvidia/`, installs
their non-NVIDIA requirements, writes the nouveau/nova/nvidia blacklist and
dracut omit, enables `immutablue-nvidia.service`); `75-nvidia.sh` then finalizes
each stack into a SELinux-labelled squashfs `immutablue-nvidia.raw`, and
`80-initramfs.sh` fails if any GPU module reached the initramfs. Runtime behaviour
is in [`hardware.md`](hardware.md).

| Build error | Fix |
|-------------|-----|
| `rebuild cyan-deps: missing the <branch> NVIDIA stack` | cyan-deps is old or absent: `build-cyan-deps` |
| `<branch> NVIDIA is for <k1>, image kernel is <k2>` | the kernel moved between the two builds: rebuild cyan-deps |
| `selectable NVIDIA drivers require initramfs regeneration` | drop `initramfs` from `SKIP=` |
| `the base image already has an NVIDIA stack` | base ships NVIDIA RPMs; stacks are never mixed |

Fedora 42/43 cyan keeps the old path: one akmod-built `kmod-nvidia` from cyan-deps
installed as RPMs.

Which optional pieces of a component get built is decided by the build packages
in `packages.yaml` under `build_deps` (resolved per backend by
`deps-container/00-build.sh`), and a missing one is dropped quietly rather than
failing. ai-glib needs `gtk4-devel` and `libadwaita-devel` or its `ai-gui` client
and the `org.copyleft.AiGlib.Gui.desktop` launcher are not built, and (0.6.0+, voice)
`gstreamer1-devel` and `gstreamer1-plugins-base-devel`, since a missing
gstreamer `.pc` makes ai-glib's whole `pkg-config --cflags` call fail. podomation
and bacon build ai-glib statically and need the same. When a component's new
feature is absent from the image although its pin moved, look there first.

Run `git submodule update --init --recursive` after cloning or pulling. The
components under `deps/` are submodules, and a stale checkout silently builds the
wrong source.

`deps/` is compiled into the **deps container** (`backends/<backend>/deps.Containerfile`, `make build-deps`; `make BACKEND=arch-bootc build-deps` for Arch) and excluded from the main image's build context. A submodule bump reaches the image only after that dependency container is rebuilt and published. `make build` runs prechecks but does not automatically run the post-build suite; run `make test` separately.

### Artifact provenance

`make build-deps` captures `deps-container/dep_info.json` from the same source context used for compilation and packages it at `/build/dep_info.json`. Uninitialized submodules fail generation rather than borrowing the parent repository's HEAD; dirty dependency checkouts are marked explicitly.

`make build` creates `.image-source.json` for the current image checkout, resolves `DEPS_IMAGE` once with Skopeo, and passes a `repository@sha256:...` reference to the dependency stage. `build/10-copy.sh` merges that artifact's manifest with the image source metadata after applying overrides. The result ships at `/usr/immutablue/deps/dep_info.json`: `.immutablue` describes the image checkout, `.deps` describes the compiled dependency source, and `.dependency_image`, `.dependency_build`, and `.dependency_generated` identify the artifact and its build context. Advancing local pins cannot relabel older dependency binaries.

Older checkouts generated the manifest into `artifacts/overrides/usr/immutablue/deps/`. `make deps_manifest` (run by `make build`) and `make clean` delete that leftover; if `test_artifacts` reports a checksum mismatch on `dep_info.json`, that stale file is why.

**Migration:** rebuild and publish the dependency container before the first main image build using this workflow. Older dependency containers without the manifest fail the image build. Publishing is a separate action; do not infer permission to push from a request to edit or build locally.

```bash
make build-deps
make push-deps                # when publishing is authorized
make build
make test
```

`DEPS_IMAGE` defaults to the configured dependency tag, normally `quay.io/immutablue/immutablue:44-deps`. Supply `DEPS_IMAGE=repository@sha256:<actual-digest>` to reuse a known published artifact without a tag lookup. Resolution failures stop the build before either engine runs. Direct Containerfile builds must provide the digest argument and generate `.image-source.json` themselves.

Fedora host tools for this workflow and its host checks: `bash`, `git`, `jq`, `yq`, `skopeo`, `make`, `ShellCheck`, and `just`, alongside the existing container build tools.

The dependency list includes components a final variant may omit. It does not cover independently supplied cmacs, its bundled libraries, Linuxbrew, RPMs, or external downloads. If cmacs overwrites a dependency file, that file needs cmacs provenance. A dirty checkout cannot be reconstructed from its commit alone; avoid editing source between manifest capture and build-context capture. For older installed manifests without `dependency_image`, verify the binary's originating artifact before trusting local-pin-derived metadata for crash analysis.

## Adding a package

Edit `packages.yaml` and rebuild. Packages are listed by **logical name** under
`pkg*` and resolved per backend: a plain entry is used as-is everywhere, a map
overrides the name only where it differs, `null` means "not on that backend",
and a list installs several packages:

```yaml
pkg:
  all:
  - tmux
  - {name: fuse-sshfs, pacman: sshfs, freebsd: fusefs-sshfs}
  - {name: perf, freebsd: null}
```

Check that an override name exists in that distribution's repository;
`tests/test_pkg_resolve.sh` rejects unknown fields (a typo would silently fall
back to `name`). Pick the section by who should get it:

| Section | Who gets it |
|---------|-------------|
| `pkg.all` | every variant, every backend |
| `pkg_gui` | every graphical variant |
| `pkg_silverblue` (the GNOME desktop on any backend), … | one desktop |
| `pkg_kuberblue`, … | one specialised variant |
| `pkg_x86_64`, `pkg_aarch64`, `pkg_<variant>_<arch>` | one architecture |
| `rpm*` / `pacman*` / `freebsd*` | one backend only (its `pkg_key`), with the same suffixes; Fedora-only variants (`rpm_trueblue`, `rpm_kuberblue.<ver>`, workshop) live here |
| `pkg_rm*`, `rpm_rm*`, … | removed from the base image |

Service lists take the same shape, keyed by init system:
`{name: sshd.service, rc: sshd}`.

Packages that are not in Fedora's repositories have two more routes, keyed the
same way (`rpm_url_<variant>`, `rpm_post_url_<variant>`, `repo_urls_<variant>`):

| Key | Does |
|-----|------|
| `repo_urls*` | adds a `.repo` file (`name:` and `url:` per entry, keyed by Fedora version) before packages install; Trueblue's `znapzend` comes from a COPR this way |
| `rpm_url*` | `dnf5 install <url>` **before** the `rpm` list — for release RPMs such as RPM Fusion |
| `rpm_post_url*` | `dnf5 install <url>` **after** the `rpm` list, for packages that need something from it |

Trueblue's `rpm_post_url_trueblue` installs 45Drives' `cockpit-file-sharing` and
`cockpit-zfs-manager` from pinned GitHub release URLs (neither is in Fedora, and
the 45Drives repo file is Rocky-only), with `znapzend` in `rpm_trueblue` as the
latter's dependency. The URLs are exact versions and move only when someone edits
them; `cockpit-zfs-manager` is archived upstream. A dead URL fails the whole
image build, not just that package.

There are matching sections for flatpaks, distrobox definitions, brew, pip, and
nix. Under each section, `all` applies everywhere; `<version>` (`44`), `all_<arch>`
and `<version>_<arch>` narrow it — see `get_yaml_array` in `build/99-common.sh`.

## Shipping a file

Anything under `artifacts/overrides/` is copied into the image root, mirroring the
target path:

```
artifacts/overrides/etc/myconfig.conf          -> /etc/myconfig.conf
artifacts/overrides/usr/libexec/immutablue/…   -> /usr/libexec/immutablue/…
```

Variant-specific trees exist alongside it: `overrides_cyan/`, `overrides_asahi/`,
`overrides_kuberblue/`, `overrides_trueblue/`, `overrides_nix/`.

This is how scripts, systemd units, justfiles, dconf keyfiles and skills get into
the image. A file placed here is read-only at runtime — which is the point.

## Adding a command

Recipes live in `artifacts/overrides/usr/libexec/immutablue/just/`, in numbered
justfiles pulled in by `import` lines in that directory's `Justfile`. Add to an
existing one, or create a new numbered file **and add its `import`** — a file
without one ships but its recipes are unreachable. Variant justfiles
(`overrides_<variant>/…/10-cyan.justfile` etc.) get their `import` appended by
`build/90-post.sh`.

Tag related recipes with `[group('name')]` so they list together. Keep the recipe
a thin front end over a script in `/usr/libexec/immutablue/` when there is real
logic — the justfile is the interface, not the place for a hundred lines of bash.

## Build scripts

`build/*.sh` are the platform-neutral stages. `backends/lib/run-stages.sh`
merges them by file name with the selected backend's `backends/<backend>/stages/*.sh`
(`build/` first on a tie), drops any listed under `skip_stages` in its
`backend.yaml`, runs each fed to `bash` on stdin (so no arguments), then calls
the backend's `backend_finalize` (fedora-bootc: `ostree container commit`).
Stages never call dnf5, rpm, pacman, pkg, systemctl or sysrc themselves: they
call `backend_pkg_install`, `backend_svc` and the rest, and test
`backend_has <capability>` rather than a backend's name.

| Script | Stage |
|--------|-------|
| `00-pre.sh` | before anything |
| `10-copy.sh` | overrides and prebuilt deps into the image |
| `20-add-repos.sh` | third-party repos (set to priority 200, below Fedora's 99) |
| `29-kernel-zfs-nvidia.sh` *(fedora-bootc)* | udev rules, akmods, LTS kernel, kernel versionlock, ZFS DKMS, `rpm_url`, cyan NVIDIA |
| `30-install-packages.sh` | package installation, and binaries fetched from releases |
| `31-post-urls.sh` *(fedora-bootc)* | `rpm_post_url` |
| `35-mesa-freeworld.sh`, `36-ffmpeg-freeworld.sh` *(fedora-bootc)* | swap in RPM Fusion's full codecs |
| `40-uninstall-packages.sh` | removals |
| `50-remove-files.sh` | file removals |
| `60-services.sh` | enable/disable/mask units |
| `65-crash-capture.sh` | unattended-tier kernel crash policy — [`crash-capture.md`](crash-capture.md) |
| `61-arch-system.sh` *(arch-bootc)* | networking, resolved, timesyncd, GDM: what Fedora presets and Arch does not |
| `75-nvidia.sh` *(fedora-bootc)* | cyan 44+: finalize the NVIDIA sysext images (its `install` phase is called from `29-`) |
| `80-initramfs.sh` | regenerate and verify the initramfs; `SKIP=initramfs` skips it |
| `90-post.sh` | variant justfile imports, image-info.json, dconf update, cleanup |
| `91-fedora-post.sh` *(fedora-bootc)* | release the kernel versionlock, kuberblue RPM Fusion key links |
| `99-common.sh` | shared helpers — **sourced**, not run |

Always source `99-common.sh`, and use `set -euxo pipefail`. That last point has
teeth: a pipeline ending in `grep` exits non-zero when it matches nothing, which
under `-e` aborts the whole build. Append `|| true` where a non-match is legal.

Release URLs and their pinned checksums belong in `99-common.sh` next to the
existing ones, with `_x86_64`/`_aarch64` variants selected by `MARCH`.

## Adding a setting

1. Add the key to `settings.yaml` with its default and a comment.
2. Read it with `immutablue-settings .path.to.key`, handling empty and `null`.
3. Document it in `docs/content/user-guide/settings.md`.

## Producing something bootable

`make build` produces a container image. Everything else is derived from it, and
every one of these refuses on `DISTROLESS=1`:

| Target | Produces |
|--------|----------|
| `make iso` / `make iso-config` | an installer ISO; `anaconda-iso` for the Anaconda flavour |
| `make qcow2` / `make qcow2-config` | a VM disk; `qcow2-config` prompts for user, password, wheel, SSH key |
| `make raw` / `make vhd` / `make vmdk` | disk images for bare metal, Hyper-V, VMware |
| `make ami` / `make gce` | cloud images, with `push_ami` / `push_gce` to upload |
| `make LIMA=1 qcow2 && make lima` | a Lima VM definition; then `lima-start`, `lima-shell`, `lima-stop`, `lima-delete` |
| `make run_qcow2` / `run_iso_qemu` / `run_raw_qemu` | boot the artefact in QEMU locally |

Lima is the quickest way to boot what you just built on the same machine. Output
paths come from `immutablue.gen.*` in `settings.yaml`.

`make build-deps` / `push-deps` rebuild and publish the deps container;
`build-cyan-deps` / `push-cyan-deps` do the NVIDIA stacks (see above), and
`clean-deps` / `clean-cyan-deps` remove them locally. `make sbom` writes a
software bill of materials for the image.

## Tests

```bash
make test                         # same suite as the standalone runner
bash tests/run_tests.sh --list     # inspect selection without running anything
make test_regressions              # host-safe checks, no image or root needed
bash tests/run_tests.sh --suite regressions
./tests/test_shellcheck.sh          # strict, per .shellcheckrc
./tests/test_justfile_syntax.sh     # every shipped justfile parses
./tests/test_package_presence.sh    # packages.yaml matches the built image (per backend)
./tests/test_pkg_resolve.sh         # logical package resolution per backend
./tests/test_backend_contract.sh    # every backend implements the interface
./tests/test_backend_dispatch.sh    # immutablue-backend verbs against stub tools
./tests/test_artifacts.sh           # every override file reached the image intact
./tests/test_container.sh
```

`tests/run_tests.sh` owns the suite registry used by `make test`, `make tests`, and `make run_all_tests`; the default image reference comes from Make, or an explicit image argument. The full suite includes prechecks, regressions, container/package/QEMU/artifact checks, and setup checks. `make pre_test` selects `pre`; individual suite names are `container`, `package_presence`, `container_qemu`, `artifacts`, and `setup`.

Each child script runs in a fresh Bash process. Failures are recorded while later checks continue, and any failure makes the suite exit nonzero. ShellCheck is fatal, without `--report-only`. `SKIP_TEST=1` skips execution consistently; `--list` still lists the selection. Individual checks can skip unavailable dependencies, so inspect their output rather than reading a zero exit status as proof every check executed; setup needs `python3-pyyaml`.

`KUBERBLUE=1` or an image name containing `kuberblue` adds container, component, and security checks. `make test_kuberblue` and `--suite kuberblue` share that selection. Cluster checks require `KUBERBLUE_CLUSTER_TEST=1`; integration additionally requires `KUBERBLUE_INTEGRATION_TEST=1`. Chainsaw is opt-in through `KUBERBLUE_CHAINSAW_TEST=1` or its dedicated Make target.

The host regression suite covers cyan kernel resolution (`test_cyan_kernel.sh`), the NVIDIA selector against fake PCI/config trees (`test_nvidia_selector.sh` — neither proves modules compile or a sysext mounts on real hardware; `tests/nvidia/README.org` lists the manual boot checks), provenance source drift, missing metadata, digest-resolution failures, Make/CLI parity, and failure aggregation. Brew selection uses fixture paths and a fake executable: the production selector uses an absolute brew path, so a shell function named `brew` alone cannot isolate it. Make-variable tests run the fixture's `make` under `env -i`, so neither inherited variant flags (`TRUEBLUE=1` from `make TRUEBLUE=1 all`) nor `MAKEFLAGS` can rewrite the fixture's tag or make it read files it does not carry.

`test_artifacts` compares the working tree against the built image, so **editing
an override after starting a build makes it fail** — that is the test working, not
a flake. Rebuild rather than adjusting the test.

Shell code must be shellcheck-clean; that is enforced, not aspirational.

## Documentation

Docs are a Hugo site in `docs/` (a submodule). Older pages use Markdown with TOML frontmatter; write new documentation in org-mode and update it alongside code. `docs/content/building/provenance-and-tests.org` explains the artifact fields and suite interface in detail.

```bash
cd docs && hugo server        # preview at :1313
```

## Code style

- `#!/bin/bash`, `set -euo pipefail` (`-euxo` for build scripts)
- `local` in functions, quote every expansion
- `TRUE`/`FALSE` constants from the header library
- Comment the reasoning, not the syntax — say why a thing is done the way it is,
  especially where the obvious approach is wrong
- Conventional Commits: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`,
  `build`, with an optional scope

## Downstream images

Immutablue is designed to be built on. `immutablue-custom` is the fork point for a
personal variant; Hyacinth Macaw, Trueblue and Kuberblue are examples of the
pattern. If a change is genuinely personal rather than general, it belongs in a
derivative image rather than in Immutablue itself.
