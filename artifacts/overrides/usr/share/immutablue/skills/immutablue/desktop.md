# The Desktop: gowl, cmacs, and the Bar

Read this before changing the compositor, the status bar, keybindings, or the
editor-as-window-manager session.

Immutablue ships more than one session and they are genuinely different systems:

- **GNOME on Wayland** — the conventional session. Configure it through dconf; see
  [`configuration.md`](configuration.md).
- **gowl** — a wlroots compositor written against GLib, embedded inside **cmacs**
  (a GNU Emacs fork). In this session Emacs is the window manager.

Check which one is running before advising:

```bash
echo "${XDG_CURRENT_DESKTOP}"
```

## gowl configuration

Two mechanisms that work together, lowest precedence first:

1. built-in defaults
2. **YAML** config — declarative, covers the standard settings
3. **C** config — a compiled module, for programmatic control; runs after the
   YAML and overrides it
4. command-line arguments

Both can be used at once. Config lives under `~/.config/gowl/`. The C path exists
because the compositor is a GLib program and the config is real code — for
anything nontrivial it is preferred over a large declarative blob.

## Compositor modules

gowl's features are GModule `.so` plugins loaded at runtime, each a GObject
subclass of `GowlModule` implementing compositor interfaces. The shipped set
covers layouts (tile, monocle, fibonacci, scrolling, centeredmaster), effects
(blur, alpha, roundcorners, animation, magnifier, cube), and behaviour
(scratchpad, swallow, dropdown, expo, switcher, screenlock, screenshot,
recording, ipc, mcp).

Source is on the machine at `/usr/src/gitlab/gowl/modules/`, with the development
guide in `/usr/src/gitlab/gowl/docs/modules.org`.

## Bar plugins

The bar (`gowlbar`) is a plugin host: left/centre/right regions with a centre
anchor, dropdown **panels** that a plugin *describes* while the host renders and
hit-tests them, and **toasts** on the overlay layer that can name a panel.

```
~/.config/gowl/bar-plugins/        # user plugins — yours to edit
```

A plugin is a `GowlBarPluginVTable` of plain C functions, loaded either as a
compiled `.so` or as a `.c` file compiled through **crispy** (cmacs's embedded
C-like scripting language) and cached. **Only the vtable form hot-reloads**,
because a GType cannot be unregistered — this is the single most important thing
to know before writing one.

Two rules for a plugin that is meant to be shipped rather than local:

- **Colours are theme *roles*** resolved from the session palette. A plugin that
  hard-codes hex fails the source guard.
- **Containment is the invariant.** Plugins run in-process, so every entry point
  runs under `gowl_bar_guard_call`, which catches SIGSEGV/BUS/FPE/ILL/ABRT,
  unwinds, quarantines the plugin and raises a toast.

When a plugin kills the session anyway, the quarantine journal is what stops the
next start from loading it and crashing again:

```bash
cat "${XDG_STATE_HOME:-$HOME/.local/state}/gowl/bar-plugins.journal"
```

Read that first when diagnosing a compositor crash — see
[`crash-analysis.md`](crash-analysis.md).

Never edit a shipped plugin under `/usr`. Copy it into
`~/.config/gowl/bar-plugins/` and edit the copy; the user directory is what
survives an image update.

## cmacs

cmacs is a GNU Emacs fork that embeds GLib/GObject, the compositor, AI, and a
browser as C primitives. Relevant entry points:

| Command | What it does |
|---------|--------------|
| `cmacs --gowl` | start the compositor session, Emacs as window manager |
| `cmacs --bacon` | the embedded shell (fork-of-self mode) |
| `emacsctl` / `cmacsctl` | kubectl-style CLI over the D-Bus surface |

Subsystems are `--with-cmacs-*` gated at build time. What is actually compiled in
is authoritative at runtime rather than guessable:

```bash
emacsctl instances
```

Relevant subsystems include `gowl` (compositor), `bacon` (shell), `crispy` (C
scripting), `ai` and `ai-brigade` (agents, over ai-glib), `mcp` (an MCP server for
runtime introspection and control), `gsurf` (embedded browser), `whisper`/`piper`
(STT/TTS), and `podomation` (event-driven automation).

Full source and docs are on the machine:

```bash
ls /usr/src/gitlab/          # gowl, gst, gsurf, ai-glib, bacon, crispy, podomation, ...
```

`gst` is the terminal (a GLib/GObject port of suckless `st`); `gsurf` is the
browser (a port of `surf`).

## Dictation

voxtype ships in GUI variants. Setup, the Super+D keybinding, and the reason the
typing backend differs between GNOME and gowl are covered by:

```bash
immutablue enable_dictation
immutablue dictation_status
```

The short version: `wtype` speaks `wlr-virtual-keyboard-v1`, which gowl implements
and Mutter does not, so under GNOME voxtype falls through to `ydotool`, which
needs `ydotool.service` running.

## What not to do

- Do not edit anything under `/usr/src/gitlab/` expecting it to affect the running
  system — that is the *source* the image was built from, not the live config.
  Reading it is the point; changing it does nothing until the image is rebuilt.
- Do not edit shipped modules or plugins in place. Copy into `~/.config/gowl/`.
- Do not assume GNOME advice applies to gowl, or the reverse. Check
  `XDG_CURRENT_DESKTOP` first.
