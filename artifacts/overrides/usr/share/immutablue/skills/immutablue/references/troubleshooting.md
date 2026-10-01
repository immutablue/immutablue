# Troubleshooting: Start Here

A symptom-first index across the whole system. Find the row, run the first
check, then read the guide it points at — each component guide has its own
Troubleshooting section with the detail.

## Method

Five habits that settle most problems before a theory is needed:

1. **Establish what this machine is.** `immutablue sysinfo` and
   `echo "$XDG_CURRENT_DESKTOP"`. Advice for GNOME is wrong for gowl, and
   advice for one variant is wrong for another.
2. **Ask the system.** `immutablue doctor_json` returns structured health for
   ostree, disk, network, services, flatpak, brew, distrobox and crash capture.
3. **Read the log that already exists.** `journalctl -b -p warning`,
   `journalctl --user -b --grep <program>`, and each program's own log (gowl's
   `log-file`, cmacs's `*Messages*` and `*Warnings*` via `emacsctl logs`).
4. **Bisect the configuration.** Every in-house program starts without its
   config: `--no-yaml-config` and `--no-c-config` for gowl, gowlbar, gst and
   gsurf; `--no-modules` for gsurf. If the problem goes away, it is the config.
5. **Check which file actually won.** Every program searches several
   locations and uses the first hit; C config runs after YAML and overrides it.
   A change to the "wrong" file is the most common reason a change does nothing.

Immutablue's own documentation is installed too, as markdown under
`/usr/immutablue/docs/content/` — the same pages as the website, matching this
image. `rg -l <term> /usr/immutablue/docs/content` finds the relevant one.

For how an installed cmacs component behaves, the manual under
`/usr/share/emacs/*/doc_org/cmacs/` matches the installed build — read it
before answering from memory. See [`cmacs.md`](cmacs.md).

## System

| Symptom | First check | Guide |
|---|---|---|
| Update failed, or stopped half-way | `immutablue deployments`; `journalctl -b -u rpm-ostreed` | [`updates.md`](updates.md) |
| Broken after an update | roll back the image **and** restore the `/var` snapshot | [`updates.md`](updates.md) |
| An update is blocked by a layered package | `rpm-ostree status` — remove the layer | [`packages.md`](packages.md) |
| "dnf: command not found" / cannot install | use the decision tree, not `dnf` | [`packages.md`](packages.md) |
| A setting is ignored | `immutablue-settings <key>` prints the value that won | [`configuration.md`](configuration.md) |
| A service is not running | `systemctl status <unit>`, `immutablue doctor` | [`configuration.md`](configuration.md) |
| A scheduled or update hook did not run | `journalctl --user -u immutablue-<mode>.service`; hooks run as `bash - < script`, `.ignore` skips | [`automation.md`](automation.md) |
| First-boot wizard did not run, or should run again | markers in `/etc/immutablue/setup/`; `immutablue initial_setup` | [`automation.md`](automation.md) |
| A program crashed | `immutablue crashes`, `immutablue analyze_crash` | [`crash-analysis.md`](crash-analysis.md) |
| The whole machine froze or rebooted itself | there is no coredump; `immutablue crash_capture_status`, `logs_since_last_boot` | [`crash-capture.md`](crash-capture.md) |
| VMs will not start | `immutablue status_libvirt`; SELinux relabel recipe | [`hardware.md`](hardware.md) |
| Video stutters, battery drains in the browser | `vainfo` | [`hardware.md`](hardware.md) |
| Black screen or no NVIDIA driver on a cyan (Fedora 44+) image | `immutablue nvidia_status`; `journalctl -b -u immutablue-nvidia.service` | [`hardware.md`](hardware.md) |
| An always-on machine suspended anyway | the sleep targets are not masked | [`hardware.md`](hardware.md) |
| Image build fails | `make pre_test` first; then the failing build script's output | [`building.md`](building.md) |

## Desktop and applications

