# cmacs: Configuration and the On-Machine Manuals

cmacs is Immutablue's GNU Emacs fork. It embeds GLib/GObject, the gowl
compositor, the bacon shell, crispy C scripting, AI agents over ai-glib, an MCP
server, the gsurf browser, speech (whisper, piper) and podomation automation as
C primitives. In a gowl session it is also the window manager.

| Command | What it is |
|---|---|
| `emacs` | the editor (the cmacs binary) |
| `emacs --gowl` | the compositor session, Emacs as window manager |
| `emacs --bacon` | the embedded shell |
| `emacs --lrg` | the libregnum/raylib display backend instead of GTK; `--lrg=3d` shows the frame as panels in a 3D scene, `--lrg=3dvr` puts that scene in a VR headset — see [Display backends and VR](#display-backends-and-vr) |
| `emacsctl` / `cmacsctl` | kubectl-style CLI over the D-Bus surface (`org.cmacs.Editor1`) |

**There is no `cmacs` executable on the image.** The binary is `/usr/bin/emacs`
(with `emacsclient`, `emacsctl`, `cmacsctl -> emacsctl` and `cmacs-mcp`). The
manuals, and this skill's older wording, write `cmacs --gowl` for
`emacs --gowl`; `cmacs` is the project name.

Subsystems are gated at build time, so ask the running instance rather than
guessing what is compiled in: `emacsctl instances`, and `emacsctl describe
instance` lists `features[]` (`lrgterm`, `lrgvr`, `gowl`, `ai-brigade`,
`spacemouse`, `camera`, `handtrack`, …). From Elisp the same is
`IS-CMACS-<NAME>` (`IS-CMACS-CAMERA`, …).

**On the `freebsd-be` backend** cmacs comes from the
`quay.io/zachpodbielniak/cmacs:freebsd-15.1` image (cmacs's
`./build-container freebsd-15.1`, `admin/cmacs-build-freebsd.sh`) and lives
under `/usr/local`: `/usr/local/bin/emacs`, the manuals in
`/usr/local/share/emacs/<version>/doc_org/`, the C API libraries in
`/usr/local/lib/cmacs`, registered with the loader by
`/usr/local/libdata/ldconfig/cmacs` (the Linux image uses
`/etc/ld.so.conf.d/cmacs.conf`). It is the same configure flag set, built with
gcc13 and gcc13's libgccjit for native compilation (gcc14's libgccjit corrupts
the heap on FreeBSD), with kqueue file notification. The FreeBSD build bundles
no whisper model or piper voice, so speech features start by downloading one
into your home (`M-x cmacs-whisper-download-model`). bacon's `sandbox` builtin
(Linux namespaces) is not built on FreeBSD. `nucleus` images carry no cmacs on
any backend.

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
| gowl | `~/.config/gowl/config.yaml` and `config.c` (init only), read once when `emacs --gowl` starts; Elisp `gowl-*` and the `cmacs-gowl-*` defcustoms that `cmacs-gowl-mode` pushes over it, `M-x customize-group RET cmacs-gowl` | [`gowl.md`](gowl.md) |
| the bar | plugins in `~/.config/gowl/bar-plugins/`, `M-x gowl-bar-plugin-reload` | [`gowl-bar.md`](gowl-bar.md) |
| gsurf | Elisp `cmacs-gsurf-modules` — **not** gsurf's own YAML, unless opted in | [`gsurf.md`](gsurf.md) |
| gst | its own files; it is a separate program | [`gst.md`](gst.md) |
| `ai` / agents | the ai-glib config cascade, `immutablue ai_setup` | `cmacs-ai.org`, `deps/ai-glib/` |

gowl's YAML is only read by the `emacs --gowl` launch path (unless it sets
`evaluate-gowl-config-with-cmacs: false`). A compositor started later with
`(gowl-start)` reads none, and `(gowl-reload-config)` with no argument
**resets to built-in defaults** rather than rereading the file — pass the path:
`(gowl-reload-config "~/.config/gowl/config.yaml")`.

