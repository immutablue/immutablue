# gowl: Hotkeys (AutoHotkey for gowl)

The `hotkey` module is AutoHotkey done in the compositor. A hotkey is a key —
in AutoHotkey's notation (`#!t`, `~LButton`, `CapsLock & j`, `^a UP`) or gowl's
(`Super+Alt+t`) — and a list of actions. Around that: remaps (`a::b`), contexts
(`#HotIf`), modes, double taps and long presses, hotstrings, timers, event
hooks, input hooks and the Send language. Hotkeys are decided **before** any
configured keybind and before an app's keyboard-shortcuts-inhibit, so they work
in fullscreen games; the keys they type go through the compositor's own key path,
X11 windows included.

| How gowl runs | Enable |
|---|---|
| standalone `gowl` | **opt-in**: `modules: hotkey: {enabled: true}`. With it off the `hotkey:` section is inert and `hotkey-*` words answer `ERROR unknown command` |
| `emacs --gowl` | loaded when `cmacs-gowl-hotkey-enable` is set, something is configured in Elisp, or a `cmacs-gowl-hotkey-` function is first used — see [Under cmacs](#under-cmacs) |

Which input module to use:

| Want | Use |
|---|---|
| a key/button/wheel runs actions; conditional remaps; layers | `hotkey` (this guide) |
| typed text expands into other text | `gabbrev` — [`gowl-gabbrev.md`](gowl-gabbrev.md); hotstrings here are handed to it |
| a longer program run by name, triggers, recording | `macro` — [`gowl-macros.md`](gowl-macros.md); a hotkey can run one |
| one *device's* keys (foot pedal, macro pad), or a clean modifier swap | `inputremap` — [`gowl-macros.md`](gowl-macros.md) |
| a plain "this chord runs this action" | an ordinary `keybinds:` entry — [`gowl.md`](gowl.md) |

## Quick start

```yaml
# ~/.config/gowl/config.yaml
modules:
  hotkey:  {enabled: true}
  gabbrev: {enabled: true}          # only needed for hotstrings

hotkey:
  hotkeys:
    - {key: "#!t", do: {action: spawn, arg: gst}}        # Super+Alt+t
    - {key: "CapsLock & j", do: {send: "{Down}"}}         # a CapsLock layer
    - {key: "CapsLock", do: {send: "{Esc}"}}              # tapped alone: Escape
  remaps:
    XButton2: MButton
  hotstrings:
    - "::btw::by the way"
```

```bash
gowl-msg reload                    # the module re-reads its section on every config reload
gowl-msg hotkey-problems           # what it could not use, one line each
gowl-msg hotkey-list | jq .        # every hotkey, with its canonical form
gowl-msg hotkey-history            # last 64 inputs: keysym, swallowed?, what fired
```

A mistake costs only the entry it is in.

## Keys

| Symbol | Meaning |
|---|---|
| `#` `!` `^` `+` | Super, Alt, Control, Shift |
| `<` / `>` before one | that hand only: `<^a` is left Control + a |
| `<^>!` | AltGr (Level 3, Mod5) |
| `*` | fire with other modifiers held too (`^a` is exactly Ctrl+a; `*^a` also Ctrl+Shift+a) |
| `~` | fire *and* let the window have the key |
| `$` | never fire on injected input (a Send, a KVM) |
| `KEY UP` | fire on release |
| `A & B` | B while A is held; A then loses its own function and its own hotkey fires on release only if tapped alone |

Key names: one character, AutoHotkey names (`Enter`, `Esc`, `PgUp`, `F1`–`F24`,
`Numpad5`, `Volume_Up`, `Media_Play_Pause`, `LCtrl`, `RAlt`, `LWin`, …), any XKB
keysym (`XF86AudioRaiseVolume`), `code:NN` (an evdev code — `hotkey-history`
shows it), mouse `LButton RButton MButton XButton1 XButton2`, and
`WheelUp/Down/Left/Right` (one press per notch). A modifier alone (`LWin`) fires
on release only if nothing else was pressed. Refused: three-key combinations,
wheel `UP`, a wheel as a prefix.

Entry options: `id:`, `do:` (one action or a list), `context:`, `when:`
(focused window filter), `over:` (window under the pointer), `exists:`,
`absent:`, `mode:`, `double: true|250ms`, `hold: true|1s`, `priority:`,
`level:`, `max-running:` (1), `suspend-exempt:`, `enabled:`, `description:`.
Filters use gowl's filter language (`app-id`, `title`, `exec`, `pid`, `id`,
`floating`, `fullscreen`, `xwayland`, `monitor`, `layout`, `tag(s)`, `time`,
`hour`, `weekday`, `mode`). When several match: highest `priority`, then one with
a context, then more modifiers, then loaded last; the same `id` replaces.

