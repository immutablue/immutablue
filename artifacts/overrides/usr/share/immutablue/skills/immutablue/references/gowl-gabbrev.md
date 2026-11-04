# gowl: Text Expansion (gabbrev)

`gabbrev` is gowl's text expander — espanso, done in the compositor. Type
`;today` in any window and it becomes `2026-10-19`; `;shrug` becomes `¯\_(ツ)_/¯`.
The compositor already sees every key on its way to a window, knows which
window that is, and can type into it without moving focus, so there is no
daemon, no `/dev/input` access and no virtual keyboard.

The configuration format is **espanso's, as a superset**: an existing espanso
directory (`config/default.yml`, `config/*.yml` app profiles, `match/`,
packages, `imports`, `global_vars`) loads unchanged.

| How gowl runs | Enable |
|---|---|
| standalone `gowl` | **opt-in**: `modules: gabbrev: {enabled: true}` — with it off nothing watches keys and the `gabbrev-*` words answer `ERROR unknown command` |
| `emacs --gowl` | always loaded; configured from Elisp — see [Under cmacs](#under-cmacs) |

Related guides: [`gowl.md`](gowl.md) (the compositor, `gowl-msg`),
[`gowl-hotkey.md`](gowl-hotkey.md) (its hotstrings are typed by gabbrev),
[`gowl-macros.md`](gowl-macros.md) (a match can run a macro),
[`gowl-bar.md`](gowl-bar.md) (the `gabbrev` widget).

## Quick start

```yaml
# ~/.config/gowl/config.yaml
modules:
  gabbrev:
    enabled: true

gabbrev:                       # a match file, shifted under one key
  matches:
    - trigger: ";sig"
      replace: |
        Best,
        Zach
    - trigger: "teh"
      replace: "the"
      word: true               # only as a whole word
      propagate_case: true     # Teh -> The
  # espanso: true              # also load $XDG_CONFIG_HOME/espanso
  # files: [snippets.d/]       # relative to config.yaml
```

```bash
gowl-msg reload                 # or Super+Shift+r; gabbrev reloads with the config
gowl-msg gabbrev-test ';sig'    # which match would fire in the focused window, and why not
gowl-msg gabbrev-status | jq .problems
```

Edited match files outside `config.yaml` reload by themselves (inotify,
debounced 300 ms); `gowl-msg gabbrev-reload` forces it.

## How it behaves

- A trigger fires **on its last character**. A `word`/`right_word` trigger fires
  on the separator typed after it. So no trigger may be the start of another:
  with `;le` defined, `;lenny` can never be typed.
- Typing is forgotten on a click, an arrow, Home/PgUp/Escape, any key with
  Ctrl/Alt/Super held, or a different window — a trigger fires only when typed
  in one go, in one place.
- When several fire, the longest wins; between equals, the one loaded last —
  which is how your `;today` replaces the built-in one.
- **Backspace right after an expansion undoes it** (`undo_backspace`, on).
- Text goes in as keys or as a paste: `backend: auto` (default) types short
  text the layout can type, pastes the rest (`¯\_(ツ)_/¯` is pasted). `keys`
  (`inject`) always types; `clipboard` always pastes; `text-input` commits it
  like an input method (text-input-v3: no keymap, no clipboard, one undo step;
  needs a GTK/Qt/Firefox/Chromium text field, else falls back to keys after
  250 ms). `force_mode:` overrides per match.
- Terminals get Ctrl+Shift+V; the module knows `gst`, `foot`, `kitty`,
  `alacritty`, `wezterm`, `ghostty`, GNOME Terminal/Console, Konsole, xterm…
  (`terminals: "+my-term"` adds).
- Pastes are marked like a password manager's copy
  (`x-kde-passwordManagerHint`), so gowl's clipboard history, cmacs's kill ring
  and Klipper/CopyQ skip them; `clipboard-history: true` stops marking.
- **Never in password prompts**: the default `deny-filter` covers password
  managers, pinentry, polkit and password-titled windows. `"+EXPR"` adds to it,
  any other expression replaces it, `none` removes it — do not.

## Matches and variables

| Match key | Meaning |
|---|---|
| `trigger`, `triggers`, `regex` | what fires it (a regex sees the last 30 chars, named groups become variables) |
| `replace` | the text: `{{var}}`, `{{var.field}}`, `$\|$` for the cursor |
| `vars` | variables, resolved in order |
| `word`, `left_word`, `right_word`, `propagate_case`, `uppercase_style` | boundaries and case |
| `form`, `image_path`, `html` | a form shorthand, a picture, rich text (always pasted) |
| `filter` | gowl's filter language: where it may fire |
| `filter_class`, `filter_title`, `filter_exec` | espanso's regexes on one match |
| `force_mode`, `paste_shortcut`, `delete_first`, `notify`, `timeout`, `id`, `label` | per-match behaviour |

| Variable `type` | Value |
|---|---|
| `echo`, `date` (`format`, `offset` s, `tz`; `%o` is `st/nd/rd/th`), `random`, `clipboard`, `env`, `uuid`, `file` | the obvious |
| `shell` (`cmd`; **bash** by default), `script` (`args`) | the output; earlier values arrive as `$GABBREV_NAME` / `$ESPANSO_NAME` |
| `choice`, `form`, `search` | a picker (`picker-command`, else the first of fuzzel/bemenu/wofi/tofi/rofi; the minibuffer under cmacs) |
| `selection` (`scope: primary\|clipboard\|line\|word\|paragraph\|all`) | text grabbed from the window, so the replacement goes over it |
| `window` (`field: app-id\|title\|exec\|pid\|monitor\|layout\|tag`) | a fact about the target window |
| `macro` (`name`, `args`, `wait`) | runs a gowl macro and types what it gave `gowl_macro_set_result()` — needs `modules: macro:` |
| `c` (`code`, `file`, or `func`) | crispy C in the compositor, under the fault guard, 500 ms budget (`c-timeout-ms`) |
| `match`, `global` | another match rendered; a global variable here |

```yaml
gabbrev:
  matches:
    - trigger: ";standup"
      replace: "Yesterday: {{y}}\nToday: \nBlockers: none"
      filter: "app-id ~ '(?i)slack|element' and weekday != sat and weekday != sun"
      vars:
        - {name: y, type: date, params: {format: "%A", offset: -86400}}
    - trigger: ";wins"
      replace: "{{n}} windows open"
      vars:
        - {name: n, type: macro, params: {name: count-windows}}
    - trigger: ";branch"
      replace: "{{b}}"
      vars:
        - {name: b, type: shell, params: {cmd: "git -C ~/src/app branch --show-current"}}
```

Filter fields: `app-id` (`class`), `title`, `exec`, `pid`, `xwayland`,
`floating`, `fullscreen`, `monitor`, `layout`, `tag`, `tags`, `time`, `hour`,
`weekday`, `trigger`; `and`/`or`/`not`, `=`/`!=` globs, `~`/`!~` regexes.
App-specific *profiles* (espanso's `config/*.yml`, or `profiles:` inline) switch
options per window — `{name: games, filter: "fullscreen = true", enable: false}`.

Everything is asynchronous: a slow shell command, picker or model never
stalls the desktop, the trigger stays visible until the text is ready, and a
failed variable leaves the window as it was. Each expansion has a 2-minute
budget (`timeout`).

## Built-in matches

On unless `builtin: false`; `gowl-msg gabbrev-builtin` prints them as YAML.
Give a trigger again to replace one.

| Group | Triggers |
|---|---|
| Dates | `;today` (= `;date`), `;htoday` (October 19th, 2026), `;mtoday` (20261019); the same three for `;yesterday`/`;hyesterday`/`;myesterday` and `;tomorrow`/`;htomorrow`/`;mtomorrow`; `;now`, `;hnow`, `;mnow`, `;iso`, `;time`, `;htime`, `;week`, `;dow`, `;month`, `;epoch` |
| Faces | `;shrug`, `;tableflip`, `;unflip`, `;lenny`, `;disapprove` |
| Symbols | `;->` `;<-` `;=>` `;<=` `;>=` `;!=` `;+-` `;inf` `;deg` `;em` `;en` `;...` `;bullet` `;check` `;cross` `;copy` `;reg` `;tm` `;euro` |
| Session | `;uuid`, `;user`, `;host`, `;clip`, `;lorem` |
| AI | `;reword`, `;fix` — grab the current line, pipe it through the `ai` CLI (ai-glib; needs a configured provider), paste the answer over it. cmacs uses its own AI instead |

## The expand key, usage, learning

- **Expand key**: bind `gabbrev-search` (`search_shortcut: Super+Alt+e` in the
  section, or a keybind `{action: ipc_command, arg: gabbrev-search}`). If the
  text before the cursor ends with a trigger, it expands it whatever its word
  rules; otherwise it opens a picker seeded with the word being typed, and the
  pick replaces that word. `gabbrev-search-all` is the plain picker.
  `toggle_key: ALT` (double-tap) switches expansion off and on.
- **Usage counts** (`stats`, on): `gowl-msg gabbrev-stats [--unused]` — prune
  what never fires. Kept in `$XDG_STATE_HOME/gowl/gabbrev-stats.tsv`.
- **Learning** (`learn: true`, off by default, in memory only): phrases of 2–8
  words typed `learn-min-count` (3) times are proposed as triggers
  (`gabbrev-suggestions`). `gabbrev-accept [--trigger T] PHRASE` appends one to
  `~/.config/gowl/gabbrev-learned.yml`; `gabbrev-dismiss PHRASE` drops it. Never
  counts denied windows, terminals (`learn-terminals`), synthetic input, or
  runs containing a digit or symbol.
- **Pending expansions**: one still resolving after `pending-toast-ms` (1500)
  gets a toast; `gabbrev-cancel [JOB]` stops it. The bar's `gabbrev` widget
  lists them with a cancel each, plus suggestions and usage —
  [`gowl-bar.md`](gowl-bar.md).

## Module settings

Under `modules: gabbrev:` (the format options above go in the `gabbrev:`
section or a match file instead):

| Setting | Default | |
|---|---|---|
| `start-on`, `builtin`, `toast`, `stats`, `watch` | true | expand from start; shipped matches; toasts; usage counts; auto-reload |
| `learn`, `learn-terminals`, `clipboard-history`, `log`, `expand-synthetic` | false | see above; `expand-synthetic` expands KVM/injected typing |
| `files` | — | more match sources |
| `deny-filter`, `terminals` | built-in | `+` adds to the default |
| `picker-command`, `prompt-command` | autodetect | dmenu-style; rows on stdin, prompt in `$GABBREV_PROMPT` |
| `learn-min-count`, `learn-toast`, `learned-file`, `stats-file` | 3, true, `~/.config/gowl/gabbrev-learned.yml`, `$XDG_STATE_HOME/gowl/gabbrev-stats.tsv` | |
| `max-jobs`, `c-timeout-ms`, `cache-dir`, `pending-toast-ms` | 8, 500, `$XDG_CACHE_HOME/gowl/gabbrev`, 1500 | |

## Driving it

```bash
gowl-msg gabbrev-toggle                      # also gabbrev-on, gabbrev-off
gowl-msg gabbrev-list [TEXT]                 # JSON, with uses / last-used
gowl-msg gabbrev-add --name mine '{matches: [{trigger: ";x", replace: "y"}]}'   # runtime; same name replaces
gowl-msg gabbrev-load --name team ~/team/snippets.yml
gowl-msg gabbrev-remove mine; gowl-msg gabbrev-clear
gowl-msg gabbrev-expand ';sig'               # as if typed (by id)
gowl-msg gabbrev-insert 'any text'           # type text into the focused window
gowl-msg -s | grep '^EVENT gabbrev'          # expanded, failed, pending, suggestion, ...
```

From a macro: `gowl_macro_command(ctx, "gabbrev-insert text")`. From C
(`config.c`, before or after the module loads, surviving reloads):
`gowl_gabbrev_add_file("~/.config/espanso")`, `gowl_gabbrev_add_yaml(yaml,
&error)`, `gowl_gabbrev_register_func(name, fn, data, destroy)` for
`type: c, params: {func: NAME}`, and `gowl_gabbrev_register_var_type()` for a
whole new variable type (`<gowl/gowl.h>`, declared in `gabbrev/gowl-gabbrev.h`).

## Under cmacs

`emacs --gowl` loads the module at every compositor start
(`cmacs-gowl-gabbrev-start`) and pushes its defcustoms:
`cmacs-gowl-gabbrev-matches`, `-files`, `-espanso`, `-options`,
`-module-settings`, `-builtin`, `-learn`, `-deny-filter`, `-enable`. The expand
key is **Super+Alt+e** (`cmacs-gowl-gabbrev-search-key`); pickers are the
minibuffer; `type: elisp` variables run Lisp (`cmacs-gowl-gabbrev-define-type`,
`-define-function`). `M-x cmacs-gowl-gabbrev-list` (usage columns),
`cmacs-gowl-gabbrev-suggestions`, `-test`, `-status`, `-toggle`, `-reload`. The
YAML `gabbrev:` section lives on the compositor's config, so it applies too when
cmacs evaluated `config.yaml` (the default — see [`gowl.md`](gowl.md#under-cmacs)).
The *Text expansion* part of `gowl.org` in the cmacs manual has the rest.

The full reference is `deps/gowl/gabbrev.org` (and
`deps/gowl/bar-widgets/gabbrev.org`) under
`/usr/share/emacs/*/doc_org/cmacs/`. gowl's `example-gabbrev.yaml`/`.c` are not
installed on the image; the doc carries the same examples.

## Troubleshooting

| Symptom | Check |
|---|---|
| `gabbrev-*` → `ERROR unknown command` | module not enabled: `modules: gabbrev: {enabled: true}`, reload |
| Nothing expands | `gowl-msg gabbrev-test TRIGGER` — says the match, whether the window is denied or a profile disabled it; `gabbrev-status` `.on` |
| A longer trigger never fires | a shorter trigger is its prefix and fires first — rename one |
| Expands garbled / wrong characters | layout cannot type them: `force_mode: clipboard`, or `backend: clipboard`; slow app: `key_delay: 5` |
| Paste lands as the old clipboard | app reads the clipboard slowly: raise `pre_paste_delay`, `post_paste_delay` |
| `text-input` backend types keys instead | the app has no text-input-v3 field focused; `gabbrev-status` shows `focused-text-input` |
| An edit to a match file does not apply | `gabbrev-status` `.watching`; `auto_restart: false` somewhere disables watching; `gowl-msg gabbrev-reload` |
| A `macro` variable fails | the `macro` module is not enabled standalone |
| `;reword`/`;fix` fail | the `ai` CLI has no provider configured, or timed out — run `ai` by hand |
| Config problem | `gowl-msg gabbrev-status \| jq .problems` — each bad key/regex/file costs only itself |
