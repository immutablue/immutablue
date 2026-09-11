# gst: Configuring the Terminal

gst is Immutablue's terminal: a GLib/GObject reimplementation of suckless `st`
with runtime modules. It is the `terminal` gowl spawns. Configuration is YAML,
optionally overridden by a crispy-compiled C file.

## Files

| Kind | Searched in order, first hit is used |
|---|---|
| YAML | `--config PATH`, `~/.config/gst/config.yaml`, `/etc/gst/config.yaml`, `/usr/share/gst/config.yaml` |
| C | `--c-config PATH`, `~/.config/gst/config.c`, `/etc/gst/config.c`, `/usr/share/gst/config.c` |

The C config runs **after** the YAML, so anything it sets wins. With no file at
all the built-in defaults apply.

```bash
gst --generate-yaml-config > ~/.config/gst/config.yaml     # every key, commented
gst --modules=scrollback,search --generate-yaml-config     # include those modules' sections
gst --generate-c-config    > ~/.config/gst/config.c
gst --list-modules
gst --recompile                                            # compile config.c only, report errors
gst --no-c-config / --no-yaml-config                       # isolate a bad config
```

`--generate-yaml-config` is the most complete on-machine reference: gst's own
docs are **not** in the cmacs documentation tree (see the end of this file).

## YAML sections

```yaml
terminal:
  shell: /bin/bash
  editor: emacsclient          # used by export-command-output
  term: st-256color
  tabspaces: 8

window:
  title: gst
  geometry: 80x24              # columns x rows
  border: 2

font:
  primary: "JetBrains Mono:pixelsize=14:antialias=true:autohint=true"
  fallback:
    - "Noto Color Emoji:pixelsize=14"
    - "Symbols Nerd Font:pixelsize=14"

colors:
  foreground: "#cdd6f4"        # a hex string, or a palette index 0-255
  background: "#1e1e2e"
  cursor_fg: "#1e1e2e"
  cursor_bg: "#cdd6f4"
  palette:                     # the 16 ANSI colours, 0-15
    - "#45475a"
    - "#f38ba8"
    # ... fourteen more

cursor:
  shape: block
  blink: false
  blink_rate: 500

keybinds:
  "Ctrl+Shift+c": clipboard_copy
  "Ctrl+Shift+v": clipboard_paste

modules:
  scrollback:
    enabled: true
    lines: 10000
  transparency:
    enabled: false
```

Fonts are fontconfig patterns — `Family:pixelsize=14` for pixels, `size=10`
for points, plus `antialias`, `autohint`, `style=Bold`. `ignore_yaml: true` at
top level skips the YAML entirely, for someone who configures only in C.
`selection` and `mousebinds` are the remaining sections.

## Keybindings

Key strings are `Modifier+Modifier+KeyName` with X11 keysym names (`a`,
`Page_Up`, `Return`, `plus`, `F1`). Modifiers are `Ctrl` (`Control`),
`Shift`, `Alt` (`Mod1`), `Super` (`Mod4`), `Hyper`, `Meta`, case-insensitive.
Mouse bindings use `Button1`–`Button9` (4/5 are the wheel).

| Default | Action |
|---|---|
| `Ctrl+Shift+c` / `Ctrl+Shift+v` | `clipboard_copy` / `clipboard_paste` |
| `Shift+Page_Up` / `Shift+Page_Down` | `scroll_up` / `scroll_down` |
| `Ctrl+Shift+Home` / `Ctrl+Shift+End` | `scroll_top` / `scroll_bottom` |
| `Ctrl+Shift+plus` / `minus` / `0` | `zoom_in` / `zoom_out` / `zoom_reset` |
| `Ctrl+Shift+y` | `copy-command-output` — the selected or latest command's output |
| `Ctrl+Shift+o` | `export-command-output` — open it in `terminal.editor` |
| `Shift+Button4` / `Shift+Button5` | `scroll_up_fast` / `scroll_down_fast` |

The two command-output actions need the `shell_integration` module and a shell
that emits OSC 133 prompt markers. Some keys belong to modules rather than the
table: `Ctrl+Shift+u` (`urlclick`), `Ctrl+Shift+e` (`externalpipe`),
`Ctrl+Shift+Escape` (`keyboard_select`), `Ctrl+Shift+f` (`search`),
`Ctrl+Shift+Up/Down` (`shell_integration`, jump between prompts).

## The C config

```c
#include <gst/gst.h>

G_MODULE_EXPORT gboolean
gst_config_init(void)
{
	GstConfig *config = gst_config_get_default();

	gst_config_set_title(config, "gst");
	gst_config_set_font_primary(config, "JetBrains Mono:pixelsize=14:antialias=true");
	gst_config_set_module_config_bool(config, "scrollback", "enabled", TRUE);
	gst_config_set_module_config_int(config, "scrollback", "lines", 20000);
	return TRUE;                  /* FALSE falls back to YAML only */
}
```

