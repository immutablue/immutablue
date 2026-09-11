# gsurf: Configuring the Browser

gsurf is a GLib/GObject port of suckless `surf` on WebKitGTK, with surf's
patches rebuilt as runtime modules. It runs standalone as `gsurf`, and embedded
in cmacs as `cmacs-gsurf` — and **the two are configured differently**, which
is the first thing to establish.

## Standalone gsurf

Configuration merges in this order, later overriding earlier:

1. built-in defaults
2. `~/.config/gsurf/config.yaml` — or `--config PATH`, or `/etc/gsurf/config.yaml`
3. `~/.config/gsurf/config.c`, compiled and run

```bash
gsurf --generate-yaml-config > ~/.config/gsurf/config.yaml   # every key, and which modules default on
gsurf --generate-c-config    > ~/.config/gsurf/config.c
gsurf --list-modules
gsurf --no-modules / --no-c-config / --no-yaml-config        # isolate a problem
```

```yaml
browser:
  homepage: "about:blank"
  new_view_uri: "about:blank"
  default_zoom: 1.0
  smooth_scroll: true

user_agent: ""                  # "" = the engine default

webkit:                         # web engine settings, surf's defconfig
  javascript: true
  images: true
  webgl: false
  default_font_size: 16

window:
  title: gsurf
  geometry: 1024x768

keybinds:
  "Ctrl+r": reload
  "Alt+Left": back

modules:                        # one block per module; enabled: gates it
  search_engines:
    enabled: true
    default: ddg
    engines:
      g: { prefix: "g ", url: "https://www.google.com/search?q=%s" }
  modal:
    enabled: true
    hint_chars: "asdfghjkl"
```

The C config defines `gsurf_config_init()` and edits the config object
directly:

```c
#include <gsurf/gsurf.h>

G_MODULE_EXPORT gboolean
gsurf_config_init(void)
{
	GsurfConfig *config = gsurf_config_get_default();

	if (config == NULL)
		return FALSE;
	g_free(config->homepage);
	config->homepage = g_strdup("https://duckduckgo.com");
	config->default_zoom = 1.25;
	config->settings->webgl = FALSE;
	gsurf_settings_set_user_agent(config->settings, "MyAgent/1.0");
	g_hash_table_replace(config->keybinds, g_strdup("Ctrl+m"),
	                     GUINT_TO_POINTER(GSURF_ACTION_RELOAD));
	return TRUE;
}
```

It is compiled by crispy and cached as `$XDG_CACHE_HOME/gsurf/cconfig/<hash>.so`;
`#define CRISPY_PARAMS "..."` adds flags.

## Keybindings

Key strings are optional modifiers plus a GDK keyval name: `"Ctrl+r"`,
`"Alt+Left"`, `"Ctrl+Shift+g"`, `"slash"`, `"j"`. Modifiers are `Ctrl`
(`Control`), `Alt` (`Mod1`), `Shift`, `Super` (`Logo`, `Mod4`); order and case
are normalised. Values are action names, with `-` or `_` accepted.

| Default | Action |
|---|---|
| `Ctrl+r` / `Ctrl+Shift+r` | `reload` / `reload-nocache` |
| `Escape` | `stop` |
| `Alt+Left` / `Alt+Right` | `back` / `forward` |
| `Ctrl+plus` / `minus` / `0` | zoom in / out / reset |
| `Ctrl+f`, `Ctrl+g` / `Ctrl+Shift+g` | find, next / previous |
| `F11`, `Ctrl+q` | `toggle-fullscreen`, `quit` |

The vim-style layer comes from the `modal` module, not the core table, and is
focus-aware — it never eats typing. With no editable element focused: `hjkl`
scroll, `gg`/`G` top/bottom, `H`/`L` history, `r` reload, `d`/`u` half-page,
`f` link hints (`F` opens in a new view). With a text field or the address bar
focused, keys go to it; `Escape` returns to command context, `i` forces insert
mode for pages that want raw keys. Hint appearance is `modules.modal.hint_chars`,
`hint_bg`, `hint_fg`. `tabs` adds `Ctrl+t` / `Ctrl+w` / `Ctrl+Tab`, and
`toggles` adds `Ctrl+Shift+…` setting toggles.

Other actions: `home`, `open-prompt`, `open-new-view`,
`scroll-{up,down,left,right,top,bottom}`, `page-{up,down}`,
`half-page-{up,down}`, `tab-{new,close,next,prev,reopen}`,
`enter-{normal,insert}-mode`, `follow-hints`, `copy-url`, `paste-url`.

## Modules

`gsurf --list-modules` is authoritative. Grouped:

| Group | Modules |
|---|---|
| chrome | `chromebar`, `omnibar`, `tabs`, `find_bar`, `status_bar`, `downloads` |
| navigation | `modal`, `search_engines`, `spacesearch`, `homepage`, `history`, `bookmarks` |
| content | `adblock`, `dark_mode`, `site_styles`, `userscripts`, `uri_params`, `useragent` |
| privacy and trust | `cookie_policy`, `cert_manager`, `toggles` |
| integration | `externalpipe`, `playexternal` (mpv), `notifications`, `inspector`, `mcp` |

A module is on only if the effective config says `enabled: true`.

