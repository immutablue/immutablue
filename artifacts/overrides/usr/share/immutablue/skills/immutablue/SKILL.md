---
name: immutablue
description: >
  REQUIRED for any work on a machine running Immutablue, Hyacinth Macaw, Trueblue,
  Kuberblue or another Immutablue variant. Use when installing software, changing
  system configuration, updating or rolling back the OS, diagnosing a crash or a
  service failure, customizing the gowl/cmacs desktop, or changing the image build
  itself. Triggers: rpm-ostree, bootc, ostree, atomic, Silverblue, immutable,
  /usr is read-only, rpm-ostree install, layering, flatpak, distrobox, brew,
  immutablue-doctor, immutablue-update, immutablue-snapshot, rollback, rebase,
  deployment, coredump, segfault, "why did X crash", packages.yaml, settings.yaml,
  artifacts/overrides, gowl, gowlbar, bar plugin, cmacs, dictation, voxtype.
  Covers reporting a confirmed Immutablue bug.
---

# Immutablue

Immutablue is a Fedora Atomic (bootc/OSTree) image builder and the OS it produces.
This skill is for working **on a machine running it**, and for changing the image
itself.

Two things make it different from a normal Fedora box, and almost every mistake
comes from forgetting one of them:

1. **`/usr` is read-only and is replaced wholesale on every update.** A change
   written there is either impossible or lost at the next reboot.
2. **The image is built from a git repository**, not assembled on the machine. The
   durable way to change the system is to change the build and rebuild.

## Before doing anything else

Read what this machine actually is. Variants differ a great deal — Nucleus is
headless, Kuberblue is a Kubernetes node, Trueblue adds ZFS and the LTS kernel — and advice for
one is wrong for another.

```bash
immutablue sysinfo                      # variant, tag, deployment, hardware
cat /usr/share/immutablue/image-info.json
rpm-ostree status                       # or: bootc status
```

## Topic guides

The guides live in `references/` beside this file. Read only the one the task needs.

This skill is always installed at `/usr/share/immutablue/skills/immutablue/`. If your harness has not told you this skill's directory, resolve the paths below against that: `references/packages.md` is `/usr/share/immutablue/skills/immutablue/references/packages.md`. The guides link to each other by bare filename, relative to `references/`.

- [`references/configuration.md`](references/configuration.md) — settings.yaml cascade, `/etc` vs `/usr`, dconf defaults, what is safe to edit
- [`references/packages.md`](references/packages.md) — installing software, and the decision tree that keeps you off `rpm-ostree install`
- [`references/updates.md`](references/updates.md) — updating, `/var` snapshots, deployment rollback, rebasing between variants
- [`references/desktop.md`](references/desktop.md) — the gowl compositor, cmacs, gowlbar plugins, dictation
- [`references/crash-analysis.md`](references/crash-analysis.md) — analysing a coredump and deciding whether Immutablue is at fault
- [`references/building.md`](references/building.md) — changing the image: packages.yaml, overrides, build scripts, variants, tests
- [`references/reporting.md`](references/reporting.md) — filing an Immutablue bug that can actually be acted on

## Critical rules

**Never write to `/usr`.** It is read-only at runtime and replaced on update.
Reading it is safe and encouraged — `/usr/immutablue/` holds the settings and
package defaults, `/usr/libexec/immutablue/` the scripts and justfiles, and
and `/usr/immutablue/deps/dep_info.json` records the exact commit and remote of
every component this image builds from git.

**Never suggest `dnf install`.** There is no `dnf` on the host in the sense that
matters. See [`references/packages.md`](references/packages.md) for what to do instead; the answer is
usually a flatpak, a distrobox, or a change to the image.

**`rpm-ostree install` is a last resort, not a first answer.** It creates a layered
deployment that must be rebuilt on every OS update, slows every future update, and
can block one entirely when a dependency stops resolving. Recommend it only when
nothing else fits, and say what it costs.

**Prefer changing the image over changing the machine.** A change to
`packages.yaml` or `artifacts/overrides/` survives updates and reaches every
machine built from the image. A change made on one machine does not.

**Do not run `bootc usr-overlay` without asking.** It makes `/usr` transiently
writable and is a debugging tool, not a deployment mechanism.

## Where things live

