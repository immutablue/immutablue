# cmacs: Configuration and the On-Machine Manuals

cmacs is Immutablue's GNU Emacs fork. It embeds GLib/GObject, the gowl
compositor, the bacon shell, crispy C scripting, AI agents over ai-glib, an MCP
server, the gsurf browser, speech (whisper, piper) and podomation automation as
C primitives. In a gowl session it is also the window manager.

| Command | What it is |
|---|---|
| `cmacs` | the editor |
| `cmacs --gowl` | the compositor session, Emacs as window manager |
| `cmacs --bacon` | the embedded shell |
| `emacsctl` / `cmacsctl` | kubectl-style CLI over the D-Bus surface (`org.cmacs.Editor1`) |

Subsystems are gated at build time, so ask the running instance rather than
guessing what is compiled in: `emacsctl instances`.

## Configuration files

| File | Language | Found in | Loaded by |
|---|---|---|---|
| `init.el` | Elisp | `user-emacs-directory` | Emacs, as usual |
| `init.bacon` | bacon | `~/.config/cmacs/`, then `user-emacs-directory` | `bacon-source` |
| `init.c` | C, via crispy | `~/.config/cmacs/`, then `user-emacs-directory` | `crispy-run` |

They load at startup in that order: `init.el`, `init.bacon`, `init.c`.
`user-emacs-directory` is `~/.emacs.d/` if that exists, otherwise
`~/.config/emacs/` — check with `M-: user-emacs-directory` instead of assuming.

**Someone's init may be C, not Elisp.** Before changing startup behaviour, read
both `init.el` and `~/.config/cmacs/init.c`; a setting that "has no effect" in
one is often being overwritten by the other, which runs later.

### init.c

`init.c` is a crispy script: compiled with gcc on first load, cached by SHA256,
dlopened into the Emacs process, and its `main()` called on the main thread.
The cmacs API headers and library are injected automatically — no
`CRISPY_PARAMS` needed.

```c
/* ~/.config/cmacs/init.c */
#include <cmacs-api.h>

int main(int argc, char **argv)
{
    CmacsApi *api = cmacs_api_new(NULL);
    if (!api) return 1;

    cmacs_theme(api, "modus-vivendi");
    cmacs_font(api, "Iosevka", 14);
    cmacs_set(api, "inhibit-startup-screen", "t");
    cmacs_eval(api, "(setq custom-file (concat user-emacs-directory \"custom.el\"))");
    cmacs_message(api, "init.c loaded");

    cmacs_api_free(api);
    return 0;
}
```

`M-: (crispy-run "~/.config/cmacs/init.c")` re-runs it in a live session.
`cmacs-config-load-crispy` (default `t`) and `cmacs-config-directory` (default
`~/.config/cmacs`) control discovery. The full C API is `api.org` in the
manuals below.

## Configuring the embedded components

| Component | Configured under cmacs by | Guide |
|---|---|---|
| gowl | `~/.config/gowl/config.yaml` and `config.c` (init only), read once when `cmacs --gowl` starts; Elisp `gowl-*` and the `cmacs-gowl-*` defcustoms that `cmacs-gowl-mode` pushes over it, `M-x customize-group RET cmacs-gowl` | [`gowl.md`](gowl.md) |
| the bar | plugins in `~/.config/gowl/bar-plugins/`, `M-x gowl-bar-plugin-reload` | [`gowl-bar.md`](gowl-bar.md) |
| gsurf | Elisp `cmacs-gsurf-modules` — **not** gsurf's own YAML, unless opted in | [`gsurf.md`](gsurf.md) |
| gst | its own files; it is a separate program | [`gst.md`](gst.md) |
| `ai` / agents | the ai-glib config cascade, `immutablue ai_setup` | `cmacs-ai.org`, `deps/ai-glib/` |

gowl's YAML is only read by the `cmacs --gowl` launch path (unless it sets
`evaluate-gowl-config-with-cmacs: false`). A compositor started later with
`(gowl-start)` reads none, and `(gowl-reload-config)` with no argument
**resets to built-in defaults** rather than rereading the file — pass the path:
`(gowl-reload-config "~/.config/gowl/config.yaml")`.

cmacs's AI features link **cmacs's own copy** of ai-glib, built from cmacs's
submodule pin, not `/usr/bin/ai`. The two can differ: a feature `ai` or `ai-tui`
has (`ai loop`, `/goal`, `--check-update`) may not exist in `M-x cmacs-ai-*`
yet, and the reverse.