Compiled by crispy and cached by content hash in `$XDG_CACHE_HOME/gst/`, so an
unchanged file never recompiles. `#define CRISPY_PARAMS "..."` adds compiler
flags. `gst_module_manager_get_default()` is available inside
`gst_config_init()`, before modules activate. Every setter has a matching
getter; `gst --generate-c-config` prints a template that uses them.

## Modules

`gst --list-modules` is the authoritative list. The notable ones:

| Module | Gives you |
|---|---|
| `scrollback`, `search` | history and interactive search in it |
| `shell_integration` | OSC 133 prompt zones: jump between prompts, copy a command's output |
| `clipboard`, `osc52` | system clipboard; remote clipboard over SSH |
| `urlclick`, `hyperlinks` | open detected URLs; OSC 8 links |
| `kittygfx`, `sixel` | inline images |
| `ligatures`, `font2`, `boxdraw`, `undercurl` | text rendering |
| `transparency`, `visualbell`, `notify`, `dynamic_colors`, `sync_update` | window and escape-sequence features |
| `keyboard_select`, `externalpipe` | keyboard selection; pipe the screen to a command |
| `mcp` | an MCP server so an agent can drive the terminal |

Each is gated by `modules: <name>: enabled:`. Modules load at startup from, in
order, `$GST_MODULE_PATH` (colon-separated), `~/.config/gst/modules/`, and
`/usr/lib64/gst/modules/`. A module gst does not know by name — your own —
defaults to **enabled**.

A personal module is a `.so` exporting `gst_module_register()` that returns a
`GstModule` subclass implementing hook interfaces (`GstBellHandler`, …), built
against the installed library: `gcc -std=gnu89 -shared -fPIC -o mine.so mine.c
$(pkg-config --cflags --libs gst)`. Drop it in `~/.config/gst/modules/` and
start a new terminal; there is no hot reload. `GST_MODULE_PATH=./build gst` is
the quick way to try one before installing it.

## Backends

`gst --wayland` / `--x11` force a backend; `--lrg=2d` renders through
libregnum/raylib. `--mcp-socket=NAME` names the MCP socket when several
terminals run the `mcp` module.

## Troubleshooting

gst writes its warnings — a YAML key it rejected, a module that failed to load,
a C config that did not compile — to stderr. Launched from a keybind, that
output is lost, so reproduce from another terminal: `gst 2>&1 | tee /tmp/gst.log`.

| Symptom | Cause | Fix |
|---|---|---|
| A config change does nothing | another file won the search, the YAML failed to parse, or `config.c` overrode it | read stderr; bisect with `--no-c-config` and `--no-yaml-config` |
| A `config.c` edit does nothing | it failed to compile and gst fell back to YAML | `gst --recompile` prints the gcc error |
| The font is wrong, or glyphs are boxes | the fontconfig pattern matched something else, or no fallback has the glyph | `fc-match "JetBrains Mono:pixelsize=14"` shows what the pattern resolves to; add a `fallback`, or enable `font2` |
| A keybind does nothing | an X11 keysym name is needed (`plus`, not `+`), the key belongs to a module, or the compositor took it first | check the module table above; gowl binds `Super` combinations before any client sees them |
| Copy / export command output does nothing | needs the `shell_integration` module and a shell emitting OSC 133 markers | enable the module; configure the shell's prompt markers |
| Mouse selection or tmux mouse mode misbehaves | | `GST_MOUSE_DEBUG=1 gst` logs every mouse event, its pixel-to-cell mapping, and whether it went to the application or to local selection |
| Images do not render | `kittygfx` / `sixel` are off | enable them under `modules:` |
| A personal module does not load | wrong directory, or no `gst_module_register` export | `GST_MODULE_PATH=$PWD gst` from the build directory; `nm -D mine.so \| grep gst_module_register` |
| Oddities under `--lrg` | expected limits of that backend | `PRIMARY` is the clipboard, `--windid` embedding is unsupported, `3d`/`3dvr` are rejected, and it repaints at ~60 fps |
| It picked the wrong display backend | | force it with `--wayland` or `--x11` |

## Documentation

gst's reference docs are not shipped on the machine — neither under
`/usr/share/doc` nor in the cmacs documentation tree. The source is, at the
exact commit this image was built from:

```bash
remote=$(jq -r '.deps[] | select(.name=="gst") | .remote' /usr/immutablue/deps/dep_info.json)
commit=$(jq -r '.deps[] | select(.name=="gst") | .commit' /usr/immutablue/deps/dep_info.json)
git clone "${remote}" /tmp/gst && git -C /tmp/gst checkout "${commit}"
# docs/configuration.org  docs/keybindings.org  docs/colors.org  docs/c-config.org
# docs/modules/*.org      one file per module, with every option
```
