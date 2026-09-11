# The gowl Bar and Its Plugins

The bar you see in a gowl session is a **compositor module** (`bar`), not a
separate program. Extending it means writing a *plugin*: C that lives in your
home directory, loads as crispy-compiled `.c` source or a prebuilt `.so`, and
hot-reloads without restarting anything. Compositor modules in general are in
[`gowl.md`](gowl.md); this file is only the bar.

The compositor's bar module is a plugin host: left/centre/right regions with a centre
anchor, dropdown **panels** that a plugin *describes* while the host renders and
hit-tests them, and **toasts** on the overlay layer that can name a panel.

## Configuring it

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

## A minimal plugin

```c
/* ~/.config/gowl/bar-plugins/hello.c */
#include <gowl/barkit/gowl-bar-plugin.h>
#include <gowl/barkit/gowl-bar-plugin-proxy.h>
#include <gowl/barkit/gowl-bar-registry.h>

static void
hello_poll(GowlBarPlugin *plugin, gpointer data)
{
	(void)data;
	gowl_bar_plugin_set_label(plugin, "hello");
}

static const GowlBarPluginVTable hello_vtable = {
	sizeof(GowlBarPluginVTable),
	NULL, NULL,             /* create, destroy */
	NULL, NULL, NULL,       /* activate, deactivate, configure */
	NULL, hello_poll, NULL, /* interval, poll, poll_async */
	NULL, NULL,             /* measure, draw */
	NULL, NULL,             /* click, scroll */
	NULL, NULL,             /* panel, action */
	NULL, NULL              /* panel_opened, panel_closed */
};

static const GowlBarPluginDesc descs[] = {
	{ GOWL_BAR_PLUGIN_ABI, "hello", "Hello", "A greeting", "1.0.0",
	  &hello_vtable, NULL, { NULL, NULL, NULL, NULL } }
};

G_MODULE_EXPORT const GowlBarPluginDesc *
gowl_bar_plugin_query(guint *n_descs)
{
	*n_descs = G_N_ELEMENTS(descs);
	return descs;
}
```

That is the whole contract for a label that updates: every other slot may be
`NULL` and the bar supplies measurement, drawing, hover and the panel
machinery. One file may publish several plugins in `descs[]`; they compile and
reload together. The headers are installed in `/usr/include/gowl/barkit/`, so
the same file also builds as a `.so` anywhere:
`gcc -std=gnu89 -shared -fPIC -o hello.so hello.c $(pkg-config --cflags --libs gowl cairo pangocairo)`.
Name `cairo pangocairo` explicitly: the barkit headers include both, and the
`gowl.pc` in images built before gowl fixed its `Requires:` does not list them, so
`pkg-config gowl` alone fails there with `cairo.h: No such file`. Naming them is
harmless on newer images. Loading the `.c` through the bar is unaffected — the
bar supplies its own flags.

## Make, load and reload

```bash
# 1. write it -- the minimal plugin above, or the pomodoro example from gowl's data/
mkdir -p ~/.config/gowl/bar-plugins
$EDITOR ~/.config/gowl/bar-plugins/hello.c

# 2. load it into the running bar, by path or by name
gowl bar-plugin-load ~/.config/gowl/bar-plugins/hello.c
gowl bar-plugin-load hello                # resolved through the search path

# 3. put it on the bar -- an unknown widget name is skipped silently, so spell it right
#    ~/.config/gowl/config.yaml:  modules: bar: widgets-right: "hello clock battery"

# 4. edit, then swap the new build in without restarting anything
gowl bar-plugin-reload hello

# 5. when it misbehaves
gowl bar-quarantined                      # held back after a caught signal?
cat "${XDG_STATE_HOME:-$HOME/.local/state}/gowl/bar-plugins.journal"
gowl bar-plugin-unload hello
```

A plugin loaded only by hand is gone at the next session start. Make it
permanent by naming it in `plugins:` (see "Where plugins are found" below). A
`.so` built yourself goes in the same directory and loads the same way; when
both `hello.so` and `hello.c` exist, the compiled one wins.

## Writing a plugin

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

## Where plugins are found

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

## Loading and reloading

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

## Containment

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

## Troubleshooting

```bash
gowl bar-widgets          # what is laid out, per slot and region
gowl bar-plugins          # what is registered
gowl bar-quarantined      # what is held back, and why
cat "${XDG_STATE_HOME:-$HOME/.local/state}/gowl/bar-plugins.journal"
```

| Symptom | Cause | Fix |
|---|---|---|
| A widget is not on the bar | an unknown widget name is skipped **silently** — a typo, or a plugin not yet loaded when the widget lists were read | compare `gowl bar-widgets` with `gowl bar-plugins`; name the plugin in `plugins:` so it loads first |
| A `plugins:` entry warns | it resolved to nothing on the search path | the warning lists every directory searched; check the name and `plugin-dir` |
| A plugin vanished after a crash | it was quarantined, and the journal keeps it held back across restarts | fix it, then `gowl bar-plugin-clear NAME` |
| An edit is not picked up | not reloaded yet, or an older `.so` of the same name shadows the `.c` | `gowl bar-plugin-reload NAME`; delete the stale `.so` |
| Reload fails with the class already registered | the plugin defines its own `GType`, which cannot be re-registered | use the vtable form; only it hot-reloads |
| The editor freezes while the bar updates | `poll` blocks on the dispatch thread | move subprocesses, network and slow reads to `poll_async` |
| A `.c` plugin fails to load | a compile error | the `gowl bar-plugin-load PATH` reply carries it; building with the gcc line above shows the full diagnostic |
| Building a `.so` fails with `cairo.h: No such file` | an older `gowl.pc` omits cairo and pango | `pkg-config --cflags --libs gowl cairo pangocairo` |
| Colours are wrong after a theme switch | a hex literal instead of a colour role | use the `GOWL_BAR_COLOR_*` roles |
| The whole session died | a plugin crashed outside the guard | see [Containment](#containment) — the journal stops it loading again |

## Under cmacs

The bar is the same module with the same plugin directory and search path. The
commands also exist in Elisp: `M-x gowl-bar-plugin-load`,
`gowl-bar-plugin-reload`, `gowl-bar-plugin-unload`, `gowl-bar-plugin-clear`,
and `M-x cmacs-gowl-bar-plugins` to see what is registered and what is held
back. `(gowl-set-palette "latte")` re-themes the bar, its panels, toasts and
every third-party plugin with it — which is why plugins name colour roles
rather than hex values.

## The standalone `gowlbar` binary

The `gowlbar` binary is an older, separate layer-shell bar client. It has its own
configuration — `~/.config/gowl/bar.yaml`, and a crispy `~/.config/gowl/bar.c`
(`/usr/share/gowl/example-bar.c` is a commented template; `gowlbar --recompile`
checks it) — but it does **not** load plugins or modules: the module manager in
its source is never instantiated by the binary. Everything above applies to
the compositor's bar module, which is the one to extend.

## Documentation on the machine

Under `/usr/share/emacs/<version>/doc_org/cmacs/`, openable with
`M-x cmacs-manual-topic`:

| File | Covers |
|---|---|
| `deps/gowl/bar.org` | the full plugin contract: vtable, panels, toasts, threading, search path, containment |
| `gowl.org` (Status Bar) | the bar under cmacs and its Elisp commands |
| `gowl/bar-widgets.org` | the shipped widgets and their options |

The commented pomodoro example, `data/example-bar-plugin.c`, is in the gowl
source only; `/usr/immutablue/deps/dep_info.json` has the remote and commit to
clone.