### The gowl session from Elisp

Under `cmacs --gowl` most of the session is cmacs Elisp. Remapping and macros
ship no rule and load nothing until first used; the IPC socket, the lock key and
the menu are on by default. Each row is a section of `gowl.org`:

| Want | Entry point | `gowl.org` section |
|---|---|---|
| Rules, modes, mouse binds, gestures, libinput settings without YAML | `gowl-add-rule-entry`, `gowl-add-keybind-ex`, `gowl-add-mousebind`, `gowl-add-gesture`, `gowl-add-input-setting` | Key modes, pointer binds… |
| Remap keys on one device (a pedal, a macro pad) | `cmacs-gowl-input-remap-define`, `M-x cmacs-gowl-input-remap-identify` | Per-device input remapping |
| Scripted window actions | `cmacs-gowl-macro-run` / `-define` / `-bind`, `cmacs-gowl-macro-triggers`; shell: `emacsctl compositor macro NAME ARGS` | Macros |
| React to windows, focus, outputs, lock | `cmacs-gowl-client-added-functions` and the other `cmacs-gowl-*-functions` hooks | Hooks |
| Per-output settings and dock/undock profiles | `cmacs-gowl-monitor-configs`, `cmacs-gowl-output-profiles`, `M-x cmacs-gowl-apply-output-config` | Monitor settings and profiles from Elisp |
| Drive the session from a shell | `gowl-msg` over `$XDG_RUNTIME_DIR/gowl.sock`; `cmacs-gowl-ipc` moves or disables it | The IPC socket |
| Lock screen | `Super+Shift+l`, `cmacs-gowl-lock-command`, `cmacs-gowl-lock-on-suspend` | Locking the screen |
| Launcher / control menu | `Super+space`, `Super+Shift+space` (adds `$PATH`), `~/.config/gowl/menu.yaml` | The menu |
| HDR | `M-x cmacs-gowl-toggle-hdr`, `cmacs-gowl-hdr-*` | HDR |

Do not invent names around these: `M-x apropos RET ^cmacs-gowl-` in the running
session, or `rg -n` the section in `gowl.org`, before writing config.

## The manuals are on the machine

Every cmacs build installs its manual, and the manuals of the libraries it
embeds, as org files:

```
/usr/share/emacs/<version>/doc_org/cmacs/
```

`ls -d /usr/share/emacs/*/doc_org` gives the version. Inside cmacs it is
`(expand-file-name "../doc_org/cmacs/" data-directory)`.

- `M-x cmacs-manual` opens the index, `cmacs.org`.
- `M-x cmacs-manual-topic` completes over every `.org` and `.md` in the tree,
  including `deps/<dep>/…` — for example `deps/ai-glib/architecture`.

**Prefer these over memory and over the web.** The tree is generated from
cmacs's own submodule checkouts at the cmacs build, so it describes cmacs and
everything linked into it; upstream `master` may already differ. An agent can
search it directly:

```bash
rg -l -i 'bar-plugin' /usr/share/emacs/*/doc_org/cmacs
```

A dependency's `docs/` directory lands as `deps/<dep>/` — the `docs/` level is
dropped, so ai-glib's `docs/cli.org` is `deps/ai-glib/cli.org` and podomation's
`docs/modules/registry.org` is `deps/podomation/modules/registry.org`.

**`deps/<dep>/` follows cmacs's pin, not the standalone binary's.** `ai`,
`ai-tui`, `podomation` and `bacon` on `$PATH` are built from immutablue's own
`deps/` submodules — cmacs links in its own copies, and where it ships the
same files (podomation and bacon modules) the image installs immutablue's over
them — so they can be newer or older than their manual here. Before citing `deps/ai-glib/` for `ai` itself, compare
`ai --version` and the `ai-glib` entry in `/usr/immutablue/deps/dep_info.json`
with what the doc describes; a missing doc (ai-glib's `updating.org` or
`loops-and-goals.org`, say) usually means the binary is ahead of cmacs's pin, and
the source at the recorded commit is the reference.

