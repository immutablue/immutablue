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
  artifacts/overrides, gowl, gowl-msg, gowlbar, bar plugin, gowl macro, input
  remap, foot pedal, macro pad, gowl menu, macro-record, floatdesk, broadcast,
  pointer confine, bar widget, ai-call, ai project, emacs --lrg, VR headset,
  Steam Frame, cmacs-mcp, cmacs, gsurf, gst, NVIDIA, cyan,
  dictation, voxtype, gabbrev, espanso, text expansion, snippet, abbreviation,
  hotkey, AutoHotkey, hotstring, CapsLock layer, tag transition, workspace
  animation, menu-choose, JSON-RPC, wire protocol, screencast, screen share,
  restore token, voice loop, wake word, voice command, hand tracking,
  SpaceMouse, ai benchmark, ai decide, gsurf adblock, uBlock, EasyList, filter
  list, freebsd-be, FreeBSD, bectl, boot environment, deliver.sh,
  builder-vm.sh, install-disk.sh, GELI, raidz, mirror.
  Covers reporting a confirmed Immutablue bug.
---

# Immutablue

Immutablue is a Fedora Atomic (bootc/OSTree) image builder and the OS it produces.
The same configuration also builds on other bases (backends): Arch Linux with bootc
(`arch-bootc`) and FreeBSD with ZFS boot environments (`freebsd-be`), where some
commands differ. `cat /usr/immutablue/backend` says which one you are on.
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
grep -E '^(PRETTY_NAME|VARIANT_ID)=' /etc/os-release
rpm-ostree status                       # or: bootc status
```

`/etc/os-release` names the image on anything built from immutablue `d280d3a`
or later: `Kuberblue 44 (Nucleus)`, `Immutablue 44 (Silverblue, Trueblue)`,
`Immutablue Arch (GNOME)`. Older images say `Immutablue <ver> (Silverblue)`
whatever the variant — trust `image-info.json` and the tag there. `ID` stays
`fedora` on Fedora-based images.

## Skill baseline — maintained

This skill is kept in step with specific commits: immutablue's own, and every
component the image builds from source. They are recorded here and updated
whenever the skill is — the rule is in `AGENTS.md` in the immutablue
repository. The machine you are on may run an image built from newer *or older*
components; `/usr/immutablue/deps/dep_info.json` records the image source and dependency artifact's source separately. Its dependency entries are not an inventory of every installed binary; cmacs and its bundled components need their own provenance.

When something here does not match what you see, or you are asked about a
feature this skill does not cover, check how far the image and the skill have
drifted before answering:

<!-- skill-baseline:start — reviewed 2026-10-30; update with the skill, see AGENTS.md -->
```bash
# CHANGED = the image and this skill were written against different commits.
while read -r name base; do
    image=$(jq -r --arg n "${name}" 'if $n == "immutablue" then .immutablue.commit else (.deps[] | select(.name == $n) | .commit) end // empty' /usr/immutablue/deps/dep_info.json)
    if [[ -z "${image}" ]]; then state="not recorded"
    elif [[ "${image}" == "${base}" ]]; then state="same"
    else state="CHANGED"; fi
    printf '%-20s %-13s skill=%.12s image=%.12s\n' "${name}" "${state}" "${base}" "${image}"