## Actions

`do:` runs in order, never blocking the desktop. Exactly one kind key per action;
a bare string is a gowl command line.

| Kind | Example |
|---|---|
| `action` | `{action: spawn, arg: gst}` — any keybind action |
| `command` | `{command: "view 4"}` — any `gowl-msg` word, modules' included |
| `rpc` | `{rpc: window.center, params: {width: 800}}` — a wire-protocol method |
| `window` | `{window: float}`, `{window: activate, target: "app-id=zoom"}`, `move-by`, `resize`, `tag`, `opacity`, `group-activate` |
| `mouse` | `{mouse: click, button: right, x: 10, y: 10}`; `move` `drag` `wheel` `down` `up` |
| `send` / `send-text` | `{send: "^c{Enter}"}` (AutoHotkey Send syntax); `{send-text: "literal"}` |
| `shell` / `run` | `{shell: "grim ~/s.png"}` (`/bin/sh -c`); `{run: [playerctl, play-pause]}` (no shell); `wait: true` to wait |
| `macro` | `{macro: pip-corner, args: [small]}` — needs `modules: macro:`; the macro sees trigger `HOTKEY` |
| `c` | crispy C body seeing `call`, `comp`, `focused`, `ARG(n)`; or `{c: {file: PATH}}` exporting `gowl_hotkey_action()` |
| `call` | `{call: tidy, args: [x]}` — a `functions:` list, a registered C function, or a `hotkey-func-define` |
| `mode` / `suspend` / `hotkey` / `context` | `{mode: resize}`; `{suspend: toggle}`; `{hotkey: disable, id: X}`; `{context: gaming, value: toggle}` |
| `notify`, `clipboard`, `sleep`, `input`, `capslock`, `numlock`, `reload` | toast; set clipboard; wait; input hook; lock state; re-read sources |
| `custom` (`elisp`) | the embedder's custom action — Elisp under cmacs, inert standalone |

`send-text`, `notify`, `clipboard` and `call` args substitute `{{title}}`,
`{{app-id}}`, `{{key}}`, `{{input}}`, `{{1}}`…; shell lines and programs get them
only as `GOWL_HOTKEY_*` environment variables — a window title is never pasted
into a command line. Keep it that way.

## The rest of the section

```yaml
hotkey:
  contexts:
    browser: "app-id=librewolf or app-id=firefox*"
  hotkeys:
    - {key: "^+d", context: browser, do: {send: "!d!{Enter}"}}
    - {key: "#r", do: {mode: resize}}
    - {id: lock, key: Esc, hold: 1s, do: {command: lock}}  # tap still sends Escape
  modes:
    resize:
      timeout: 2s
      swallow: true                     # unbound keys do nothing in the mode
      hotkeys:
        - {key: h, do: {window: move-by, arg: "-40 0"}}
        - {key: Esc, do: {mode: default}}
  remaps:
    CapsLock: Control_L                 # FROM: TO, press for press
  hotstrings:
    - ":*:;em::ada@example.com"         # typed by gabbrev
  timers:
    - {id: stretch, every: 50m, do: {notify: "stand up"}}
  on:                                   # focus, window-open, window-close, title, tag, monitor, mode, startup, lock, unlock
    window-open:
      - {filter: "app-id=steam", do: [{window: float}]}
  functions:
    tidy: [{rpc: layout.set, params: {name: tile}}]
  include: [hotkeys.d/games.yaml]       # relative to this file
```