| Component | cmacs-side docs | Its own docs, embedded |
|---|---|---|
| ai-glib | `cmacs-ai.org`, `cmacs-ai-harness.org`, `ai-brigade/` | `deps/ai-glib/` |
| bacon | `bacon.org` | `deps/bacon/` |
| crispy | `crispy.org`, `api.org` | `deps/crispy/` |
| clawtilla | `clawtilla.org` | `deps/clawtilla/` |
| libreclaw | `libreclaw/` | `deps/libreclaw/` |
| gowl | `gowl.org`, `gowl/` | `deps/gowl/` |
| gsurf | `cmacs-gsurf.org` | `deps/gsurf/` |
| libregnum | `cmacs-libregnum.org`, `cmacs-lrgterm.org` | `deps/libregnum/` |
| podomation | `podomation.org` | `deps/podomation/` |

Also embedded: `cad-glib`, `graylib`, `manifold`, `mcp-glib`, `orm-glib`,
`piper`, `screensavers`, `yaml-glib`. Other cmacs topics worth knowing:
`overview.org`, `api.org`, `dbus/`, `emacsctl/`, `mcp.org`, `evil.org`.

Check with `ls` before citing a file: the tree matches the installed build. A
component added to cmacs after that build — clawtilla on older images — has no
docs here until the image is rebuilt. **gst is not in this tree at all**; see
[`gst.md`](gst.md).

The stock GNU Emacs manuals are alongside, also as org: `doc_org/emacs/`
(the user manual), `doc_org/lispref/` (the Elisp reference),
`doc_org/lispintro/`, `doc_org/misc/`, `doc_org/man/`. `M-x info` works as
usual.

## Troubleshooting

```bash
emacsctl instances              # is it running, which build, which is primary
emacsctl describe instance      # features[] -- what this build has compiled in
emacsctl logs -f                # *Messages*, live
emacsctl events recent 50       # the last editor events, as JSON
journalctl --user -b -t emacs   # what cmacs wrote to stderr
```

| Symptom | Cause | Fix |
|---|---|---|
| cmacs will not start, or stops at an error | `init.el` signalled | `cmacs --debug-init` for the backtrace |
| Is it the config at all? | | `cmacs -Q` skips `init.el`, `init.bacon` **and** `init.c` — cmacs only loads the latter two when an init file is in use |
| `init.c` has no effect | a compile or run failure never stops startup: it is caught and raised as a warning | read the `*Warnings*` buffer for `Error loading …/init.c`; `M-: (crispy-run "~/.config/cmacs/init.c")` re-runs it and shows the gcc diagnostic |
| A setting keeps reverting | `init.c` runs after `init.el` and wins | grep both files for it |
| `init.c` worked until an image update | a stale compiled object, or an API that changed | `M-: (crispy-cache-status)` names the cache (`~/.cache/crispy`); move it aside to force a rebuild, and check `api.org` for the call |
| A crispy script crashes | | `crispy --gdb script.c` builds a debug executable and runs it under gdb; `crispy -n` forces a rebuild |
| A feature or command does not exist | not compiled into this build | `emacsctl describe instance`, then the manual for the installed version |
| Keybinds and rules vanished after a config reload | `(gowl-reload-config)` with no argument resets to built-in defaults | reload with the YAML path, or re-run the Elisp that set them |
| A gowl macro is refused every time | it faulted or timed out once and is held back, across restarts | `M-x cmacs-gowl-macro-list-macros` (`c` on a line) or `M-x cmacs-gowl-macro-clear` releases it; fix the macro first — the log says what killed it |
| The session returns to the login screen, an Electron app forgets its login, Super keys are dead, keys are stuck in an embedded client | the compositor side | [`gowl.md`](gowl.md#troubleshooting) |
| A gsurf buffer eats keystrokes | the page has focus | [`gsurf.md`](gsurf.md#troubleshooting) |
| cmacs crashed | `/usr/bin/emacs` is an image binary, so the crash watcher sees it | [`crash-analysis.md`](crash-analysis.md) |

Subsystems ship their own troubleshooting pages — agents, libreclaw, bacon,
crispy, audio, speech, video, lrgterm; the index is in
[`troubleshooting.md`](troubleshooting.md#troubleshooting-docs-already-on-the-machine).

## What not to do

- Do not edit anything under `/usr/share/emacs/` — it is the image, read-only,
  and replaced on update.
- Do not `setenv` in `init.el` a variable that C code reads at startup, such as
  `CMACS_GOWL_MODULE_DIR`. `setenv` changes `process-environment`, not the
  process environment `g_getenv` sees; set it in `~/.config/environment.d/`.
- Do not describe a feature from upstream cmacs without checking the installed
  manual — if it is not in `doc_org`, it is not on this machine yet.