done <<'EOF'
immutablue           5c0c1f44b6dafb720fe2ea59c7df9b6bbb4874e1
ai-glib              02678e0e24cc91cae9c44244b66d2ea212ed8dfa
bacon                f0a1c596cd454e2063b7d1149a50327eaf8c861e
crispy               9b9ec4eeffb2bd84e76b91cd9196133e79fc8344
gowl                 11a1d63de9713f02b11dca061cb179502eb1fb44
gst                  118d542dba9d0c6f6a29fa5b540713a11476269d
gsurf                268fb3069b5611d07f1fb0104ca8075330a49803
mcp-gdb-glib         626ee15456e15b37254dcfe0482e5e35586ee4a9
mcp-glib             80611856d89e322ee6c41a22104d496bc8158eda
mcp-kuberblue-glib   a11bcc211e7ccebd24c412a551e73fb396b7faa8
podomation           5fa9ec8b4061d9ef8042de4bda72a9f7701e53de
yaml-glib            46baefcef3285c74eb4155f40e993c9a13ec1fa7
EOF
```
<!-- skill-baseline:end -->

Every line was fully reviewed on 2026-10-29: each component's changes since the previous baseline were read from source and written into the guides. Of note: the freebsd-be backend grew up — the in-house projects and cmacs under `/usr/local`, patched ports (ConsoleKit2, so the GNOME lock screen unlocks), podman storage on its own dataset, `deliver.sh` always pulling with progress, an installer with mirror/raidz layouts and GELI full-disk encryption, and `make FREEBSD=1` running in the builder VM ([building](references/building.md), [updates](references/updates.md), [desktop](references/desktop.md)); gowl's tag transitions, JSON-RPC wire protocol, screen-sharing portal, `menu-choose`, and the new [gabbrev](references/gowl-gabbrev.md) text expander and [hotkey](references/gowl-hotkey.md) module; gsurf's local-file addresses and uBlock/EasyList filter lists; cmacs's voice loop, camera, hand tracking and SpaceMouse; ai-glib's `ai decide` backends and `ai benchmark`. crispy, mcp-glib, yaml-glib, bacon and podomation changed for FreeBSD portability (plus podomation's Linux-only `fs_mount` noted in [automation](references/automation.md)); mcp-gdb-glib and mcp-kuberblue-glib did not change.

A second review the same day brought immutablue itself up to `d280d3a` (no `deps/` pin or cmacs moved): arch-bootc gained `LTS`/`ZFS`/`TRUEBLUE` through ArchZFS and `KUBERBLUE` at the current Fedora release's Kubernetes minor; os-release is now generated per image (name, release and variant); derived images finish with `backend_finalize_derived`; trueblue's `zfs-arc-max` works for the first time; and `immutablue rebase` offers only the running backend's bootable tags (images before `2686025` list every tag); gowl moved only to `11a1d63`, a wlroots 0.19 build fix with no behaviour change on 0.20 ([building](references/building.md), [updates](references/updates.md), [packages](references/packages.md), [troubleshooting](references/troubleshooting.md)).

A review on 2026-10-30 brought immutablue up to `5c0c1f4` and cmacs to `b7b8656` (no `deps/` pin moved). On freebsd-be each machine now chooses its login screen — gdm, with GNOME's lock screen, or LightDM, which also offers the gowl and CMacs Wayland sessions but under which GNOME cannot lock (Super+L says so) — in the installer or with `immutablue display_manager`; Wi-Fi works through firmware packages, `immutablue_wlan` and the networkmgr/wifimgr pickers; `immutablue_drm` loads the GPU's DRM driver; the installer creates the first user; and the ISO is a hybrid that boots when `dd`'d to a USB stick. cmacs's two commits only ship `cmacs.desktop` in the FreeBSD image ([desktop](references/desktop.md), [building](references/building.md), [recipes](references/recipes.md), [troubleshooting](references/troubleshooting.md)).

For manifests with `dependency_image`, `.deps` comes from the digest-pinned dependency container, while `.immutablue` identifies the main image checkout. Older manifests were generated from that checkout's submodules and can misidentify binaries from a separately built dependency container. Do not treat a missing entry as proof that a component is absent, or replace an artifact's recorded commit with a newer local submodule pin. See [the build guide](references/building.md) for migration and scope.

cmacs is not in `dep_info.json`: it arrives from the cmacs container image, not a
`deps/` submodule. The cmacs material in this skill was checked against cmacs
`b7b8656deec28f0917860a8cddd4a54a9d71902f` (reviewed 2026-10-30). The manual
installed under `/usr/share/emacs/*/doc_org/cmacs/` matches the installed cmacs
and what it links in — read that rather than diffing. Its `deps/<dep>/` docs
follow **cmacs's own submodule pins**, which differ from immutablue's: at this
review cmacs pinned ai-glib `02678e0e24cc`, bacon `f0a1c596cd45`, podomation
`5fa9ec8b4061` and gowl `fa0d3e1be4bb` (the same as immutablue), but crispy
`8116b9cf705c`, mcp-glib `ccad2035d84f`, yaml-glib `e8de6ef29a4b` and gsurf
`f9d2b0bd421e` (all behind immutablue's). The standalone `ai`, `ai-tui`,
`podomation`, `bacon` and `gsurf` come from immutablue's `deps/` and can be ahead
of or behind that manual — see [`references/cmacs.md`](references/cmacs.md).

For a component marked CHANGED, read the difference from its source at both
commits. The recorded remotes are SSH URLs; clone over https unless the machine
has keys. For immutablue itself use `https://gitlab.com/immutablue/immutablue.git`.

```bash
d=gowl; base=<its commit in the list above>
remote=$(jq -r --arg d "$d" '.deps[] | select(.name == $d) | .remote' /usr/immutablue/deps/dep_info.json)
image=$(jq -r --arg d "$d" '.deps[] | select(.name == $d) | .commit' /usr/immutablue/deps/dep_info.json)
git clone --filter=blob:none "${remote/git@gitlab.com:/https://gitlab.com/}" "/tmp/drift/$d"
cd "/tmp/drift/$d"
git log --oneline "$base..$image"           # in the image, not in this skill: learn it from source
git log --oneline "$image..$base"           # in this skill, not in the image: this machine lacks it
git diff --stat "$base" "$image" -- docs '*.org' '*.md'
```

Drift runs both ways, and both matter. A newer image can have features this
skill has never heard of: answer from the component's docs *at the image's
commit*, and say the skill is behind. An older image may lack something the
skill describes: check `git log "$image..$base"` before telling anyone to use it.
Either way the skill lives under `/usr` and is not edited on the machine — the
fix is an update to the skill in the immutablue repository.

## Topic guides

The guides live in `references/` beside this file. Read only the one the task needs.

This skill is always installed at `/usr/share/immutablue/skills/immutablue/`. If your harness has not told you this skill's directory, resolve the paths below against that: `references/packages.md` is `/usr/share/immutablue/skills/immutablue/references/packages.md`. The guides link to each other by bare filename, relative to `references/`.

- [`references/troubleshooting.md`](references/troubleshooting.md) — **start here when something is broken**: symptom → first check → guide, across the whole system
- [`references/configuration.md`](references/configuration.md) — settings.yaml cascade, `/etc` vs `/usr`, dconf defaults, what is safe to edit
- [`references/packages.md`](references/packages.md) — installing software, and the decision tree that keeps you off `rpm-ostree install`
- [`references/updates.md`](references/updates.md) — updating, `/var` snapshots, deployment rollback, rebasing between variants
- [`references/desktop.md`](references/desktop.md) — which session is running, polkit under gowl, dictation, and a map of the desktop guides
- [`references/gowl.md`](references/gowl.md) — configuring gowl (YAML and C), keybinds, rules, outputs, tag transitions, the menu, `gowl-msg` and the JSON-RPC wire protocol, screen sharing/screenshot portal, and writing and loading compositor modules
- [`references/gowl-macros.md`](references/gowl-macros.md) — gowl macros (crispy C run in the compositor, triggers, filters) and per-device input remapping (foot pedals, macro pads)
- [`references/gowl-bar.md`](references/gowl-bar.md) — the bar: layout, widgets, and writing, loading and hot-reloading plugins
- [`references/gowl-gabbrev.md`](references/gowl-gabbrev.md) — text expansion (gabbrev, espanso-compatible): matches, variables, built-ins like `;today`, the expand key, usage and learning
- [`references/gowl-hotkey.md`](references/gowl-hotkey.md) — AutoHotkey for gowl: hotkeys, remaps, CapsLock layers, modes, contexts, hotstrings, timers, C scripts
- [`references/cmacs.md`](references/cmacs.md) — configuring cmacs (`init.el`, `init.c`, `init.bacon`), and the manuals installed on the machine
- [`references/gst.md`](references/gst.md) — configuring gst, the terminal
- [`references/gsurf.md`](references/gsurf.md) — configuring gsurf, the browser, standalone and inside cmacs
- [`references/crash-analysis.md`](references/crash-analysis.md) — analysing a coredump and deciding whether Immutablue is at fault
- [`references/building.md`](references/building.md) — changing the image: packages.yaml, overrides, build scripts, variants, tests
- [`references/reporting.md`](references/reporting.md) — filing an Immutablue bug that can actually be acted on
- [`references/recipes.md`](references/recipes.md) — every `immutablue` recipe, by justfile, including the variant ones
- [`references/automation.md`](references/automation.md) — scheduled and event hooks, the update hooks, the bash header, `immutablue-settings`, profile.d, first-boot
- [`references/hardware.md`](references/hardware.md) — libvirt, video acceleration, suspend, hardware overrides, print-to-cmacs, NVIDIA driver selection on cyan, variant hardware recipes
- [`references/crash-capture.md`](references/crash-capture.md) — the *kernel* crash policy: panics, watchdog, netconsole; distinct from coredump analysis

## Critical rules

**Never write to `/usr`.** It is read-only at runtime and replaced on update.
Reading it is safe and encouraged — `/usr/immutablue/` holds the settings and
package defaults, `/usr/libexec/immutablue/` the scripts and justfiles, and
`/usr/immutablue/deps/dep_info.json` records source metadata for the image and the submodules compiled into its dependency artifact.

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
| `/usr/immutablue/docs/content/` | Immutablue's full documentation, as markdown, matching this image | no |
| `/usr/share/emacs/*/doc_org/cmacs/` | the cmacs manual and the manuals of everything it embeds | no |
| `/usr/immutablue/deps/dep_info.json` | image source, dependency artifact digest, and dependency source commits | no |
| `/etc/immutablue/` | system-level setting overrides | yes |
| `/etc/immutablue/scripts/{system,user}/<mode>/` | your hook scripts: `on_boot`, `daily`, `pre_update`, … | yes |
| `/etc/immutablue/setup/` | first-boot completion markers (`did_first_boot_setup`, …) | wheel |
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
[`references/recipes.md`](references/recipes.md) is that list with a line per recipe.

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

When `doctor` is clean and something is still wrong, go to
[`references/troubleshooting.md`](references/troubleshooting.md): it maps symptoms across the
system, the desktop and every in-house program to a first check and the guide
with the detail.

## Deciding what kind of change you are making

1. **A setting Immutablue already exposes?** → `/etc/immutablue/settings.yaml` or
   `~/.config/immutablue/settings.yaml`. See [`references/configuration.md`](references/configuration.md).
2. **Installing software?** → the decision tree in [`references/packages.md`](references/packages.md).
   Flatpak, brew and distrobox come before layering.
3. **Something that should be true on every machine you build?** → change the
   image. See [`references/building.md`](references/building.md).
4. **Desktop, compositor or bar behaviour?** → [`references/gowl.md`](references/gowl.md) for the compositor,
   [`references/gowl-bar.md`](references/gowl-bar.md) for the bar, [`references/cmacs.md`](references/cmacs.md) for the editor.
   Configuration is YAML plus optional crispy C in `~/.config/<program>/`; nothing is
   ever edited in place under `/usr`. For how any cmacs component works, read the
   manual installed at `/usr/share/emacs/*/doc_org/cmacs/` before answering from memory.
5. **Something crashed?** → [`references/crash-analysis.md`](references/crash-analysis.md).
6. **Broken after an update?** → [`references/updates.md`](references/updates.md). Deployment rollback
   and `/var` snapshot restore are separate recoveries and a bad update usually
   wants both.
7. **Something should run on a schedule, at boot, or around an update?** → a script in
   `/etc/immutablue/scripts/`, not a hand-written timer. [`references/automation.md`](references/automation.md).
8. **The whole machine froze or rebooted itself?** → [`references/crash-capture.md`](references/crash-capture.md),
   not crash-analysis; there is no coredump for a kernel panic.

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
| "Write / reload a bar plugin" | `~/.config/gowl/bar-plugins/`, `gowl-msg bar-plugin-reload` — [`references/gowl-bar.md`](references/gowl-bar.md) |
| "Write a gowl compositor module" | a `GowlModule` `.so`, loaded from `config.c` or `CMACS_GOWL_MODULE_DIR` — [`references/gowl.md`](references/gowl.md) |
| "Change a gowl keybind / rule / effect" | `~/.config/gowl/config.yaml`, then `gowl --check-config` — [`references/gowl.md`](references/gowl.md) |
| "Query or drive the running gowl session from a script" | `gowl-msg` (`clients`, `focused`, `action`, `-s` for events) — [`references/gowl.md`](references/gowl.md) |
| "Add something to the Super+space menu" | `~/.config/gowl/menu.yaml` overlay — [`references/gowl.md`](references/gowl.md) |
| "Expand `;today`" / "text expander" / "use my espanso config" | `modules: gabbrev:` + a `gabbrev:` section — [`references/gowl-gabbrev.md`](references/gowl-gabbrev.md) |
| "AutoHotkey on Linux" / "CapsLock as a layer" / "hotkey that works in a fullscreen game" | `modules: hotkey:` + a `hotkey:` section — [`references/gowl-hotkey.md`](references/gowl-hotkey.md) |
| "Change the workspace switch animation" | `tag-transition:` + `modules: <name>:`, Super+: — [`references/gowl.md`](references/gowl.md) |
| "Drive gowl from a program" / "JSON-RPC" | `gowl-msg -c METHOD`, `gowl-msg -d` — [`references/gowl.md`](references/gowl.md) |
| "Screen share is black / pick what to share / stop an app recording without asking" | the gowl portal; `$XDG_STATE_HOME/gowl/screencast-grants.yaml` — [`references/gowl.md`](references/gowl.md) |
| "Talk to the desktop / hands-free commands / dictation in cmacs" | the voice loop and spoken commands — [`references/cmacs.md`](references/cmacs.md) |
| "Camera, hand gestures, SpaceMouse" | [`references/cmacs.md`](references/cmacs.md), *Camera, hand gestures and the SpaceMouse* |
| "Compare models / typed decisions" | `ai benchmark`, `ai decide` — [`references/configuration.md`](references/configuration.md), [`references/packages.md`](references/packages.md) |
| "Block ads in gsurf" | `modules: adblock:` with `filter_lists:` — [`references/gsurf.md`](references/gsurf.md) |
| "Open a local HTML file in the browser" | `gsurf ./file.html` — [`references/gsurf.md`](references/gsurf.md) |
| "Update / roll back a FreeBSD (freebsd-be) machine" | `immutablue-backend upgrade` / `rollback` (boot environments) — [`references/updates.md`](references/updates.md) |
| "Build a freebsd-be image from Linux / install to several disks / encrypted" | `make FREEBSD=1 …` runs in the builder VM; `install-disk.sh`, the ISO — [`references/building.md`](references/building.md) |
| "Write a gowl macro" / "run X when a window opens" | `~/.config/gowl/macros/NAME.c`, `modules: macro:` triggers — [`references/gowl-macros.md`](references/gowl-macros.md) |
| "Remap a foot pedal / macro pad / one mouse" | `modules: inputremap:` + `input-remap:`, `gowl-msg inputremap-identify` — [`references/gowl-macros.md`](references/gowl-macros.md) |
| "Record / replay a macro" / "run a macro by voice" | Super+Alt+r, Super+Alt+m (needs `modules: macro:`) — [`references/gowl-macros.md`](references/gowl-macros.md) |
| "Float windows like a normal desktop" / "multibox" / "keep the pointer in a game" | `floatdesk-toggle`, `broadcast-*`, Super+g — [`references/gowl.md`](references/gowl.md) |
| "Add one widget to the bar" / "which bar widgets exist" | `widgets-right-add:`, the extended widget set — [`references/gowl-bar.md`](references/gowl-bar.md) |
| "Package not in Fedora" / "a dep's feature is missing from the image" | `rpm_url*`, `rpm_post_url*`, `repo_urls*`; deps container `-devel` packages — [`references/building.md`](references/building.md) |
| "Run cmacs in a VR headset / Steam Frame" | `emacs --lrg=3dvr`, `M-x cmacs-lrg-vr-describe` — [`references/cmacs.md`](references/cmacs.md) |
| "Talk to the AI by voice" / `ai-call` | needs your own STT/TTS service — [`references/automation.md`](references/automation.md) |
| "List my AI projects / sessions" | `ai project [--json]` — [`references/automation.md`](references/automation.md) |
| "NVIDIA not working / switch NVIDIA driver" | `immutablue nvidia_status`, `immutablue nvidia_setup` — [`references/hardware.md`](references/hardware.md) |
| "Configure cmacs" / "where is the cmacs manual" | `M-x cmacs-manual`, `/usr/share/emacs/*/doc_org/cmacs/` — [`references/cmacs.md`](references/cmacs.md) |
| "Change the terminal font / colours / keys" | `~/.config/gst/config.yaml` — [`references/gst.md`](references/gst.md) |
| "Configure the browser" | `~/.config/gsurf/config.yaml`, or Elisp under cmacs — [`references/gsurf.md`](references/gsurf.md) |
| "Open a site as its own app window / launcher" | `gsurf --kiosk URL`, `gsurf --pwa [--pwa-name NAME] URL` — [`references/gsurf.md`](references/gsurf.md) |
| "Browse gopher:// or gemini://" | standalone `gsurf` (the cmacs-embedded copy is older) — [`references/gsurf.md`](references/gsurf.md) |
| "Update ai" / "`ai --update` fails" | expected on an image — update the image — [`references/packages.md`](references/packages.md) |
| "When X happens, do Y" / "watch a container registry" | podomation — [`references/automation.md`](references/automation.md) |
| "Repeat this prompt every N minutes" / "keep going until the tests pass" | `/loop`, `/goal`, `ai loop` — [`references/automation.md`](references/automation.md) |
| "Run this every day / at boot / before updates" | `/etc/immutablue/scripts/…` — [`references/automation.md`](references/automation.md) |
| "Enable VMs" | `immutablue enable_libvirt` — [`references/hardware.md`](references/hardware.md) |
| "Video is stuttering / battery dies in the browser" | VA-API check — [`references/hardware.md`](references/hardware.md) |
| "Machine hard-locks / reboots by itself" | [`references/crash-capture.md`](references/crash-capture.md) |
| "Re-run first-boot setup" | `immutablue initial_setup` — [`references/automation.md`](references/automation.md) |
