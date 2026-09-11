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

gowl's features are GModule `.so` plugins, each a GObject subclass of
`GowlModule` exporting one symbol, `gowl_module_register()`, which returns the
type. The shipped set (`gowl --list-modules`) covers layouts (tile, monocle,
float, scrolling, centeredmaster, fibonacci), effects (animation, cube, expo,
switcher, magnifier, blur), and behaviour (autostart, scratchpad, swallow,
pertag, movestack, vanitygaps, copyhighlight, ipc, mcp).

How they load is worth knowing precisely, because it is **not** how bar plugins
load:

- Only modules with `enabled: true` under `modules:` in the YAML are loaded.
  `tile`, `monocle` and `float` are on unless explicitly disabled.
- Each is found as `<name>.so` in `<exe-dir>/modules/` (a development tree) and
  then `/usr/lib64/gowl/modules/`. That is the whole search path on the shipped
  binary — `gowl --help` prints it. There is no home-directory module scan, no
  `.c` compilation, and no load/unload/reload IPC for compositor modules.
- Loading happens once, at startup, before the compositor object exists. A new
  or rebuilt `.so` means restarting the session. `reload_config` (the IPC
  module) and `M-x gowl-reload-config` reload *configuration*, not modules.

There is no per-user module directory. A `.so` under `~/.local` or `~/.config`
is never picked up as a compositor module, whatever an older guide may say;
`gowl --help` on the machine prints the two directories that are searched.

### The C config: crispy in your home directory

The supported way to run your own compositor C code from `$HOME` is
`~/.config/gowl/config.c`. At startup `GowlConfigCompiler` compiles it through
**crispy** to a `.so` cached by content hash in `$XDG_CACHE_HOME/gowl/`, dlopens
it, and calls `gowl_config_init()`; after the compositor is up it calls the
optional `gowl_config_ready()`. Compile failure logs a warning and falls back to
the YAML config, so a broken `config.c` does not lock you out.

```bash
gowl --generate-c-config > ~/.config/gowl/config.c     # a commented template
gowl --recompile                                       # compile only, report errors, exit
gowl --no-c-config                                     # boot without it
```

Extra compiler flags go in the source: `#define CRISPY_PARAMS "$(pkg-config
--cflags --libs json-glib-1.0)"` — shell expansion runs at compile time. Inside,
`extern GowlCompositor *gowl_compositor; extern GowlConfig *gowl_config;` are
resolved at dlopen. `gowl_config_init` runs before the compositor starts, so
treat `gowl_compositor` as usable only from `gowl_config_ready`. Precedence is
built-in < YAML < C < CLI, so C wins over YAML.

```c
#include <gowl/gowl.h>
#include <xkbcommon/xkbcommon.h>

G_MODULE_EXPORT gboolean
gowl_config_init(void)
{
	g_object_set(gowl_config, "border-width", 3, "mfact", 0.60, NULL);
	gowl_config_add_keybind_full(gowl_config, GOWL_KEY_MOD_LOGO, XKB_KEY_Return,
	                             GOWL_ACTION_SPAWN, "gst", "Terminal");
	return TRUE;
}
```

"Reloading" a C config is: edit, `gowl --recompile` to check it builds, restart
the session. The cache means an unchanged file never recompiles.

The source of gowl is not on the machine — it is built in the deps container.
`/usr/immutablue/deps/dep_info.json` records the remote and exact commit; clone
that when you need the headers, `docs/modules.org`, `docs/configuration.org`, or
`data/example-bar-plugin.c`:

```bash
remote=$(jq -r '.deps[] | select(.name=="gowl") | .remote' /usr/immutablue/deps/dep_info.json)
commit=$(jq -r '.deps[] | select(.name=="gowl") | .commit' /usr/immutablue/deps/dep_info.json)
git clone "${remote}" /tmp/gowl && git -C /tmp/gowl checkout "${commit}"
```

## The bar

The bar (`gowlbar`) is a plugin host: left/centre/right regions with a centre
anchor, dropdown **panels** that a plugin *describes* while the host renders and
hit-tests them, and **toasts** on the overlay layer that can name a panel.

### Configuring it

```yaml
modules:
  bar:
    enabled: true
    height: 30
    widgets-left: "tags title"
    widgets-center: "clock"
    widgets-right: "cpu memory disk:/var battery network audio"
    center-anchor: "clock"
```

Each list is space separated and ordered. The **right** region reads outward —
the first entry ends up furthest right, as in every dwm-descended status list.
`center-anchor` names one widget to centre on the monitor, with the rest of the
centre region packing around it; without it the centre is centred as a group and
the clock slides whenever a neighbour appears.

A widget spec is `name`, `name:parameter` or `name:parameter@seconds` —
`disk:/var`, `weather:Berlin@600`, `cmd:~/bin/pomo@5`. The interval uses the
**last** `@`, so `cmd:ssh me@host@30` parses as intended. The whole spec is the
widget's identity, so two `disk:` widgets on different mounts are separately
addressable.

