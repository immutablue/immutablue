# Changing the Image

Read this when the change should be true on every machine, survive updates, or
ship to someone else. On an atomic system this is the *normal* way to change
things, not the advanced one.

The repository is at **https://gitlab.com/immutablue/immutablue**. A copy of the
source every shipped component was built from is on the machine at
`/usr/src/gitlab/`, but the image build itself lives in the repo.

## The build

```bash
make build                    # default Silverblue image
make build SKIP_TEST=1        # skip the pre/post-build tests
make pre_test                 # shellcheck + justfile syntax, before building
make test                     # the full post-build suite
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

Run `git submodule update --init --recursive` after cloning or pulling. The
components under `artifacts/overrides/usr/src/gitlab/` are submodules, and a stale
checkout silently builds the wrong source.

## Adding a package

Edit `packages.yaml` and rebuild. Pick the section by who should get it:

| Section | Who gets it |
|---------|-------------|
| `rpm.all` | every variant |
| `rpm_gui` | every graphical variant |
| `rpm_silverblue`, `rpm_kinoite`, `rpm_sericea`, … | one desktop base |
| `rpm_nucleus`, `rpm_kuberblue`, `rpm_trueblue`, … | one specialised variant |
| `rpm_x86_64`, `rpm_<version>_aarch64` | one architecture |
| `rpm_rm*` | removed from the base image |

There are matching sections for flatpaks, distrobox definitions, brew, pip, and
nix. Version-specific keys (`rpm.43`, `rpm.44`) exist for packages whose name
changes between Fedora releases.

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
justfiles that are concatenated by the wrapper. Add to an existing one or create a
new numbered file; the number controls order, not much else.

Tag related recipes with `[group('name')]` so they list together. Keep the recipe
a thin front end over a script in `/usr/libexec/immutablue/` when there is real
logic — the justfile is the interface, not the place for a hundred lines of bash.

## Build scripts

`build/` runs in alphanumeric order inside the container:

| Script | Stage |
|--------|-------|
| `00-pre.sh` | before anything |
| `10-copy.sh` | overrides and prebuilt deps into the image |
| `20-add-repos.sh` | third-party repos (set to priority 200, below Fedora's 99) |
| `30-install-packages.sh` | package installation, and binaries fetched from releases |
| `40-uninstall-packages.sh` | removals |
| `50-remove-files.sh` | file removals |
| `60-services.sh` | enable/disable/mask units |
| `90-post.sh` | image-info.json, dconf update, cleanup |
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

## Tests

```bash
./tests/run_tests.sh
./tests/test_shellcheck.sh          # strict, per .shellcheckrc
./tests/test_justfile_syntax.sh     # every shipped justfile parses
./tests/test_package_presence.sh    # packages.yaml matches the built image
./tests/test_artifacts.sh           # every override file reached the image intact
./tests/test_container.sh
```

`test_artifacts` compares the working tree against the built image, so **editing
an override after starting a build makes it fail** — that is the test working, not
a flake. Rebuild rather than adjusting the test.

Shell code must be shellcheck-clean; that is enforced, not aspirational.

## Documentation

Docs are a Hugo site in `docs/` (a submodule), with TOML frontmatter. Update them
in the same change as the code:

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