**The module-directory trap.** Standalone gsurf takes modules from *one*
directory: the first that exists of `$GSURF_MODULE_PATH`, `<exe-dir>/modules/`,
`/usr/lib64/gsurf/modules/`. Pointing `GSURF_MODULE_PATH` at a directory
holding only your module therefore drops every shipped module. For a personal
module, make a directory of symlinks to the system `.so` files plus your own,
and point the variable at that. (cmacs searches several directories — see
below — so the variable adds there instead of replacing.)

A module is a `.so` exporting `gsurf_module_register()`, returning a
`GsurfModule` subclass that implements hook interfaces: `GsurfInputHandler`
(keys and mouse before the default binds), `GsurfUriHandler` (rewrite a URI
before it loads), `GsurfNavigationHook` (before/after navigate, load events),
`GsurfScriptInjector` (once per view), and more. Its options come from
`gsurf_config_get_module_node(config, "<name>")`. Build it against the
installed library with `$(pkg-config --cflags --libs gsurf)`.

## Embedded in cmacs

`cmacs-gsurf` does **not** read `~/.config/gsurf/config.yaml` or `config.c` by
default. It tells gsurf to ignore YAML (`cmacs-gsurf-ignore-yaml`, default
`t`) and configures it from Elisp, before modules load:

```elisp
(setq cmacs-gsurf-modules
      '(("modal"          :enabled t :hint_chars "asdfjkl")
        ("search_engines" :enabled t)
        ("history"        :enabled t)
        ("dark_mode"      :enabled t)
        ("adblock"        :enabled t)))
```

`:enabled` gates a module; every other key becomes a module option. The
default enables `modal`, `search_engines` and `history`. Leave the chrome
modules (`chromebar`, `tabs`, `omnibar`, `find_bar`, `status_bar`) off — the
embedded browser has no gsurf window for them to draw in. Apply edits live with
`M-x cmacs-gsurf-reload-config`.

To use gsurf's own files as well — layering, last wins:
`cmacs-gsurf-modules` → `config.yaml` → `cmacs-gsurf-config-file` → C config:

```elisp
(setq cmacs-gsurf-load-user-config t)                       ; read ~/.config/gsurf/config.{yaml,c}
(setq cmacs-gsurf-config-file "~/my-gsurf.yaml")            ; a specific YAML file
(setq cmacs-gsurf-config-c-file "~/.config/cmacs/init.c")   ; any crispy file with gsurf_config_init()
```

Modules are searched in `$CMACS_GSURF_MODULE_DIR`, `$GSURF_MODULE_PATH`, the
cmacs tree, gsurf's build tree, then `$libdir/cmacs/gsurf/modules/` — first
match by filename, like `$PATH`. `(cmacs-gsurf-modules-list)` reports each
module's enabled and active state; `(cmacs-gsurf-module-set-enabled "adblock"
t)` flips one at runtime.

## Troubleshooting

Standalone, isolate first — each flag removes one layer:

```bash
gsurf --no-modules          # is it a module?
gsurf --no-c-config         # is it config.c?
gsurf --no-yaml-config      # is it the YAML?
env | grep -E '^GSURF_'     # GSURF_CONFIG_C or GSURF_MODULE_PATH redirecting things?
```

| Symptom | Cause | Fix |
|---|---|---|
| `config.c` changes do nothing | `GSURF_CONFIG_C` in the environment points at a different file, or the compile failed | check the variable; `--no-c-config` to compare |
| A module does nothing | it is not `enabled: true` in the effective config | `--generate-yaml-config` shows the defaults; enable it under `modules:` |
| Every shipped module is gone | `GSURF_MODULE_PATH` names a directory without them — standalone uses exactly one module directory | unset it, or make it a directory of symlinks to `/usr/lib64/gsurf/modules/*.so` plus your own |
| Pages are blank, or flicker, on some GPUs | WebKitGTK's compositing or DMA-BUF renderer | WebKitGTK's own switches: `WEBKIT_DISABLE_DMABUF_RENDERER=1`, then `WEBKIT_DISABLE_COMPOSITING_MODE=1` |
| Letters scroll the page instead of typing | nothing editable is focused, so `modal` treats keys as commands | click the field; `i` forces insert mode |

Embedded in cmacs:

| Symptom | Cause | Fix |
|---|---|---|
| Keys go to the page, and Emacs bindings stop working | the page holds GTK focus | `Escape` returns focus to Emacs, as does clicking another Emacs window; `RET`, `i` or a click gives it back |
| A module is not applying | `cmacs-gsurf` ignores gsurf's YAML by default | `(cmacs-gsurf-modules-list)`; set it in `cmacs-gsurf-modules` or with `cmacs-gsurf-module-set-enabled`, then `M-x cmacs-gsurf-reload-config` |
| `cmacs-gsurf-error: gsurf backend unavailable (no display?)` | WebKit needs a display | expected under `--batch` |
| `ERROR: invalid option: JSC_SIGNAL_FOR_GC=…` | the variable is set in the environment | unset it; cmacs configures JavaScriptCore's GC signal itself |

The embedded troubleshooting list is maintained in `cmacs-gsurf.org`.

## Documentation on the machine

Under `/usr/share/emacs/<version>/doc_org/cmacs/`, openable with
`M-x cmacs-manual-topic`:

| File | Covers |
|---|---|
| `deps/gsurf/configuration.org`, `c-config.org`, `keybindings.org` | the standalone config reference |
| `deps/gsurf/modules.org`, `module-system.org` | every module, and writing one |
| `cmacs-gsurf.org` | the embedded browser: focus model, keymap, config from Elisp, JS bridge, caret mode, `gsurf-lite` |
