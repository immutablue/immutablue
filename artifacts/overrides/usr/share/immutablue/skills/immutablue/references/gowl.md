# gowl: Configuration and Compositor Modules

gowl is the wlroots compositor behind the gowl session. It runs two ways, and
most of this file applies to both:

| How it runs | Started by | What differs |
|---|---|---|
| standalone | `gowl` | the reference behaviour described here |
| embedded in cmacs | `cmacs --gowl` | also driven from Elisp, loads some modules itself — see [Under cmacs](#under-cmacs) |

```bash
echo "$XDG_CURRENT_DESKTOP"; pgrep -a gowl; pgrep -af 'emacs.*--gowl'
```

The bar and its plugins are their own topic: [`gowl-bar.md`](gowl-bar.md).

## Configuration files

YAML, then C, then the command line — later wins over earlier:

| Kind | Searched in order, first hit is used |
|---|---|
| YAML | `--config PATH`, `./data/config.yaml`, `~/.config/gowl/config.yaml`, `/etc/gowl/config.yaml`, `/usr/local/share/gowl/config.yaml` |
| C | `--c-config PATH`, `~/.config/gowl/config.c`, `/etc/gowl/config.c`, `/usr/local/share/gowl/config.c`, `./data/config.c` |

Precedence is built-in defaults < YAML < C < CLI. `gowl --help` prints the
resolved lists for the binary actually installed.

```bash
gowl --generate-yaml-config > ~/.config/gowl/config.yaml   # every key, commented
gowl --modules=cube,expo --generate-yaml-config            # include those modules' sections
gowl --generate-c-config    > ~/.config/gowl/config.c
gowl --list-modules
less /usr/share/gowl/default-config.yaml                    # the shipped defaults, commented
```

`/usr/share/gowl/default-config.yaml` is a reference copy, not a search-path
entry — copy what you need into `~/.config/gowl/config.yaml`. The log goes to
`log-file` (default `~/.config/gowl/gowl.log`); read it first when a change
"does nothing", because a rejected key is logged there and nowhere else.

### What the YAML covers

Top-level scalars: `terminal`, `menu`, `repeat-rate`, `repeat-delay`,
`sloppyfocus`, `manage_lid`, `border-width`, `border-color-*`, `mfact`,
`nmaster`, `tag-count`, `palette`, and the effect families — `animation-*`,
`cube-*`, `expo-*`, `switcher-*`, `magnifier-*`, `blur-*`, `shadow-*`,
`wallpaper-fade`. Tables: `keybinds`, `rules`, `dropdowns`, `autostart`,
`monitors`, `modules`. Colours may name a palette role (`accent`, `surface`,
`red`) instead of a hex value, and should — a role follows a theme switch.

Keybinds map a key string to an action object:

```yaml
keybinds:
  "Super+Return":  { action: spawn, arg: "gst", desc: "Terminal" }
  "Super+j":       { action: focus_stack, arg: "+1", desc: "Focus next" }
  "Super+Shift+c": { action: kill_client, desc: "Close window" }
  "Super+2":       { action: tag_view, arg: "2" }
```

| Action | Argument |
|---|---|
| `spawn` | command string |
| `kill_client`, `toggle_float`, `toggle_fullscreen`, `zoom`, `cycle_layout`, `quit`, `reload_config` | — |
| `focus_stack`, `focus_monitor`, `move_to_monitor`, `inc_nmaster` | `"+1"` or `"-1"` |
| `tag_view`, `tag_set` | `"0"`–`"9"`, 0 meaning all tags |
| `tag_toggle_view`, `tag_toggle` | `"1"`–`"9"` |
| `set_mfact` | `"+0.05"` or `"-0.05"` |
| `set_layout` | `"tile"`, `"float"`, `"monocle"`, or any loaded layout module |
| `set_split` | `"vsplit"` or `"normal"` |
| `ipc_command` | an IPC command string |
| `custom` | passed to the embedder: an Elisp form under cmacs, inert standalone |

`desc` never affects dispatch — it feeds the keybind cheatsheet and the MCP
`list_keybinds` tool. `custom` is how a compositor key runs editor code under
cmacs: `"XF86AudioRaiseVolume": { action: custom, arg: "(cmacs-volume-raise)" }`.

Rules match on `app_id` and/or `title` and set `tags` (a bitmask), `floating`
and `monitor` (`-1` for the default):

```yaml
rules:
  - app_id: "pavucontrol"
    floating: true
  - app_id: "firefox"
    tags: 2
```

The full key reference is gowl's own `configuration.org`, installed at
`/usr/share/emacs/*/doc_org/cmacs/deps/gowl/configuration.org`.

### The C config

`~/.config/gowl/config.c` is ordinary C compiled at startup through **crispy**
to a `.so` cached by content hash in `$XDG_CACHE_HOME/gowl/`, dlopened, and
called. A compile failure logs a warning and falls back to the YAML, so a
broken `config.c` never locks anyone out.

```bash
gowl --recompile        # compile only, print errors, exit -- run this after every edit
gowl --no-c-config      # boot without it
```

Two entry points, both resolved from the running compositor at dlopen, as are
`extern GowlCompositor *gowl_compositor;` and `extern GowlConfig *gowl_config;`:

| Symbol | Required | Runs |
|---|---|---|
| `gowl_config_init(void)` → `gboolean` | yes | after the YAML, **before** the compositor or module manager exist |
| `gowl_config_ready(void)` | no | once the compositor is started, before modules receive startup |

Treat `gowl_compositor` as usable only from `gowl_config_ready`. Returning
`FALSE` from `init` falls back to YAML/defaults. Extra compiler flags go in the
source, with shell expansion at compile time:
`#define CRISPY_PARAMS "$(pkg-config --cflags --libs json-glib-1.0)"`.

```c
#include <gowl/gowl.h>
#include <xkbcommon/xkbcommon.h>

extern GowlConfig *gowl_config;

G_MODULE_EXPORT gboolean
gowl_config_init(void)
{
	g_object_set(gowl_config, "border-width", 3, "mfact", 0.60, NULL);
	gowl_config_add_keybind_full(gowl_config, GOWL_KEY_MOD_LOGO, XKB_KEY_Return,
	                             GOWL_ACTION_SPAWN, "gst", "Terminal");
	gowl_config_add_rule(gowl_config, "firefox", NULL, GOWL_TAGMASK(1), FALSE, -1);
	return TRUE;
}
```

There is no hot reload for `config.c`: edit, `gowl --recompile`, restart the
session. An unchanged file never recompiles.

## Compositor modules

A module is a GModule `.so` holding a GObject subclass of `GowlModule` that
implements one or more hook interfaces (`GowlKeybindHandler`,
`GowlStartupHandler`, `GowlLayoutProvider`, `GowlClientDecorator`,
`GowlRuleProvider`, `GowlIpcHandler`, … — eighteen in all), and exports one
symbol, `gowl_module_register()`, returning its type. The shipped set is
`gowl --list-modules`: layouts (tile, monocle, float, scrolling,
centeredmaster, fibonacci), effects (animation, cube, expo, switcher,
magnifier, blur), and behaviour (autostart, scratchpad, swallow, pertag,
movestack, vanitygaps, copyhighlight, ipc, mcp).

How the binary loads them, which is **not** how bar plugins load:

- Only modules with `enabled: true` under `modules:` are loaded. `tile`,
  `monocle` and `float` are on unless explicitly disabled.
- Each is looked up as `<name>.so` in `<exe-dir>/modules/`, then
  `/usr/lib64/gowl/modules/`, first match wins. There is no home-directory
  scan and no `.c` compilation for compositor modules.
- Loading happens once, at startup. There is no load/unload/reload IPC for
  compositor modules; `reload_config` reloads configuration only. A new or
  rebuilt `.so` means restarting the session.
- Per-module YAML under `modules: <name>:` reaches the module's `configure()`
  as a `GHashTable` of string keys to string values.

### Writing one

Headers and `gowl.pc` are installed, so a module builds anywhere — no gowl
source tree needed:

```c
/* hello.c -- gcc -std=gnu89 -shared -fPIC -o hello.so hello.c $(pkg-config --cflags --libs gowl) */
#include <gowl/gowl.h>
#include <xkbcommon/xkbcommon.h>

#define HELLO_TYPE_MODULE (hello_module_get_type())
G_DECLARE_FINAL_TYPE(HelloModule, hello_module, HELLO, MODULE, GowlModule)

struct _HelloModule {
	GowlModule  parent_instance;
	gchar      *greeting;
};

static void
hello_on_startup(GowlStartupHandler *handler, gpointer compositor)
{
	(void)compositor;
	g_message("hello: %s", HELLO_MODULE(handler)->greeting);
}

static void
hello_startup_init(GowlStartupHandlerInterface *iface)
{
	iface->on_startup = hello_on_startup;
}

static gboolean
hello_handle_key(GowlKeybindHandler *handler, guint modifiers,
                 guint keysym, gboolean pressed)
{
	(void)handler;
	if (pressed && (modifiers & GOWL_KEY_MOD_LOGO) && keysym == XKB_KEY_F12) {
		g_message("hello: Super+F12");
		return TRUE;                     /* consumed */
	}
	return FALSE;                        /* next handler */
}

static void
hello_keybind_init(GowlKeybindHandlerInterface *iface)
{
	iface->handle_key = hello_handle_key;
}

G_DEFINE_FINAL_TYPE_WITH_CODE(HelloModule, hello_module, GOWL_TYPE_MODULE,
	G_IMPLEMENT_INTERFACE(GOWL_TYPE_STARTUP_HANDLER, hello_startup_init)
	G_IMPLEMENT_INTERFACE(GOWL_TYPE_KEYBIND_HANDLER, hello_keybind_init))

static gboolean     hello_activate(GowlModule *m) { (void)m; return TRUE; }
static const gchar *hello_get_name(GowlModule *m) { (void)m; return "hello"; }

static void
hello_configure(GowlModule *mod, gpointer config)
{
	const gchar *v = g_hash_table_lookup((GHashTable *)config, "greeting");

	if (v != NULL) {
		g_free(HELLO_MODULE(mod)->greeting);
		HELLO_MODULE(mod)->greeting = g_strdup(v);
	}
}

static void
hello_module_finalize(GObject *object)
{
	g_free(HELLO_MODULE(object)->greeting);
	G_OBJECT_CLASS(hello_module_parent_class)->finalize(object);
}

static void
hello_module_class_init(HelloModuleClass *klass)
{
	GowlModuleClass *mc = GOWL_MODULE_CLASS(klass);

	mc->activate  = hello_activate;      /* must return TRUE, or the module stays inactive */
	mc->get_name  = hello_get_name;      /* the name YAML and find_module() use */
	mc->configure = hello_configure;
	G_OBJECT_CLASS(klass)->finalize = hello_module_finalize;
}

static void
hello_module_init(HelloModule *self)
{
	self->greeting = g_strdup("hello from $HOME");
}

G_MODULE_EXPORT GType
gowl_module_register(void)
{
	return HELLO_TYPE_MODULE;
}
```

That builds clean with `-Wall -Wextra`. Every dispatcher skips a module whose
`activate()` did not return `TRUE`, so an `activate` that forgets to return
`TRUE` is a module that silently does nothing. The interface list and every
vfunc signature are in gowl's `modules.org`, installed at
`/usr/share/emacs/*/doc_org/cmacs/deps/gowl/modules.org`.

### Loading a module from your own directory

Keep personal modules somewhere like `~/.config/gowl/modules/`. The binary
never scans it, so something has to load them — which depends on how gowl is
running.

**Standalone gowl — from `config.c`.** `gowl_config_ready()` runs after the
module manager exists and *before* startup is dispatched, so a module loaded
there still receives `on_startup`. `load_module()` registers a module but does
not configure or activate it; do both:

```c
extern GowlCompositor *gowl_compositor;
extern GowlConfig     *gowl_config;

G_MODULE_EXPORT void
gowl_config_ready(void)
{
	GowlModuleManager *mgr;
	GowlModule *mod;
	GHashTable *settings;
	g_autoptr(GError) error = NULL;
	g_autofree gchar *path = NULL;

	mgr  = gowl_compositor_get_module_manager(gowl_compositor);
	path = g_build_filename(g_get_user_config_dir(), "gowl", "modules", "hello.so", NULL);
	if (!gowl_module_manager_load_module(mgr, path, &error)) {
		g_warning("hello: %s", error->message);
		return;
	}
	mod = gowl_module_manager_find_module(mgr, "hello");        /* by get_name() */
	if (mod == NULL)
		return;
	settings = gowl_config_get_module_config(gowl_config, "hello");  /* modules: hello: in YAML */
	if (settings != NULL)
		gowl_module_configure(mod, (gpointer)settings);
	if (!gowl_module_activate(mod))
		g_warning("hello: activate() returned FALSE");
}
```

This composes public API rather than following an upstream recipe; it compiles
against the installed headers (`gowl --recompile`). Check the result in
`~/.config/gowl/gowl.log`.

**Under cmacs — `CMACS_GOWL_MODULE_DIR`.** cmacs resolves a module name as
`$CMACS_GOWL_MODULE_DIR/<name>.so`, then its in-tree build, then its installed
`gowl-modules/` directory, so pointing the variable at a personal directory
*adds* to what is available rather than hiding the shipped modules. It is read
with C `g_getenv` when the module is enabled, so it must be in cmacs's
environment **before** cmacs starts — `(setenv …)` in `init.el` only changes
`process-environment` and is invisible to it:

```bash
mkdir -p ~/.config/environment.d
echo 'CMACS_GOWL_MODULE_DIR=${HOME}/.config/gowl/modules' > ~/.config/environment.d/60-gowl-modules.conf
# log out and back in
```

```elisp
;; init.el -- then enable and configure by name
(when (and (fboundp 'gowl-running-p) (gowl-running-p))
  (gowl-start)
  (gowl-enable-module "hello")
  (gowl-configure-module "hello" '(("greeting" . "hi"))))
```

`(getenv "CMACS_GOWL_MODULE_DIR")` in a fresh cmacs shows whether the session
got the variable; `(gowl-list-modules)` shows what loaded. `gowl_config_ready()`
is **not** called under cmacs, so the `config.c` route above does not apply
there.

**Shipping it in the image.** Put the `.so` under
`artifacts/overrides/usr/lib64/gowl/modules/` (or build it in the deps
container) and set `enabled: true` — see [`building.md`](building.md). That is
the only route that reaches every machine.

## Under cmacs

- cmacs reads the same `~/.config/gowl/config.yaml`, and compiles
  `~/.config/gowl/config.c` and runs its `gowl_config_init()` — but never its
  `gowl_config_ready()`.
- cmacs loads several modules itself — `animation`, `cube`, `expo`, `blur`,
  `scrolling`, the layout indicator — which is why the shipped YAML leaves them
  `enabled: false` with a comment saying so.
- Much of the session is also set from Elisp: `cmacs-gowl-mode` pushes
  defcustoms into the running compositor, `(gobject-set (gowl-config-object)
  "manage-lid" nil)` sets a single property, `M-x gowl-reload-config` rereads
  the YAML, and `M-x cmacs-gowl-describe-keybinds` renders the cheatsheet.
- The embedding manual is `gowl.org` in the cmacs docs — see
  [`cmacs.md`](cmacs.md) for where those live.

## Documentation on the machine

All under `/usr/share/emacs/<version>/doc_org/cmacs/` (`ls -d
/usr/share/emacs/*/doc_org` for the version), and all openable with
`M-x cmacs-manual-topic`:

| File | Covers |
|---|---|
| `deps/gowl/configuration.org` | every YAML key, the C config API, keybind and rule syntax |
| `deps/gowl/modules.org` | writing modules: every interface and vfunc, step by step |
| `deps/gowl/architecture.org` | core objects, dispatch, signals |
| `deps/gowl/bar.org` | the bar and its plugin contract |
| `gowl.org` | gowl embedded in cmacs: startup, Elisp API, modules, bar, monitors |
| `gowl/bar-widgets.org`, `gowl/multi-display.org`, `gowl/screenshot-recording.org` | cmacs-side topics |

These are generated from the gowl submodule at the cmacs build, so they
describe the installed gowl, not upstream `master`. Headers are in
`/usr/include/gowl/`.

## Troubleshooting

Start with what the compositor itself will tell you:

```bash
gowl ping; gowl status; gowl version           # is it answering IPC?
tail -f ~/.config/gowl/gowl.log                 # log-file; set log-level: debug, or start with gowl --debug
journalctl --user -b --grep gowl                # session start-up and the systemd bootstrap
systemctl --user status gowl-session.target graphical-session.target
```

| Symptom | Cause | Fix |
|---|---|---|
| A YAML change does nothing | `config.c` runs after the YAML and overrides it, or a different file won the search | read the log; `gowl --no-c-config` rules the C config out |
| A `config.c` edit does nothing | it failed to compile, and gowl fell back to YAML with only a log warning | `gowl --recompile` prints the gcc error |
| `Module 'x' is enabled but .so not found` | no `x.so` in `<exe-dir>/modules/` or `/usr/lib64/gowl/modules/` | check the name matches the file; for `$HOME` modules see [Loading a module from your own directory](#loading-a-module-from-your-own-directory) |
| A module loads but does nothing | its `activate()` returned `FALSE`, so every dispatcher skips it | return `TRUE`; a module loaded from `config.c` must be activated explicitly |
| A rebuilt module behaves like the old one | modules load once, at startup | restart the session; `reload_config` does not reload modules |
| A keybind never fires | a bad keysym name, a module consumed the key first, or — nested — the host compositor kept it | `M-x cmacs-gowl-describe-keybinds`, or MCP `list_keybinds`, shows what is bound |
| Super bindings are dead when gowl runs nested in GNOME | Mutter owns Super until the nested gowl surface has focus and holds the shortcuts inhibitor | click into the gowl window first |
| Portals, gvfs or flatpak helpers are dead in the session | `graphical-session.target` never started because the bootstrap believed it was nested | `systemctl --user show-environment \| grep -E '^(WAYLAND_)?DISPLAY'` for a value leaked from an earlier session |
| Login returns straight to GDM, and works again after a GNOME login | a stale `$XDG_RUNTIME_DIR/wayland-N` from an older cmacs logout made the session think it was nested | fixed in current builds — gowl now connects rather than stat-ing, and removes its socket at exit; on an old image, update |
| An Electron app (VS Code, Slack, Claude) forgets its login | Chromium picks its secret store from `XDG_CURRENT_DESKTOP` and needs a desktop it recognises | `echo $XDG_CURRENT_DESKTOP` must end in `:GNOME`; the shipped `gowl.desktop` and `cmacs.desktop` do this, and a custom session file must too — `GNOME` **last**, or portals route to the wrong backend |
| An X11 window focuses or stacks oddly | override-redirect versus managed XWayland surfaces take different paths | `GOWL_DEBUG_XWAYLAND=1` logs each surface's type at the default log level |
| A nested or headless output has no size | the backend advertised no modes | `GOWL_OUTPUT_SIZE=1920x1080` |
| The wrong backend was chosen | gowl only sets `WLR_BACKENDS` when it is unset | set `WLR_BACKENDS=libinput,drm` explicitly |
| The laptop panel switches off with the lid closed and a monitor attached | `manage_lid` does that by design | `manage_lid: false`, or `(gobject-set (gowl-config-object) "manage-lid" nil)` |
| Keys are stuck in an embedded client under cmacs | the client holds keyboard focus | `Escape` returns focus to Emacs; `Escape Escape` sends one Escape to the client |
| KVM / deskflow capture fails | | the Troubleshooting section of `deps/gowl/input-capture.org` |
| The compositor crashed | a bar plugin is the usual in-process suspect | read the plugin journal first ([`gowl-bar.md`](gowl-bar.md)), then [`crash-analysis.md`](crash-analysis.md) |

`GOWL_DISABLE_SYSTEMD=1` skips the systemd user-session bootstrap
(`import-environment`, `gowl-session.target`, portal restart) — useful to tell
a compositor problem from a session-plumbing one. The sessions GDM offers are
`/usr/share/wayland-sessions/gowl.desktop` and `cmacs.desktop`; both stop
`gowl-session.target` when the compositor exits.