| Path | What it is | Writable? |
|------|-----------|-----------|
| `/usr/immutablue/` | `settings.yaml`, `packages.yaml`, image defaults | no |
| `/usr/libexec/immutablue/` | scripts, justfiles, header library | no |
| `/usr/share/immutablue/` | `image-info.json`, skills, dconf examples | no |
| `/usr/immutablue/deps/dep_info.json` | commit + remote of every in-house component | no |
| `/etc/immutablue/` | system-level setting overrides | yes |
| `~/.config/immutablue/` | user-level setting overrides | yes |
| `/var/`, `~/` | all mutable state | yes |

## The command surface

`immutablue` is a wrapper around the justfiles in
`/usr/libexec/immutablue/just/`. It is not a binary with subcommands, so
`immutablue --help` is not the way in:

```bash
immutablue                  # list every recipe
immutablue choose           # pick one interactively
just --list -f /usr/libexec/immutablue/just/Justfile
```

Read a recipe before running it — they are plain justfiles and the source is the
documentation:

```bash
grep -A 30 '^recipe_name' /usr/libexec/immutablue/just/*.justfile
```

Only some recipes carry a `[group(...)]` tag — currently `agents`, `rollback` and
`dictation`. The rest are ungrouped and appear in the flat listing, so do not
assume a group exists for a topic: list the recipes and read the names.

Recipes are spread across numbered justfiles, and that numbering is the map:
`00-base` (install, update, doctor, services), `03-power`, `05-hardware-overrides`,
`06-crash-capture`, `07-agents`, `08-rollback`, `09-dictation`. Variant images add
their own (`10-cyan`, `25-asahi`, `30-kuberblue`).

## Diagnosis first

```bash
immutablue doctor            # ten check groups
immutablue doctor_verbose    # with detail
immutablue doctor_json       # machine-readable, for an agent to parse
immutablue doctor_fix        # apply the fixes it knows how to make
```

`doctor` covers ostree status, disk space, network, flatpak, distrobox, brew,
system and user services, crash capture, and variant-specific checks. Run it
before forming a theory: it answers most "why is this broken" questions directly,
and `doctor_json` is the cheapest way for an agent to get structured system state.

## Deciding what kind of change you are making

1. **A setting Immutablue already exposes?** → `/etc/immutablue/settings.yaml` or
   `~/.config/immutablue/settings.yaml`. See [`references/configuration.md`](references/configuration.md).
2. **Installing software?** → the decision tree in [`references/packages.md`](references/packages.md).
   Flatpak, brew and distrobox come before layering.
3. **Something that should be true on every machine you build?** → change the
   image. See [`references/building.md`](references/building.md).
4. **Desktop, compositor or bar behaviour?** → [`references/desktop.md`](references/desktop.md).
   gowl config is YAML plus optional C; bar plugins are cloned into
   `~/.config/gowl/bar-plugins/`, never edited in place under `/usr`.
5. **Something crashed?** → [`references/crash-analysis.md`](references/crash-analysis.md).
6. **Broken after an update?** → [`references/updates.md`](references/updates.md). Deployment rollback
   and `/var` snapshot restore are separate recoveries and a bad update usually
   wants both.

## Common requests

| Request | Answer |
|---------|--------|
| "Install `<gui app>`" | `flatpak install` — see [`references/packages.md`](references/packages.md) |
| "Install `<cli tool>`" | `brew install`, or a distrobox; layering last |
| "Install a build dependency" | Do not. Add it to `packages.yaml` and rebuild — [`references/building.md`](references/building.md) |
| "Enable/disable a service" | `systemctl` for now; `packages.yaml` `services_*` to make it stick |
| "Change a GNOME default" | dconf — [`references/configuration.md`](references/configuration.md) |
| "Undo the last update" | `immutablue rollback`, and consider `immutablue restore_snapshot` |
| "Move to the NVIDIA/LTS/ZFS variant" | `immutablue rebase` — [`references/updates.md`](references/updates.md) |
| "Why did `<program>` crash?" | [`references/crash-analysis.md`](references/crash-analysis.md) |
| "Add a package to the image" | `packages.yaml` — [`references/building.md`](references/building.md) |
| "Ship a config file in the image" | `artifacts/overrides/` — [`references/building.md`](references/building.md) |
| "Report this as a bug" | [`references/reporting.md`](references/reporting.md) |
