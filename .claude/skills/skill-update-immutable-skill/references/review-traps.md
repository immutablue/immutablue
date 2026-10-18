# Review traps

Read this before writing any guide text. Each item was a wrong or missing claim
found in a past review of the shipped `/immutablue` skill. Verify every flag,
key, command, path and function name against the component's **source**, not
only its docs — the docs in these repos have been wrong, and the skill repeats
whatever it is told.

## gowl

- **`gowl` has no client mode.** `gowl <word>` parses no positional arguments
  and starts a compositor. Every IPC command is `gowl-msg <word>`; the socket is
  `$XDG_RUNTIME_DIR/gowl.sock`. Upstream docs still write `gowl bar-…` and
  `gowl menu-…` — translate them. Check `src/main.c` (`GOptionEntry` list) if in
  doubt.
- **Opt-in modules.** `macro`, `inputremap`, `menu` and `hints` ship off in
  standalone gowl; the shipped keybinds that reach them (Super+space, Super+q)
  do nothing until `modules: <name>: {enabled: true}`. Say so in the guide, or
  an agent's YAML silently does nothing.
- **Two wlroots versions.** Fedora 42/43 builds against wlroots 0.19, 44+
  against 0.20. A feature can exist on one and not the other — check
  `AGENTS.md`, *gowl and the two wlroots versions*.

## cmacs embedding gowl

- **`cmacs --gowl` reads `~/.config/gowl/config.yaml` and `config.c`.** The
  load is in cmacs `src/emacs.c`, gated by `evaluate_gowl_config_with_cmacs` and
  `evaluate_c_config_with_cmacs`, both default true. A compositor started later
  from Elisp with `gowl-start` reads neither. Some cmacs and gowl docs claim the
  YAML is "never read" under `--gowl`; they are wrong.
- **`(gowl-reload-config)` with no argument resets to built-in defaults** and
  reads no file. To re-read the YAML, pass its path.
- **cmacs never calls `gowl_config_ready()`**, and loads `macro`/`inputremap`
  from Elisp on first use, not from YAML.
- **The macro stop key under cmacs is Super+Alt+Escape**; Super+Escape is its
  menu.

## Versions and what the image ships

- **cmacs pins its own copies** of ai-glib, bacon, podomation, gsurf, gowl and
  others. The manual under `/usr/share/emacs/*/doc_org/cmacs/deps/<dep>/`
  follows *cmacs's* pin, not immutablue's. `scripts/drift-report.sh` prints
  both lists; record the differing cmacs pins in the prose under the baseline
  block, and say in the guide when a feature exists only in the standalone
  binary.
- **What reaches the image** is decided by `deps-container/00-build.sh` (build
  flags, `PREFIX=/usr`), the component's own `install` target, and
  `build/10-copy.sh`. Copy order: `artifacts/overrides/`, then the deps
  artifacts, then cmacs — and podomation and bacon are copied **after** cmacs,
  overwriting cmacs's bundled modules. Check that a binary, data file or `/etc`
  file is installed before telling an agent to use it.
- **Use image paths.** Upstream docs default to `PREFIX=/usr/local`; the image
  installs under `/usr/share/…`, `/usr/lib64/…`.

## Immutable-OS fit

- Anything that updates or installs itself into `/usr` is wrong on the machine:
  ai-glib's self-updater (`ai --update` reports unavailable), `make install-*`,
  `dnf install`, `pip install` into the system. The guide must say "update the
  image" (or a user-scope alternative), never work around the read-only `/usr`.
- Never suggest `bootc usr-overlay` without saying it must be asked about first.

## Justfiles and the header library

- A `NN-*.justfile` needs an `import` line in
  `artifacts/overrides/usr/libexec/immutablue/just/Justfile`; variant files get
  theirs from `build/90-post.sh`. List the recipes with
  `just -f artifacts/overrides/usr/libexec/immutablue/just/Justfile --list` and
  check every recipe the skill names.
- Every `immutablue_*` header function the skill names must exist in
  `artifacts/overrides/usr/libexec/immutablue/immutablue-header.sh`.

## C examples in the guides

- Write them against the real signatures in the component's `src/**/*.h`, and
  mirror a shipped example (`data/*.c`, `data/macros/*.c`) where one exists.
- Keep them gnu89, tab-indented, warning-free with `-Wall -Wextra`, and include
  every header they use (`<linux/input-event-codes.h>` for `KEY_*`, `BTN_*`).
