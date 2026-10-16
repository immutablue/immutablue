# gowl: Macros and Per-Device Input Remapping

Two opt-in gowl modules that are often used together:

| Module | What it is | Enable |
|---|---|---|
| `macro` | small C files compiled at runtime with crispy, loaded into the compositor, run by name | `modules: macro: {enabled: true}` |
| `inputremap` | remap keys/buttons/wheel on **one physical device** (foot pedal, macro pad, one mouse) | `modules: inputremap: {enabled: true}` |

Neither is in any default module list. With the module off, its YAML section
and its IPC words do nothing — check that first when "nothing happens". Under
cmacs both are loaded by Elisp on first use instead: see [Under cmacs](#under-cmacs).

Everything below is driven through `gowl-msg` (the IPC client, see
[`gowl.md`](gowl.md)); MCP (`macro_*`, `input_remap_*` tools) and D-Bus wrap the
same words. The installed references are `deps/gowl/macros.org` and
`deps/gowl/input-remap.org` under `/usr/share/emacs/*/doc_org/cmacs/`.

## Macros

### Write one

`~/.config/gowl/macros/term-make.c` — first hit on the search path wins, and
`NAME`, `NAME.c` and `NAME.so` all name the same macro:

```c
#include <gowl/gowl.h>

G_MODULE_EXPORT const gchar *
gowl_macro_info(void)
{
	return "Type ARG (default: make) into the terminal, keep focus where it is";
}

G_MODULE_EXPORT gboolean
gowl_macro_run(GowlMacroContext *ctx)
{
	GowlClient *term;
	const gchar *cmd;
	g_autofree gchar *line = NULL;

	cmd  = gowl_macro_get_arg(ctx, 0) != NULL ? gowl_macro_get_arg(ctx, 0) : "make";
	term = gowl_macro_find_client(ctx, "app-id:gst");
	if (term == NULL) {
		gowl_macro_notify(ctx, "term-make", "no terminal open");
		return FALSE;                      /* a failure, not a fault */
	}
	line = g_strdup_printf("%s\n", cmd);
	gowl_macro_text(ctx, term, line);      /* that window only; focus stays put */
	return TRUE;
}
```

```bash
gowl-msg macro-compile term-make            # compile only; the gcc error on one line
gowl-msg macro-run term-make "make -j8"     # args are shell-parsed
gowl-msg macro-list                         # everything runnable by name (JSON)
gowl-msg macro-info term-make               # path, compiled path, threaded, budget
```

There is no rebuild or restart: an edited file recompiles on its next run
(cache in `$XDG_CACHE_HOME/gowl/macros`, keyed by source hash). Extra
compiler flags go in the source: `#define CRISPY_PARAMS "$(pkg-config --cflags --libs foo)"`.

| Search path, first to last | |
|---|---|
| `macro-dir` setting (`:`-separated), then `$GOWL_MACRO_DIR` | your overrides |
| `~/.config/gowl/macros`, `$XDG_DATA_HOME/gowl/macros` | yours — **the place to write** |
| `/etc/gowl/macros`, `/usr/local/share/gowl/macros` | site / local |
| `/usr/share/gowl/macros` | the 25 shipped examples — read these before writing |

A name containing `/` is a path, used as is. `gowl-msg macro-dirs` prints the
path in force.

### The API

| Optional exports and defines | Meaning |
|---|---|
| `gowl_macro_info()` | one line for `macro-list` and the menu |
| `const guint gowl_macro_abi = GOWL_MACRO_ABI;` | a mismatched build is refused, not run |
| `#define GOWL_MACRO_THREADED 1` | run on a worker thread (may sleep, may be slow) |
| `#define GOWL_MACRO_TIMEOUT_MS N` | its time budget; `0` disables the watchdog |

The `#define`s are read from the source text, so write them literally.

**Steps** — queued, played in order after `gowl_macro_run` returns:
`gowl_macro_key(ctx, target, "Super+9")` (modifiers plus ONE key, or `KEY_F13`),
`gowl_macro_key_code`, `gowl_macro_text(ctx, target, "make\n")`,
`gowl_macro_button(ctx, BTN_MIDDLE)`, `gowl_macro_wait(ctx, ms)`,
`gowl_macro_command(ctx, "scratchpad-toggle")`,
`gowl_macro_action(ctx, GOWL_ACTION_SET_LAYOUT, "tile")`, `gowl_macro_focus(ctx, client)`.
A key/text `target` of `NULL` is the focused window **through the
compositor's keybinds**; a `GowlClient` is that window only, with focus left
where it is.

**Helpers** — act now and return: `gowl_macro_find_client(ctx, "app-id:GLOB" | "title:GLOB" | bare-app-id-glob)`,
`gowl_macro_list_clients`, `gowl_macro_sort_clients`, `gowl_macro_move_client`,
`gowl_macro_run_command(ctx, line)` (reply string, free it),
`gowl_macro_call_on_compositor` (required for raw API calls from a threaded macro).

**Context** — `gowl_macro_get_arg/argc/argv`, `gowl_macro_get_trigger`
(`API`, `IPC`, `DBUS`, `EVENT`, `TIMER`, `REMAP`), `gowl_macro_get_trigger_detail`,
`gowl_macro_set_result` (the `macro-run` reply), `gowl_macro_log`,
`gowl_macro_notify` (a toast), `gowl_macro_set_timeout`, `gowl_macro_is_cancelled`.

Two modes, and picking the wrong one freezes the desktop:

| Mode | Runs on | Rules |
|---|---|---|
| timeline (default) | the compositor thread | return quickly; `gowl_macro_sleep()` is refused; use `gowl_macro_wait` steps for pauses; the whole gowl API is callable directly |
| threaded | its own worker | may sleep and take as long as it likes; steps and helpers are marshalled; anything else touching compositor state goes through `gowl_macro_call_on_compositor` |

Network, disk, subprocesses you wait for → threaded.

### Run it from things

```yaml
# ~/.config/gowl/config.yaml
modules:
  macro:
    enabled: true
    triggers:                                   # EVENT [filter]: MACRO ARGS, or every MS
      - "client-added: tidy-on-map"
      - "client-added [app-id=firefox* and monitor=HDMI-A-1]: gather-app firefox*"
      - "focus-changed [app-id=mpv or title~'(?i)youtube']: presentation on"
      - "every 600000 [time>=22:00 and not (weekday=sat or weekday=sun)]: night"
    on-fault: "bar-notify Macro failed|%n: %s"

keybinds:
  "Super+F1": { action: ipc_command, arg: "macro-run term-make 'make -j8'", desc: "make in terminal" }
```

- **Keybind / menu row:** the `ipc_command` action (`ipc-command` also works) with `macro-run NAME ARGS`. The Super+space menu has a *Macros* submenu listing every runnable macro.
- **Event triggers** run from an idle callback *after* the signal, never inside it. Events are compositor signal names: `client-added`, `client-removed`, `focus-changed`, `workspace-switched`, `layout-changed`, `monitor-added`, `lock-changed`, … — an unknown one is reported and skipped.
- **Filters** (the `[...]`) are judged during the emission: `and`/`or`/`not`/parentheses; `field=glob`, `field!=glob`, `field~regex`, `<` `<=` `>` `>=`. Fields: `event`, `app-id`, `title`, `floating`, `fullscreen`, `urgent`, `xwayland`, `focused-app-id`, `focused-title`, `monitor`, `layout`, `tags`, `tag`, `clients`, `arg`, `time`, `hour`, `weekday`. A bad filter refuses that one trigger only.
- **Test a filter before trusting it:** `gowl-msg macro-filter-test --event=focus-changed 'app-id=firefox* and clients>2'`, and `gowl-msg macro-triggers` shows every trigger as parsed with fired/skipped counts.
- **No file at all:** `gowl-msg macro-define web action focus-client app-id:librewolf` (also `command …` and `custom …`).
- **From C** (`config.c` or a module): `gowl_macro_register_func("tidy", fn, data, NULL)` makes a C function runnable by name; `gowl_macro_run_by_name(compositor, name, argv)` runs one.
- **D-Bus:** `dbus: true` owns `org.gowl.Macro1` (`Run`, `Stop`, `List`, `Status`; `Started`/`Finished`/`Faulted` signals).

### When a macro misbehaves

Every call into macro code is under a fault guard: SIGSEGV, SIGBUS, SIGFPE,
SIGILL, SIGABRT and the watchdog (default budget `timeout-ms: 2000`) unwind
the macro instead of the desktop. A faulted macro is then **held back** —
refused until cleared — and the hold survives a restart
(`$XDG_STATE_HOME/gowl/macros.journal`).

```bash
gowl-msg macro-status              # running, held back and why, fault count
gowl-msg macro-stop                # all (or NAME / ID); Super+Escape does the same standalone
gowl-msg macro-clear term-make     # after fixing it
gowl-msg macro-reload              # forget compiled macros, re-read triggers
```

An unwound macro leaks what it allocated and keeps any lock it held — fix the
bug, do not rely on the guard. Settings worth knowing: `macro-dir`,
`timeout-ms`, `max-running` (4), `reentrant`, `stop-key`, `log`
(`none|fault|run|all`), `log-file`, `journal`, `dbus`, `on-fault`,
`on-fault-custom`.

Do not use macros to automate a game or to type secrets.

## Per-device input remapping

### The workflow

```bash
gowl-msg inputremap-devices              # every keyboard and pointer: id, vendor-product, sysname, claimed
gowl-msg inputremap-identify 10          # then press the button on the device…
gowl-msg inputremap-identify-result      # …device identity + the KEY_*/BTN_* it sent
```

Identify only observes; the press still goes where it was going. Then write the
rule into `~/.config/gowl/config.yaml` and reload (`gowl-msg reload`):

```yaml
modules:
  inputremap:
    enabled: true
    log: claim                     # none | claim | match | all
    log-file: ~/.local/state/gowl/inputremap.log

input-remap:
  - name: pedals
    match: { id: "1a86:e026", type: keyboard }   # vendor:product in hex, as lsusb prints it
    unmatched: drop                # what to do with inputs the map does not name (default pass)
    map:
      KEY_A: { button: middle }
      KEY_B: { action: focus-client, arg: "title:World of Warcraft*" }
      KEY_C: { key: "Super+9" }
      KEY_D: { command: "scratchpad-toggle" }
      KEY_E: { macro: focus-or-launch, args: "'app-id:librewolf' librewolf" }
```

`/usr/share/gowl/example-input-remap.yaml` and `example-input-remap.c` are
complete, commented versions.

| `match:` key | Matches |
|---|---|
| `id: "VVVV:PPPP"`, or `vendor:` / `product:` (hex) | libinput ids — prefer these |
| `name: GLOB` | libinput device name (`*`, `?`) — the only option for virtual devices |
| `sysname: "event*"` | kernel sysname |
| `type: keyboard \| pointer \| any` | narrows; not a criterion on its own |

At least one of the first four is required — a rule that matched everything
would claim the keyboard being typed on, so the loader refuses it. Composite
pedals expose a keyboard and a pointer with the same ids; use `type:`.

| Input | Target (one per input) |
|---|---|
| `KEY_*`, `BTN_*` (any kernel name, case-insensitive), raw codes `30` / `0x110` | `pass`, `drop` |
| `left`, `middle`, `right`, `side`, `extra`, `forward`, `back`, `task` | `{key: "Super+9"}` (keysym, resolved against the live layout) or `{key: KEY_F13}` (keycode) |
| `WHEEL_UP`/`DOWN`/`LEFT`/`RIGHT` (whole notches) | `{button: middle}` at the cursor |
| | `{action: NAME, arg: "..."}` — any keybind action |
| | `{command: "LINE"}` — one module IPC line |
| | `{macro: NAME, args: "..."}` — needs the macro module |

**One press → one output, enforced.** A list of targets, two target kinds in
one entry, `a+b` keys, multi-line commands, or `sequence`/`delay`/`repeat`/
`tap`/`hold`/… keys are refused (`NOT_ONE_TO_ONE`) and that rule is skipped;
the others load. The release mirrors the press and remapped keys never
auto-repeat in the compositor. This is what keeps a pedal a hardware remap
under "one keypress, one action" game rules. The `macro` target (and a C or
Elisp callback) is the deliberate exception — it runs code, so keep it out of
the game itself. Pointer motion and touchpad scrolling are never remapped.

Priority: runtime rules (`inputremap-add`) shadow config rules of the same
name; for one input the newest matching rule that names it decides, otherwise
the highest-priority matching rule's `unmatched:` does. Super+Escape on a
claimed keyboard always gets through as an escape hatch.

### At runtime

```bash
gowl-msg 'inputremap-add {name: pad, match: {name: "*Macro Pad*"}, map: {KEY_F13: {action: tag-view, arg: "256"}}}'
gowl-msg inputremap-list           # rules, source (config/runtime), devices each claims
gowl-msg inputremap-status
gowl-msg inputremap-remove pad     # removing a config rule lasts until the next reload
gowl-msg inputremap-log match      # log every remap while debugging
gowl-msg inputremap-disable        # release every device without unloading
```

`inputremap-add` takes flow YAML or JSON; the same validator applies.

### In C config

```c
#include <gowl/gowl.h>
#include <linux/input-event-codes.h>

extern GowlConfig *gowl_config;

G_MODULE_EXPORT gboolean
gowl_config_init(void)
{
	GowlInputRemapRule *rule;

	rule = gowl_input_remap_rule_new("pedals");
	gowl_input_remap_rule_set_match_ids(rule, 0x1a86, 0xe026);
	gowl_input_remap_rule_set_match_type(rule, GOWL_INPUT_REMAP_DEVICE_KEYBOARD);
	gowl_input_remap_rule_map_button(rule, KEY_A, BTN_MIDDLE, NULL);
	gowl_input_remap_rule_map_action(rule, KEY_B, GOWL_ACTION_FOCUS_CLIENT,
	                                 "title:World of Warcraft*", NULL);
	gowl_config_add_input_remap_rule(gowl_config, rule);
	gowl_input_remap_rule_unref(rule);
	return TRUE;
}
```

Also `gowl_input_remap_rule_map_key/command/macro/drop/pass`, and
`gowl_input_remap_rule_map_callback(rule, KEY_C, fn, data, destroy)` — a C
function called on press *and* release (`event->pressed`). A config that maps
a callback stays loaded for the session. The module must still be enabled in
YAML. `gowl --recompile` after editing.

## Under cmacs

cmacs loads neither module from YAML; its Elisp surface loads them on first
use and reinstalls rules and definitions at every compositor start.

```elisp
;; Input remap -- M-x cmacs-gowl-input-remap-identify puts a :match plist on the kill ring
(with-eval-after-load 'cmacs-gowl
  (cmacs-gowl-input-remap-define "pedals"
    :match '(:id "1a86:e026" :type keyboard)
    :unmatched 'drop
    :map '((KEY_A . (button middle))
           (KEY_B . (action focus-client "title:World of Warcraft*"))
           (KEY_C . (macro "focus-or-launch" "app-id:librewolf librewolf"))
           (KEY_D . my/pedal-function))))       ; Elisp, on the press, main thread

;; Macros -- C files by name, and Elisp functions as macros every trigger can name
(cmacs-gowl-macro-bind "Super+F1" "term-make" "make -j8")
(cmacs-gowl-macro-define "snapshot" (lambda (&rest _) (message "%S" (gowl-list-clients))))
(setq cmacs-gowl-macro-triggers                 ; the same strings gowl's YAML takes
      '("client-added: tidy-on-map"
        ("focus-changed" "app-id=mpv" "presentation" "on")))   ; or (EVENT FILTER MACRO ARG...)
```

| | Elisp |
|---|---|
| remap | `cmacs-gowl-input-remap-{define,remove,clear,list,devices,identify,status,enable,disable}`, `cmacs-gowl-input-remap-rules` (defcustom) |
| macros | `cmacs-gowl-macro-{run,bind,define,undefine,stop,clear,compile,reload,new,visit,list-macros,filter-test}`, `cmacs-gowl-macro-definitions`, `cmacs-gowl-macro-triggers`, `cmacs-gowl-macro-fault-functions` |

- The stop key under cmacs is **Super+Alt+Escape** (`cmacs-gowl-macro-stop-key`) — Super+Escape is cmacs's menu.
- A crispy macro must never call Lisp: define the Elisp half with `cmacs-gowl-macro-define` and have the C half run it by name.
- `M-x cmacs-gowl-macro-new` writes a skeleton into your macro directory.

The full Elisp reference is the *Per-device input remapping* and *Macros*
sections of `gowl.org` in the cmacs manual.

## Troubleshooting

| Symptom | Check |
|---|---|
| `macro-run`/`inputremap-*` reply `ERROR unknown command` | the module is not loaded: `enabled: true` and reload; under cmacs, call any `cmacs-gowl-macro-`/`-input-remap-` function |
| `ERROR NAME is held back (...)` | it faulted earlier; fix it, then `gowl-msg macro-clear NAME` |
| A macro does nothing, no error | `gowl-msg macro-compile NAME` for the compile error; `macro-log all` and read the module log |
| The desktop stutters while a macro runs | it is a timeline macro doing slow work — make it threaded |
| A trigger never fires | `gowl-msg macro-triggers` (refused lines, skipped counts) and `macro-filter-test` |
| A pedal is not claimed | `gowl-msg inputremap-devices` — compare its `vendor-product`/`name` with the rule's `match:`; the log at `log: claim` says when a device is claimed |
| The rule is silently missing | it was refused at load (`NOT_ONE_TO_ONE`, no match criterion): the gowl log names it; `gowl --check-config` counts problems |
| A `{macro:}` pedal is logged and dropped | the macro module is not loaded |
| Remap or macro input does nothing while locked | by design: actions, commands, callbacks and macro steps do not run on a locked session |