- **Remaps** onto a modifier (Caps Lock → Control) work fully. Remapping *a*
  modifier (`LShift: a`) only half works — use `inputremap` or an xkb option
  (`xkb-options: caps:ctrl_modifier`) for a clean swap.
- **Hotstrings** (`:OPTIONS:ABBR::REPLACEMENT`) are translated to gabbrev
  matches: without the `gabbrev` module nothing is typed
  (`hotkey-status` shows `hotstrings-active: false`). Options gabbrev cannot do
  (`B0`, `O`, …) are listed in `hotkey-problems`.
- **Modes** are the compositor's key modes, shared with `keybinds:` `mode:` and
  shown on the bar; `mode: "*"` puts a hotkey in every mode.

## Module settings

Under `modules: hotkey:`:

| Setting | Default | |
|---|---|---|
| `suspend-key` | `Super+Shift+Pause` | suspends every hotkey but itself; `none` for no key |
| `send-mode`, `key-delay` | `input`, 0 | `event` with `key-delay: 10` for apps or games that drop fast keys |
| `send-level` | 0 | level of injected keys (hotkeys of a lower `level:` ignore them, so a send never loops) |
| `accept-synthetic` | false | let a KVM's (deskflow) injected keys fire hotkeys |
| `hotstrings` | true | hand `hotstrings:` to gabbrev |
| `scripts` | — | crispy hotkey scripts, below |
| `c-timeout` | 2000 | ms a C action/function/context may run before the fault guard stops it |
| `dbus` | false | own `org.gowl.Hotkey1` on the session bus (standalone) |
| `toast`, `log` | true, false | |

## From C

`<gowl/gowl.h>` brings `hotkey/gowl-hotkey.h`; it works before the module loads
and survives config reloads. In `config.c`'s `gowl_config_init()`, or in a
**hotkey script** — a C file named in `scripts: [~/.config/gowl/hotkeys.c]`,
built by crispy, rebuilt and re-run on every save, its registrations taken back
first:

```c
#include <gowl/gowl.h>

static void
stash(GowlHotkeyCall *call, gpointer data)
{
	(void)data;
	g_free(gowl_hotkey_command(gowl_hotkey_call_get_compositor(call),
	                           "scratchpad-toggle"));
}

G_MODULE_EXPORT gboolean gowl_hotkey_script_init(void);

G_MODULE_EXPORT gboolean
gowl_hotkey_script_init(void)
{
	GError *error = NULL;

	if (!gowl_hotkey_define("stash", "#!s", stash, NULL, NULL, &error)) {
		g_warning("hotkeys.c: %s", error->message);
		g_error_free(error);
		return FALSE;
	}
	gowl_hotkey_register_func("stash", stash, NULL, NULL);   /* {call: stash} */
	return gowl_hotkey_add_yaml("mine", "hotkeys: [{key: F9, do: {call: stash}}]", NULL);
}
```

Also `gowl_hotkey_register_context(name, predicate, data, destroy)` (a C
`#HotIf`; keep it quick and side-effect free), `gowl_hotkey_set_context(name,
value)`, `gowl_hotkey_send(comp, "^c")`, `gowl_hotkey_send_text`,
`gowl_hotkey_set_mode`, `gowl_hotkey_set_suspended`. An optional
`gowl_hotkey_script_fini()` runs before a rebuild. Every call runs under the
fault guard.

## Driving it