| Symptom | First check | Guide |
|---|---|---|
| gowl / cmacs session returns straight to the login screen | `journalctl --user -b --grep gowl`; stale `WAYLAND_DISPLAY` in `systemctl --user show-environment` | [`gowl.md`](gowl.md) |
| A gowl keybind, rule or effect change does nothing | `gowl --check-config`; `~/.config/gowl/gowl.log`; `config.c` overrides YAML | [`gowl.md`](gowl.md) |
| Super+space menu / Super+q hints do nothing in standalone gowl | the `menu` / `hints` module is not enabled | [`gowl.md`](gowl.md) |
| A gowl macro is refused, held back, or freezes the desktop | `gowl-msg macro-status`; `macro-compile NAME` | [`gowl-macros.md`](gowl-macros.md) |
| A foot pedal / macro pad remap does nothing | `gowl-msg inputremap-devices` — is it claimed? is the module loaded? | [`gowl-macros.md`](gowl-macros.md) |
| Locked out after the lock screen crashed | from a TTY or SSH: `gowl-msg unlock` | [`gowl.md`](gowl.md) |
| A compositor module does not load, or loads and does nothing | "enabled but .so not found" in the log; `activate()` must return `TRUE` | [`gowl.md`](gowl.md) |
| An Electron app forgets its login under gowl | `echo $XDG_CURRENT_DESKTOP` must end in `:GNOME` | [`gowl.md`](gowl.md) |
| A bar widget is missing | `gowl-msg bar-widgets`, `gowl-msg bar-plugins` — unknown widget names are skipped silently | [`gowl-bar.md`](gowl-bar.md) |
| A bar plugin disappeared after a crash | `gowl-msg bar-quarantined`, then the plugin journal | [`gowl-bar.md`](gowl-bar.md) |
| No password dialog for a privileged action under gowl | `systemctl --user status immutablue-polkit-agent.service` | [`desktop.md`](desktop.md) |
| Dictation does not type | `immutablue dictation_status` — the typing backend differs by session | [`desktop.md`](desktop.md) |
| `immutablue enable_dictation`: recipe not found | the image predates the `09-dictation` import; `just -f /usr/libexec/immutablue/just/09-dictation.justfile …` | [`desktop.md`](desktop.md) |
| cmacs will not start, or `init.c` has no effect | `cmacs --debug-init`; the `*Warnings*` buffer | [`cmacs.md`](cmacs.md) |
| A cmacs feature is missing | `emacsctl describe instance` lists what this build has | [`cmacs.md`](cmacs.md) |
| Terminal font, colours, keys or images wrong | run `gst` from another terminal and read its stderr | [`gst.md`](gst.md) |
| Browser keys go to the page, or a module does nothing | under cmacs: Escape returns focus to Emacs; `(cmacs-gsurf-modules-list)` | [`gsurf.md`](gsurf.md) |
| `ai --update` or ai-tui `/update` says "unavailable" | expected: an image build has no checkout and `/usr` is read-only | [`packages.md`](packages.md) |
| A podomation config or `.pod` does nothing | `podomation validate FILE`, then `podomation simulate FILE` | [`automation.md`](automation.md) |
| A scheduled `/loop` or `/goal` never fires | `ai loop list` (is its session running?); `AI_LOOP_DISABLE` | [`automation.md`](automation.md) |
| gowl keybinds and rules vanished after a reload in cmacs | `(gowl-reload-config)` with no argument resets to defaults; pass the YAML path | [`cmacs.md`](cmacs.md) |
| `ai` uses the wrong provider or model | `immutablue ai_defaults` shows what resolved and from where | [`configuration.md`](configuration.md) |
| The agent does not know about this system | `immutablue install_immutablue_skill`; `ls -l ~/.agents/skills/immutablue` | this skill |

## Troubleshooting docs already on the machine

Under `/usr/share/emacs/*/doc_org/cmacs/`:

| Component | File |
|---|---|
| ai-brigade agents | `ai-brigade/troubleshooting.org` — no tools, "no such agent", interrupted tasks, memory search, relay, mailbox |
| AI in cmacs | `cmacs-ai.org`, Troubleshooting section; `deps/ai-glib/providers/ollama.org`, `claude-code.org` |
| libreclaw | `libreclaw/troubleshooting.org`, `deps/libreclaw/debugging.org` (log levels, verbose logging) |
| bacon | `deps/bacon/troubleshooting.org` — `--dump-tokens`, `--dump-ast`, symptom → cause → fix |
| crispy | `deps/crispy/scripting.org` — Known issues, Debugging with GDB |
| gsurf in cmacs | `cmacs-gsurf.org`, Troubleshooting section |
| audio, whisper, piper, video, lrgterm | the Troubleshooting section of `cmacs-audio.org`, `cmacs-whisper.org`, `cmacs-piper.org`, `cmacs-video.org`, `cmacs-lrgterm.org` |
| KVM / input capture | `deps/gowl/input-capture.org`, Troubleshooting section |
| building cmacs | `build.org`, Known Issues |

## When it is Immutablue's fault

If the cause is in the image — a shipped file, a recipe, a build script, a
default — read [`reporting.md`](reporting.md) before filing, and gather what it
asks for first.