Per-widget settings live in the same block, either as `<widget>-color` (a palette
role or hex) or `<widget>.<key>`:

```yaml
    cpu-color: green
    clock.format: "%a %b %d  %H:%M"
    network.ping-host: "1.1.1.1"
```

**The shipped layout is replaced, not added to.** With no configuration the bar
shows a default layout — tags and title left, clock anchored centre,
`cpu memory disk battery tailscale` right. The *first* configuration that names
any widget list clears that wholesale, **including regions it does not mention**.

This matters on upgrade: a configuration written before regions existed sets only
`widgets:`, and that list usually ends with a clock — if the shipped centre clock
survived, the bar would show the time twice. A pre-regions configuration also
gets `tags title` put back on its left, because the bar it was written for drew
those unconditionally rather than listing them. After that first configuration
the bar is incremental again: setting only `widgets-right` leaves left and centre
alone.

### Make and reload a bar plugin in five steps

This is the thing that *does* live in your home directory, load as a crispy `.c`
file or a prebuilt `.so`, and hot-reload:

```bash
# 1. start from the shipped example (clone gowl as above if /tmp/gowl is absent)
mkdir -p ~/.config/gowl/bar-plugins
cp /tmp/gowl/data/example-bar-plugin.c ~/.config/gowl/bar-plugins/pomo.c

# 2. load it into the running bar, by path or by name
gowl bar-plugin-load ~/.config/gowl/bar-plugins/pomo.c
gowl bar-plugin-load pomo                 # resolved through the search path

# 3. put it on the bar -- an unknown widget name is silently skipped, so spell it right
#    ~/.config/gowl/config.yaml -> modules: bar: widgets-right: "pomo clock battery"

# 4. edit, then swap the new build in without restarting anything
gowl bar-plugin-reload pomo

# 5. when it misbehaves
gowl bar-quarantined                      # held back after a caught signal?
cat "${XDG_STATE_HOME:-$HOME/.local/state}/gowl/bar-plugins.journal"
gowl bar-plugin-unload pomo
```