```bash
gowl-msg hotkey-status                   # active, suspended, mode, counts, last error
gowl-msg hotkey-suspend [on|off|toggle]
gowl-msg hotkey-mode [NAME]              # `default` leaves
gowl-msg hotkey-add --id=tmp '{key: F9, do: {notify: hi}}'   # session only; same id replaces
gowl-msg hotkey-remove tmp
gowl-msg hotkey-enable|-disable|-toggle ID; gowl-msg hotkey-fire ID
gowl-msg hotkey-send 'hello{Enter}'; gowl-msg hotkey-send-text 'literal'
gowl-msg hotkey-context-set gaming 1     # a boolean context from outside
gowl-msg hotkey-keystate CapsLock; gowl-msg hotkey-capslock always-off
gowl-msg hotkey-timers; gowl-msg hotkey-cancel; gowl-msg hotkey-reload
gowl-msg -c hotkey.set suspended=true    # JSON-RPC: hotkey.list/.status/.add/.remove/.set/.send/.fire/.call
gowl-msg -s -j hotkey                    # events: fired, mode, suspended, input, fault, ...
```

## Under cmacs

Nothing is loaded by default. `cmacs-gowl-hotkey-enable`, or any of
`cmacs-gowl-hotkey-definitions` (`(KEY FUNCTION . PLIST)`, e.g.
`("#!c" org-capture)`), `-remaps`, `-hotstrings`, `-section` (a whole `hotkey:`
section as YAML or Lisp data), `-scripts`, loads it at compositor start;
`(cmacs-gowl-hotkey-define KEY FUNCTION ...)` loads it on first use. An Elisp
function runs on Emacs's main thread after the key; Elisp contexts
(`cmacs-gowl-hotkey-define-context`) are evaluated on focus/title change, never
while a key waits. `M-x cmacs-gowl-hotkey-list`, `-status`, `-problems`,
`-history`, `-suspend`. Its suspend key is `cmacs-gowl-hotkey-suspend-key`
(`Super+Shift+Pause`). The *Hotkeys (AutoHotkey)* section of `gowl.org` in the
cmacs manual is the reference.

The full module reference — every key name, action, Send escape, a cookbook
and a map from AutoHotkey — is `deps/gowl/hotkey.org` under
`/usr/share/emacs/*/doc_org/cmacs/` (`hotkey.org.in` beside it is the template it
is generated from; read `hotkey.org`). gowl's `example-hotkey*.yaml`/`.c` are not
installed on the image; `hotkey.org` embeds them.

## Troubleshooting

| Symptom | Check |
|---|---|
| `hotkey-*` → `ERROR unknown command`, `hotkey:` section ignored | module not enabled: `modules: hotkey: {enabled: true}` |
| A hotkey does not fire | press it, then `gowl-msg hotkey-history`: no entry = module off or suspended; an entry that fired nothing = compare with `canonical` in `hotkey-list` (`^a` ≠ Ctrl+Shift+a; use `*^a`), and its `context`/`mode`/`enabled` |
| A line in the config was dropped | `gowl-msg hotkey-problems` |
| Every key does nothing | a `swallow: true` mode is entered (`hotkey-mode default`), or suspended (`Super+Shift+Pause`, `hotkey-suspend off`) |
| Hotstrings type nothing | `gabbrev` module not loaded (`hotkey-status` → `hotstrings-active: false`); one without `*` waits for an end character |
| Sent text comes out wrong / dropped keys | `send-mode: event`, `key-delay: 10` |
| A C action is held back | it crashed or exceeded `c-timeout`: `hotkey-status` `last-error`; fix, `hotkey-reload` |
| Caps Lock still toggles | only a *swallowed* Caps Lock has its toggle undone; `~CapsLock` passes by design |
| A KVM's keys do not trigger hotkeys | `accept-synthetic: true` (`$` hotkeys still refuse them) |
| Do not | use hotkeys to automate gameplay a game's rules forbid, or to type secrets |