cmacs's AI features link **cmacs's own copy** of ai-glib, built from cmacs's
submodule pin, not `/usr/bin/ai`. The two can differ: a feature `ai` or `ai-tui`
has may not exist in `M-x cmacs-ai-*` yet, and the reverse. Voice calls
(`ai-call`) and `ai project` are standalone CLIs — see
[`automation.md`](automation.md#voice-sessions-ai-call); cmacs has its own,
offline voice stack — see [Voice](#voice-the-engine-the-always-on-loop-and-spoken-commands).
Details that matter when chatting in cmacs:

- A chat's built-in tools (`bash`, `read`, `write`, `edit`, `multi_edit`,
  `glob`, `grep`, `ls`, `web_fetch`, `web_search`) run on a worker thread, so a
  slow search leaves the editor responsive; `C-c C-k`
  (`cmacs-ai-chat-cancel-stream`) stops a running tool too. Tools registered
  from Lisp (`cmacs-ai-define-tool`), the brigade's tools and `generate_image`
  stay on the main thread.
- A chat opened "in directory" hands that directory to its tools
  (`cmacs-ai-tools-set-working-directory`), for every provider including HTTP
  ones; a relative or omitted `path` resolves against it. Before the fix, an
  HTTP-provider chat searched from `$HOME`, which could hang on a network mount.
- Fix spelling and grammar: `cmacs-ai-proofread` (`f` in the AI command map,
  result in a window) and `cmacs-ai-proofread-in-place` (`F`, asynchronous,
  one undo step). Unlike Rephrase it changes nothing but spelling, grammar and
  punctuation.

### The gowl session from Elisp

Under `emacs --gowl` most of the session is cmacs Elisp. Remapping, macros and
hotkeys ship no rule and load nothing until first used; the IPC socket, the
lock key, the menu, text expansion (gabbrev) and the tag transitions are on by
default. Each row is a section of `gowl.org`:

| Want | Entry point | `gowl.org` section |
|---|---|---|
| Rules, modes, mouse binds, gestures, libinput settings without YAML | `gowl-add-rule-entry`, `gowl-add-keybind-ex`, `gowl-add-mousebind`, `gowl-add-gesture`, `gowl-add-input-setting` | Key modes, pointer binds… |
| Remap keys on one device (a pedal, a macro pad) | `cmacs-gowl-input-remap-define`, `M-x cmacs-gowl-input-remap-identify` | Per-device input remapping |
| Scripted window actions | `cmacs-gowl-macro-run` / `-define` / `-bind`, `cmacs-gowl-macro-triggers`; shell: `emacsctl compositor macro NAME ARGS` | Macros |
| React to windows, focus, outputs, lock | `cmacs-gowl-client-added-functions` and the other `cmacs-gowl-*-functions` hooks | Hooks |
| Per-output settings and dock/undock profiles | `cmacs-gowl-monitor-configs`, `cmacs-gowl-output-profiles`, `M-x cmacs-gowl-apply-output-config` | Monitor settings and profiles from Elisp |
| Drive the session from a shell | `gowl-msg` over `$XDG_RUNTIME_DIR/gowl.sock`; `cmacs-gowl-ipc` moves or disables it | The IPC socket |
| Drive the session from a program (lay out windows, place what you spawn) | the JSON-RPC wire protocol on the same socket: `gowl-msg -d` lists methods, `gowl-msg -c window.set_geometry id=12 …`; processes Emacs starts get `GOWL_SOCKET`. Methods that would move an *embedded* window answer refused (`-32002`) | The IPC socket → The wire protocol |
| AutoHotkey-style hotkeys, remaps, hotstrings, with Elisp functions as actions | `cmacs-gowl-hotkey-define "#!c" #'org-capture`, `cmacs-gowl-hotkey-remaps`, `-hotstrings`, `-scripts` (crispy C); `M-x cmacs-gowl-hotkey-show`, `M-x cmacs-gowl-hotkey-problems`; shell: `emacsctl compositor hotkey status`. Loaded only when `cmacs-gowl-hotkey-enable` is set, something is configured, or a `cmacs-gowl-hotkey-` function is first called | Hotkeys (AutoHotkey); `deps/gowl/hotkey.org` |
| Text expansion in any window (`;today`, `;now`, `;shrug`, `;reword`, `;fix`) | `cmacs-gowl-gabbrev-define`, `cmacs-gowl-gabbrev-builtin` (nil drops the built-ins), `M-x cmacs-gowl-gabbrev-toggle`, `M-x cmacs-gowl-gabbrev-list`; `Super+Alt+e` expands the trigger just typed | Text expansion (gabbrev); `deps/gowl/gabbrev.org` |
| Animated workspace switches | `cmacs-gowl-tag-transition` (default `random`; a name, or `none`), `Super+:` / `M-x cmacs-gowl-cycle-tag-transition`, `M-x cmacs-gowl-set-tag-transition`; standalone gowl defaults to the cube | Tag transitions; `deps/gowl/transitions.org` |
| Move, click and scroll the pointer from Lisp | `gowl-pointer-position`, `gowl-pointer-warp`, `gowl-pointer-move`, `gowl-pointer-button`, `gowl-pointer-scroll`, `gowl-output-geometry` | Driving the pointer from Lisp and C |
| Share one window (not the whole screen) in a call; screenshots through the portal | gowl's own portal backend (ScreenCast, Screenshot, PickColor) from the cmacs image; the picker is `$GOWL_PORTAL_CHOOSER`, else the Super+space menu card, else bemenu/fuzzel/wofi/rofi/dmenu | Input Capture / KVM (deskflow) → *Sharing one window* ([`gowl.md`](gowl.md)) |
| Lock screen | `Super+Shift+l`, `cmacs-gowl-lock-command`, `cmacs-gowl-lock-on-suspend` | Locking the screen |
| Launcher / control menu | `Super+space`, `Super+Shift+space` (adds `$PATH`), `~/.config/gowl/menu.yaml` | The menu |
| HDR | `M-x cmacs-gowl-toggle-hdr`, `cmacs-gowl-hdr-*` | HDR |
| Floating desktop (title bars, dock) on chosen workspaces | `Super+w`, `cmacs-gowl-floatdesk-toggle`, `cmacs-gowl-floatdesk-*` options, `M-x cmacs-gowl-floatdesk-apply-settings`; shell: `emacsctl compositor floatdesk toggle` | Floating desktop |
| Repeat keys typed in one window into a team of windows (multiboxing) | `cmacs-gowl-broadcast-define-team` / `-rule`; `Super+b` toggles, `Super+Shift+b` is the panic key; **nothing is on until you define a team or set `cmacs-gowl-broadcast-enable`** | Input broadcasting |
| Keep the pointer inside the focused window (games, streaming) | `Super+g` (`cmacs-gowl-toggle-pointer-confine`), `Super+Ctrl+Escape` always lets go; per-app: rule `confine-pointer`; shell: `emacsctl compositor confine [on\|off\|toggle\|state]` | Pointer lock → Confining the pointer yourself |
| What every key runs, right now | `Super+?` opens the menu at Keybindings (read live from the compositor), `Super+/` is the same list in a buffer (`cmacs-gowl-describe-keybinds`) | The menu → Keybindings; The keybind cheatsheet |
| Record, replay and speak macros; OCR a region, pick a colour, clipboard history | `cmacs-gowl-macro-record`, `Super+Alt+r`; MCP tools `gowl_macro_*`, `gowl_screen_text`, `gowl_pick_color`, `gowl_clipboard_*` | Macros → Recording and replaying, Voice; MCP tools for macros, the screen and the clipboard |
| AI rewrite of the selected text | `Super+e` (`cmacs-gowl-bar-rewrite-keybind`), the `ai-rewrite` bar widget; the extended widgets are listed in `cmacs-gowl-bar-default-widgets` and use cmacs-ai (`cmacs-gowl-bar-ai-widgets`) | `gowl/bar-widgets-extended.org` ([`gowl-bar.md`](gowl-bar.md)) |

Do not invent names around these: `M-x apropos RET ^cmacs-gowl-` in the running
session, or `rg -n` the section in `gowl.org`, before writing config.

## Voice: the engine, the always-on loop and spoken commands

Everything that uses the microphone or speaks in cmacs goes through one engine
(`cmacs-voice.el`): one 16 kHz capture however many features listen, and one
speech queue, so replies are spoken in order. Push-to-talk features (VR's hold
A/Y, `C-c v v`, dictation, the voice chat, the brigade) take the microphone
ahead of the always-on loop, which shows `Voice:paused` until they finish.
All of it is offline: whisper for speech, Silero for voice detection, piper
for speech output.

| Want | Entry point |
|---|---|
| A conversation you start by name ("Jarvis, what's on my agenda?") | `C-c v l` (`cmacs-voice-loop-mode`); `C-c v j` addresses it without the wake phrase; `M-x cmacs-voice-loop-status` |
| Several names going to different places | `cmacs-voice-loop-wake-phrase` (a string or a list) and `cmacs-voice-loop-routes`: each phrase to `chat`, `commands`, `(agent NAME)` (a brigade task) or a function; `cmacs-voice-loop-default-route` |
| Act on speech with no model in between ("workspace three", "focus firefox", "run rule standup") | `C-c v v` (`cmacs-voice-command`, push-to-talk), or a wake phrase routed to `commands`; `C-c v ?` lists what applies. Destructive actions ask first (`cmacs-voice-confirm-destructive`) |
| Dictation into the buffer | `C-c v d` (`cmacs-whisper-dictate`); text appears dimmed while you talk and lands every 3 s |
| Use a particular microphone | `cmacs-voice-device` — under PipeWire a node *name* (`pw-cli ls Node`, `node.name`) |
| Stop it hearing its own replies through speakers | `M-x cmacs-voice-loop-echo-cancel-config` (`C-u` writes a PipeWire echo-cancel drop-in into `~/.config/pipewire/`), then `cmacs-voice-device "cmacs-echo-cancel-source"` and `cmacs-voice-loop-tts-gating 'none`; or `cmacs-voice-loop-tts-gating 'mute` |

- **Off until you turn it on.** Nothing listens until the mode is enabled;
  audio stays in memory and is wiped after transcription. Speech without the
  wake phrase is transcribed by the small wake model and dropped. Only an
  addressed request's text goes to the chat's provider; `cmacs-voice-loop-save-directory`
  keeps WAVs only if you set it. A wake phrase of nil is an open microphone.
- **Models.** The Linux image ships `ggml-base.en.bin` and a piper voice in
  `/usr/share/cmacs/`. Optional and downloaded by you into your home:
  `M-x cmacs-whisper-download-vad-model` (Silero, about 1 MB — without it an
  energy detector is used, poor in a noisy room) and
  `M-x cmacs-whisper-download-model RET ggml-tiny.en.bin` (cheaper wake-phrase
  spotting).
- The old `cmacs-voice-loop-device`, `-threads`, `-vad-model`, `-voice`, … are
  obsolete aliases of `cmacs-voice-device`, `cmacs-voice-threads`, … — new
  config should use the `cmacs-voice-` names.

The manuals: `cmacs-voice.org` (the engine and the `C-c v` keys),
`cmacs-voice-loop.org` (every option, privacy, troubleshooting),
`cmacs-voice-commands.org` (what you can say, adding commands),
`cmacs-whisper.org`.

## Camera, hand gestures and the SpaceMouse

| Feature | Entry point | Needs |
|---|---|---|
| A camera as a frame source, with a visible "●CAM" indicator and a bar toast | `M-x cmacs-camera-start` / `-stop`, `M-x cmacs-camera-preview`; `cmacs-camera-device` (nil = first camera, `"/dev/video0"`, `"pipewire:SERIAL"`, `"portal"`) | feature `camera` |
| Hands seen by the camera as gestures; one hand as the gowl pointer | `M-x cmacs-handtrack-mode`, `cmacs-handtrack-pointer-mode`, `M-x cmacs-handtrack-describe` | feature `handtrack`, onnxruntime (`(cmacs-handtrack-available-p)`), and the MediaPipe models, **not shipped**: `M-x cmacs-handtrack-download-models` fetches them into your home |
| Tracked hands in VR instead of controllers | automatic when the OpenXR runtime has hand tracking; `cmacs-lrg-vr-hand-tracking` nil turns it off | feature `lrgvr` |
| A 3Dconnexion SpaceMouse orbiting the libregnum scene, the `--lrg=3d` room and VR | `cmacs-spacemouse-mode`, `cmacs-spacemouse-sensitivity`, buttons as `<spacemouse-N>` in `cmacs-spacemouse-mode-map`; `M-x cmacs-spacemouse-describe` | feature `spacemouse`, and the **`spacenavd` daemon, which the image does not ship** — add it to `packages.yaml` ([`building.md`](building.md)); the mode retries every three seconds until it appears |

Frames never touch disk, and nothing opens the camera on its own. Details:
`cmacs-camera.org` (camera and hand tracking), `cmacs-spacemouse.org`, and
*Hand tracking* in `cmacs-lrgterm.org`.

## Display backends and VR

cmacs has three display backends, chosen at launch: GTK/pgtk (plain `emacs`),
tty, and **lrgterm** (`emacs --lrg`), which renders the whole UI through
libregnum/raylib with a GPU glyph atlas. The `Emacs Libregnum` and `Emacs
Libregnum (Client)` launchers start it. A running Emacs (a daemon, say) can open
an lrg frame with `emacsclient --lrg`, and `cmacs-lrg-render-mode` returns the
current frame's mode.

`--lrg=MODE[:ARRANGEMENT:ENVIRONMENT]` picks how the frame is drawn:

| Spec | Result |
|---|---|
| `emacs --lrg` | 2D, a flat window |
| `emacs --lrg=3d` | the frame as panels in a 3D scene on the desktop |
| `emacs --lrg=3dvr` | the same scene in a VR headset through OpenXR (SteamVR including the Steam Frame, Monado, WiVRn) |
| `emacs --lrg=3dvr:per-window:workshop` | the SPEC tail is the `--lrg=3d` one: one panel per window, a grid-floor environment |

VR needs a build with the `lrgvr` feature (check `emacsctl describe instance`;
the image build enables it), an OpenXR runtime that is running, and a headset.
Without one the frame stays a desktop 3D frame and says why on stderr. From a
running 3D frame, `M-x cmacs-lrg-vr-start` / `cmacs-lrg-vr-stop` move it in and
out of the headset; `M-x cmacs-lrg-vr-describe` (`C-c v ?`) reports the runtime,
session state, refresh rate and bound controller profiles.

What to know before touching it:

- **Controllers are ordinary key events.** Buttons arrive as `<vr-a>`,
  `<vr-y-hold>` and so on, with the left hand's trigger, bumper or both acting
  as Shift, Meta or Control *layers*. Rebind them in `cmacs-lrg-vr-mode-map`
  (`(keymap-set cmacs-lrg-vr-mode-map "<vr-y>" #'consult-buffer)`). Hold View or
  the left stick, or `C-c v h`, for the generated sheet of your real bindings.
- **Every controller action has a key under `C-c v`**: `SPC` voice command,
  `i` dictate, `m` quick menu, `o` workspace overview, `n` `]` `[` `w` `q`
  workspaces, `c` recenter, `0` reset the view, `k` in-world keyboard, `+` `-`
  world scale, `?` status. This is also the way to drive VR without wearing it.
- **Tuning** is the `cmacs-lrg-vr` group: `-snap-degrees`, `-move-speed`,
  `-move-hand`, `-scale`, `-frame-size` (default `(1240 . 880)`, about one
  frame pixel per Steam Frame display pixel), `-hold-seconds`, `-dpad-arrows`,
  `-modifier-hand`, and the voice options `-voice-unmatched` and
  `-voice-speak-feedback`. Workspaces stand around you as a 360° desk
  (`cmacs-lrg-3d-workspaces-layout` `desk`; `arc` is the flat desktop's).
- **Environment variables are read when VR starts, before any init file** — set
  them in `~/.config/environment.d/`, not with `setenv`:
  `CMACS_LRG_VR_RESOLUTION` (eye image size as a multiple of the runtime's
  recommendation, default 1.25; 1 is the runtime's size),
  `CMACS_LRG_VR_SHOW_WINDOW=1` (keep the desktop window, hidden by default),
  `CMACS_LRG_VR_NATIVE_GL=1` (do not switch Mesa to zink), `CMACS_LRG_ZINK_REORDER=1`,
  `CMACS_LRG_VR_GL_LOG=1`.
- **On Mesa, `--lrg=3dvr` sets `MESA_LOADER_DRIVER_OVERRIDE=zink`** unless you set
  it first: SteamVR's GL path needs `GL_NV_timeline_semaphore`, which only zink
  and NVIDIA's driver provide. `cmacs-lrg-vr-start` from an already-running
  `--lrg=3d` frame cannot switch drivers — start that frame with the variable
  set.
- **Physical keyboards in VR** are read from `/dev/input/event*` (the user must
  be in the `input` group) with the system XKB layout, and grabbed while the
  VR session has focus.
- **Voice is offline whisper.** Hold A to dictate, Y for a voice command; the
  first use offers to download `ggml-base.en.bin` (about 140 MB) into
  `~/.local/share/cmacs/whisper-models/`. `cmacs-lrg-vr-define-voice-command`
  adds phrases; `M-x cmacs-lrg-vr-voice-help` lists them.
- **The Steam button opens SteamVR's dashboard, which takes the controllers**;
  nothing reaches Emacs until it closes. Emacs says so in the echo area. A
  headset in standby (off your head) keeps the session unfocused.
- `(cmacs-lrg-vr-screenshot "/tmp/vr")` writes `/tmp/vr-eye.png` (what the
  headset is sent) and `/tmp/vr-frame.png`, which separates a rendering fault
  from a runtime one; `emacsctl eval '(cmacs-lrg-vr-screenshot "/tmp/vr")'`
  works over D-Bus.

The full controller tables, the options and the implementation notes are the
*VR mode* section of `cmacs-lrgterm.org`; the 3D scene itself, GNU's Eye and
the other libregnum views are in `cmacs-libregnum.org`.

### Steam Frame and other distros

On SteamOS / the Steam Frame the editor runs from a distrobox, not the image.
cmacs's own build recipes cover that: `just distrobox 44` (alias `just dbox`)
builds and installs cmacs into a box named after the target (`cmacs-fedora-44`,
`cmacs-ubuntu-24.04`, `cmacs-arch`), `just steam-vr-shortcut` then adds *Emacs
VR* to the Steam library (launcher `~/bin/export/emacs-vr`, log
`~/.local/state/cmacs/emacs-vr.log`). The box also links the host's Homebrew and
forwards `podman`, `systemctl`, `rpm-ostree` and similar to the host. It is a
tool for reproducing another distro's build or running on a machine that cannot
use the image, not the way to get cmacs on Immutablue: the image already ships
it. Read `build.org` (*Distrobox builds*) in the manual and
`admin/cmacs-distrobox.sh --help` in a cmacs checkout before relying on it, and
never point it at the host's `/usr`.

## The MCP server

cmacs runs an MCP server in-process, started at init, with tools for Elisp,
buffers, windows, processes, GObject Introspection and the compositor. Clients
reach it through `cmacs-mcp`, a stdio-to-socket relay; `(cmacs-mcp-socket-path)`
names the socket and `cmacs-mcp --socket PATH`, `--name NAME` or
`$CMACS_MCP_SOCKET` pick one explicitly. The gowl tools include
`gowl_macro_run` / `_list` / `_status` / `_stop` / `_record`,
`gowl_macro_voice_match`, `gowl_screen_text` (OCR), `gowl_pick_color`,
`gowl_clipboard_list` / `_entry` / `_copy`, `gowl_broadcast_*` and the hotkey
tools `gowl_hotkey_status` / `_list` / `_history` / `_add` / `_remove` / `_set`
/ `_send` / `_fire`; `podomation_control` with `{"action":"run","pod":NAME}`
runs a pod's rules now (see [`automation.md`](automation.md#podomation-event-driven-automation)). The recorder,
the macro runner, voice matching and the clipboard are *privileged* for the
brigade (named in an allowlist, not swept in by `*`). `gowl_macro_record start`
is refused until `input-recording: true` is consented to in the gowl config.
The reference is `mcp.org`; the gowl tools are under *MCP tools for macros, the
screen and the clipboard* in `gowl.org`.

The socket lives in `$XDG_RUNTIME_DIR` as `cmacs-mcp-<pid>.sock`. When that
path would not fit a `sockaddr_un` (108 bytes) — typically with no
`XDG_RUNTIME_DIR`, so GLib falls back to a deep cache directory — newer cmacs
moves it to a private `$TMPDIR/cmacs-<uid>` (mode 0700, ownership checked);
older ones bound a truncated path and mcp-glib failed with "Cannot identify
bound socket". `cmacs-mcp` with no arguments scans only `$XDG_RUNTIME_DIR`, so
for a socket in the fallback directory pass it explicitly:
`cmacs-mcp --socket "$(emacsctl eval '(cmacs-mcp-socket-path)' -o raw | tr -d '"')"`.

## The manuals are on the machine

Every cmacs build installs its manual, and the manuals of the libraries it
embeds, as org files:

```
/usr/share/emacs/<version>/doc_org/cmacs/
```

`ls -d /usr/share/emacs/*/doc_org` gives the version (on freebsd-be the tree is
under `/usr/local/share/emacs/`). Inside cmacs it is
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
them — so they can be newer or older than their manual here. Compare before
assuming: cmacs `c4ff11f` pins ai-glib `adc932d`, older than the `ai` 0.9.1
the image builds, so its manual has no `benchmark.org` or `decisions.org`
(`ai benchmark`, the TypeSafe and Ollama decision backends); cmacs `28957a8`
moved its ai-glib, bacon and podomation pins up to immutablue's. Before citing `deps/ai-glib/`
for `ai` itself, compare `ai --version` and the `ai-glib` entry in
`/usr/immutablue/deps/dep_info.json` with what the doc describes; a missing doc
(ai-glib's `voice.org` or `projects.org` on an image whose cmacs predates 0.6.0,
say) usually means the binary is ahead of cmacs's pin, and the source at the
recorded commit is the reference.

| Component | cmacs-side docs | Its own docs, embedded |
|---|---|---|
| ai-glib | `cmacs-ai.org`, `cmacs-ai-harness.org`, `ai-brigade/` | `deps/ai-glib/` |
| bacon | `bacon.org` | `deps/bacon/` |
| crispy | `crispy.org`, `api.org` | `deps/crispy/` |
| clawtilla | `clawtilla.org` | `deps/clawtilla/` |
| libreclaw | `libreclaw/` | `deps/libreclaw/` |
| gowl | `gowl.org`, `gowl/` (`bar-widgets*.org`, `multi-display.org`, `screenshot-recording.org`, `clipboard-sync.org`) | `deps/gowl/` (`hotkey.org`, `gabbrev.org`, `transitions.org`, `ipc.org`, …) |
| voice (whisper, piper) | `cmacs-voice.org`, `cmacs-voice-loop.org`, `cmacs-voice-commands.org`, `cmacs-whisper.org`, `cmacs-piper.org` | `deps/piper/` |
| camera, hand tracking, SpaceMouse | `cmacs-camera.org`, `cmacs-spacemouse.org` | — |
| gsurf | `cmacs-gsurf.org` | `deps/gsurf/` |
| libregnum | `cmacs-libregnum.org`, `cmacs-lrgterm.org` (the 3D scene and the VR mode), `cmacs-lrgterm-3d-roadmap.org` | `deps/libregnum/` |
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
| cmacs will not start, or stops at an error | `init.el` signalled | `emacs --debug-init` for the backtrace |
| Is it the config at all? | | `emacs -Q` skips `init.el`, `init.bacon` **and** `init.c` — cmacs only loads the latter two when an init file is in use |
| `init.c` has no effect | a compile or run failure never stops startup: it is caught and raised as a warning | read the `*Warnings*` buffer for `Error loading …/init.c`; `M-: (crispy-run "~/.config/cmacs/init.c")` re-runs it and shows the gcc diagnostic |
| A setting keeps reverting | `init.c` runs after `init.el` and wins | grep both files for it |
| `init.c` worked until an image update | a stale compiled object, or an API that changed | `M-: (crispy-cache-status)` names the cache (`~/.cache/crispy`); move it aside to force a rebuild, and check `api.org` for the call |
| A crispy script crashes | | `crispy --gdb script.c` builds a debug executable and runs it under gdb; `crispy -n` forces a rebuild |
| `emacs --lrg=3dvr` opens a desktop 3D frame, not the headset | no OpenXR runtime or headset; the reason is on stderr | start SteamVR/Monado/WiVRn and put the headset on, `emacsctl describe instance` for `lrgvr`, `M-x cmacs-lrg-vr-describe` once it is up |
| VR is up but the controllers do nothing | SteamVR's dashboard has the input, or the session is only visible (headset in standby, launched outside Steam) | close the dashboard (Steam button again), wear the headset; the echo area says which |
| VR shows a black/white void, or SteamVR logs "GL timeline semaphore requested but no support" | native Mesa GL under SteamVR | do not set `CMACS_LRG_VR_NATIVE_GL`; start with `MESA_LOADER_DRIVER_OVERRIDE=zink` if you launched a plain `--lrg=3d` frame first |
| Text in the headset (or `--lrg`) is scrambled — every glyph a piece of another word | zink reordering buffer uploads on Mesa 26.2 | lrgterm turns it off by default; check `CMACS_LRG_ZINK_REORDER` is not set |
| Physical keyboard does nothing in VR | cannot read `/dev/input/event*` | add the user to the `input` group and log in again |
| `cmacs-mcp` finds no socket, or the MCP server failed with "Cannot identify bound socket" | no `XDG_RUNTIME_DIR` and a deep cache dir overflowed `sun_path` | newer cmacs falls back to `$TMPDIR/cmacs-<uid>`; pass the path to `cmacs-mcp --socket` (see above) |
| `bacon-start` hangs (a cmacs built from source, older than the fix) | the same bacon module `.so` found in two module directories and loaded twice | cmacs now loads each module file name once across the dev-build, installed, cmacs and `$CMACS_MODULE_DIR` directories; on an image this shows up only if you add a duplicate directory |
| An HTTP-provider chat's `glob`/`grep` froze Emacs | tool walk started in `$HOME` over a network mount | newer cmacs and ai-glib resolve against the chat's directory, skip mount points and run off the command loop; `C-c C-k` cancels |
| A feature or command does not exist | not compiled into this build | `emacsctl describe instance`, then the manual for the installed version |
| `emacs --gowl` died with SIGSEGV in `pixman_region32_copy` under `wlr_scene_output_build_state` | cmacs before `46c2bf7`: gowl DEFUNs (`gowl-set-tags`, `gowl-toggle-client-fullscreen`, …) changed the scene from Emacs's thread without the compositor lock | update the image; [`crash-analysis.md`](crash-analysis.md) to confirm the stack |
| The voice loop never wakes | the wake model mishears the name, or the detector hears nothing | `M-x cmacs-voice-loop-status`; check the lighter turns `Voice:hearing` when you talk; install the VAD model; lower `cmacs-voice-loop-wake-threshold` (0.75) or add the misspelling as another phrase |
| The voice loop answers itself | speakers reach the microphone | the echo-cancel config above, a headset, or `cmacs-voice-loop-tts-gating 'mute` |
| A microphone choice is ignored (cmacs before `ddede24`) | the hint was set as `device`, which `pipewiresrc` does not have | newer cmacs passes it as `target-object`; use the PipeWire node name |
| SpaceMouse does nothing | no `spacenavd` (not in the image), or the feature is missing | `M-x cmacs-spacemouse-describe`; add `spacenavd` to `packages.yaml` and enable its service |
| `cmacs-handtrack-mode` says hand tracking is not available | no onnxruntime in this build, or the models are not downloaded | `(cmacs-handtrack-available-p)`; `M-x cmacs-handtrack-download-models` |
| freebsd-be: bacon's `cmacs_gi` (or another program) cannot load `libcmacs-api.so` | a `cmacs:freebsd-15.1` image built before cmacs `28957a8` did not register `/usr/local/lib/cmacs` with the loader | update the image; check `ls /usr/local/libdata/ldconfig/cmacs` and `ldconfig -r \| grep cmacs`; for one process, `LD_LIBRARY_PATH=/usr/local/lib/cmacs` |
| Keybinds and rules vanished after a config reload | `(gowl-reload-config)` with no argument resets to built-in defaults | reload with the YAML path, or re-run the Elisp that set them |
| A gowl macro is refused every time | it faulted or timed out once and is held back, across restarts | `M-x cmacs-gowl-macro-list-macros` (`c` on a line) or `M-x cmacs-gowl-macro-clear` releases it; fix the macro first — the log says what killed it |
| The session returns to the login screen, an Electron app forgets its login, Super keys are dead, keys are stuck in an embedded client | the compositor side | [`gowl.md`](gowl.md#troubleshooting) |
| A gsurf buffer eats keystrokes | the page has focus | [`gsurf.md`](gsurf.md#troubleshooting) |
| cmacs crashed | `/usr/bin/emacs` is an image binary, so the crash watcher sees it | [`crash-analysis.md`](crash-analysis.md) |

Subsystems ship their own troubleshooting pages — agents, libreclaw, bacon,
crispy, audio, speech, video, lrgterm; the index is in
[`troubleshooting.md`](troubleshooting.md#troubleshooting-docs-already-on-the-machine).

## What not to do

- Do not edit anything under `/usr/share/emacs/` (`/usr/local/share/emacs/` on
  freebsd-be) — it is the image, read-only, and replaced on update.
- Do not `setenv` in `init.el` a variable that C code reads at startup, such as
  `CMACS_GOWL_MODULE_DIR`. `setenv` changes `process-environment`, not the
  process environment `g_getenv` sees; set it in `~/.config/environment.d/`.
- Do not describe a feature from upstream cmacs without checking the installed
  manual — if it is not in `doc_org`, it is not on this machine yet.