The same commands exist as `M-x gowl-bar-plugin-load`, `gowl-bar-plugin-reload`,
`gowl-bar-plugin-unload`, `gowl-bar-plugin-clear`, and `gowl-bar-plugins` inside
cmacs. Make it persistent by naming it in `plugins:` (see "Where plugins are
found"); otherwise it is gone at the next session start. A `.so` you built
yourself goes in the same directory and loads the same way — compiled beats
source when both exist under one name.

### Writing a plugin

Copy `data/example-bar-plugin.c` from the gowl tree into
`~/.config/gowl/bar-plugins/` — it is a complete commented pomodoro timer with a
panel. A plugin is a `GowlBarPluginVTable` of plain C function pointers plus a
`GowlBarPluginDesc`, published by a `gowl_bar_plugin_query()` export. Every slot
may be `NULL`; the minimum viable plugin is a `poll` that calls
`gowl_bar_plugin_set_label()`, and it gets measurement, drawing, hover and the
panel machinery for free.

`size` must be the first member and must be `sizeof` the struct **as your file
sees it**. That is what lets the vtable grow without breaking a plugin built
against an older gowl: the bar checks each callback lies inside the declared size
before calling it.

**The threading rule matters more than everything else here.** Plugins run
in-process inside the compositor, and the compositor's dispatch thread holds the
lock every editor primitive needs:

| Callback | Thread | May do |
|----------|--------|--------|
| `poll`, `draw`, `measure`, `click`, `scroll`, `panel`, `action` | dispatch | read `/proc`, arithmetic, the setters |
| `poll_async` | worker | subprocesses, network, slow file reads |

Blocking the dispatch thread freezes **the editor**, not just the bar — spawning
a process or touching the network there is the mistake to watch for. From
`poll_async` only `set_label()`, `set_icon()`, `set_color()` and `set_tooltip()`
are thread-safe. For a subprocess in response to a click use
`gowl_bar_plugin_spawn()` (fire-and-forget) or `gowl_bar_plugin_queue_work()`.

**Name a colour role, never a hex literal.** `GOWL_BAR_COLOR_PEACH` follows a
theme switch; `#fab387` does not. Shipped plugins are held to this by a source
guard.

A plugin may also decide whether it belongs at all — the shipped `tailscale`
widget hides itself where Tailscale is not installed, and carries a set-up flow
where it is installed but no tailnet has been joined.

### Where plugins are found

There is a search path, not a single directory. In order of precedence:

1. the `plugin-dir` setting (`plugin-path` is a synonym) — colon-separated, so a config may name several
2. `$GOWL_BAR_PLUGIN_DIR` — what a development tree wants
3. `~/.config/gowl/bar-plugins` (`$XDG_CONFIG_HOME`)
4. `~/.local/share/gowl/bar-plugins` (`$XDG_DATA_HOME`)
5. `/usr/local/share/gowl/bar-plugins` and `/usr/share/gowl/bar-plugins`

**A configured directory adds to the path rather than replacing it**, so naming
one does not cost the user the plugins already in `~/.config`. Every directory is
scanned at startup in name order, each at most once however often the path is
rebuilt.

```yaml
modules:
  bar:
    plugin-dir: "~/src/mybar/plugins:/opt/gowl/plugins"
    plugins: "weather stocks"        # bare names, resolved against the path
    widgets-right: "weather clock battery"
```

A bare name resolves to `<name>`, then `<name>.so`, then `<name>.c` in each
directory in turn. **Compiled beats source in the same directory** — the object
is what was last built, and quietly preferring the source would recompile over
the top of it. A spec containing `/` is a path, taken as written and never
searched, so an explicitly named plugin cannot be shadowed by a same-named one
earlier in the path. When nothing matches, the error names every directory it
looked in.

`plugins` is read **before** the widget lists, so a plugin named there is
registered by the time `widgets-right` mentions it. This ordering is load-bearing:
an unknown widget name is *silently skipped* rather than erroring — right for a
typo, wrong for a plugin that merely had not loaded yet. A `plugins` entry that
does not resolve warns and names the directories searched, because a plugin asked
for by name and not delivered should not have to be discovered as an empty space
on the bar.

That asymmetry is the first thing to check when a widget does not appear: a
missing *widget* is quiet, a missing *plugin* is loud.

### Loading and reloading

```bash
gowl bar-widgets                    # the laid-out bar, per slot and region
gowl bar-plugins                    # what is registered
gowl bar-plugin-load ~/x/thing.c    # load one now, by path
gowl bar-plugin-load weather        # ...or by name, through the search path
gowl bar-plugin-reload pomodoro     # recompile and swap in an edit
gowl bar-plugin-unload pomodoro     # drop it
gowl bar-quarantined                # what is held back, and why
gowl bar-plugin-clear pomodoro      # let a held-back plugin load again
```

A `.c` file is compiled through **crispy** to a shared object cached on a hash of
its contents and flags, so an unchanged source loads without invoking the
compiler. Extra compiler flags go in the source itself:

```c
#define CRISPY_PARAMS "$(pkg-config --cflags --libs json-glib-1.0)"
```

Unloading drops the plugin from the registry and every instance of it, but the
shared object **stays mapped** — unmapping code a queued worker may still point
into is how a hot-unload becomes a crash somewhere unrelated. This is also why
the vtable form is the one to use: a `GType` cannot be unregistered, so a plugin
defining its own class can be dropped but a recompiled version cannot re-register
the same class name. Only the vtable form hot-reloads.

### Containment

Plugins run in-process, so every entry point runs under `gowl_bar_guard_call`,
which catches SIGSEGV/BUS/FPE/ILL/ABRT, unwinds, quarantines the plugin and
raises a toast. When a plugin kills the session anyway, the load journal is what
stops the next start from loading it and crashing again:

```bash
cat "${XDG_STATE_HOME:-$HOME/.local/state}/gowl/bar-plugins.journal"
gowl bar-quarantined
```

Read those first when diagnosing a compositor crash — see
[`crash-analysis.md`](crash-analysis.md).

Never edit a shipped plugin under `/usr`. Copy it into
`~/.config/gowl/bar-plugins/` and edit the copy — that directory comes *before*
`/usr/share/gowl/bar-plugins` in the search path, so a copy under the same name
shadows the shipped one, and it is what survives an image update. The image's own
plugins live in the system directory precisely so a user copy can win.

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
jq -r '.deps[].name' /usr/immutablue/deps/dep_info.json
```

`gst` is the terminal (a GLib/GObject port of suckless `st`); `gsurf` is the
browser (a port of `surf`).

## Polkit under gowl

GNOME Shell registers its own polkit authentication agent; a bare wlroots session
does not, so without one every GUI action needing authorisation — `pkexec`,
system Flatpak installs, virt-manager reaching the system libvirt socket — fails
with no dialog and no obvious cause. Immutablue ships `mate-polkit` and starts it
from `immutablue-polkit-agent.service`, a user unit bound to `gowl-session.target`
rather than `graphical-session.target`, so it runs only in gowl sessions and never
competes with GNOME's agent.

```bash
systemctl --user status immutablue-polkit-agent.service
```

A "permission denied" with no password prompt under gowl is this unit not
running, before it is anything to do with libvirt or Flatpak.

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

- Do not expect a clone of one of these components to affect the running system.
  It is the *source* the binary was built from, not the live config; changing it
  does nothing until the deps container and the image are rebuilt.
- Do not edit shipped modules or plugins in place. Copy into `~/.config/gowl/`,
  which precedes the system directories in the plugin search path.
- Do not tell someone to drop a compositor module `.c` file in `~/.config/gowl/`
  and expect it to load. That path is for *bar* plugins. A compositor module is a
  `.so` in the system module directory, enabled in YAML, loaded at session start;
  the home-directory C hook for the compositor itself is `config.c`.
- Do not assume GNOME advice applies to gowl, or the reverse. Check
  `XDG_CURRENT_DESKTOP` first.
