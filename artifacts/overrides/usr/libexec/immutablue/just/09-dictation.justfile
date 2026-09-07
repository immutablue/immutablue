# 09-dictation.justfile - Push-to-talk voice-to-text (voxtype)
#
# voxtype ships in the image; the model, the daemon and the keybinding are
# per-user and are set up on demand by these recipes.
#
# The model is not in the image on purpose: it is 150 MB of per-user data that
# would be replaced wholesale on every image update, and the user may well want
# a different one.

VOXTYPE_CONFIG_TEMPLATE := "/usr/share/immutablue/voxtype/config.toml"
DICTATE_KEYBIND_PATH    := "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/immutablue-dictate/"
DICTATE_KEYBIND         := "<Super>d"


# Set up dictation: config, model, daemon, and the Super+D keybinding
[group('dictation')]
enable_dictation model="":
    #!/bin/bash
    set -euo pipefail

    if ! command -v voxtype &>/dev/null
    then
        echo "voxtype is not installed -- this is a GUI variant feature." >&2
        exit 1
    fi

    config="${HOME}/.config/voxtype/config.toml"

    # Never clobber a config the user has tuned. The template is only ever a
    # starting point, and `voxtype configure` edits the user copy afterwards.
    if [[ -f "${config}" ]]
    then
        echo "Config already present at ${config} -- leaving it alone."
    else
        mkdir -p "$(dirname "${config}")"
        cp "{{ VOXTYPE_CONFIG_TEMPLATE }}" "${config}"
        echo "Seeded ${config}"
    fi

    # Downloading the model is the slow step and the one that needs network.
    # Do it before touching the daemon so a failure here leaves nothing half
    # configured.
    echo
    if [[ -n "{{ model }}" ]]
    then
        # --activate matters: `setup --download` fetches a model without
        # selecting it, so a named model would land on disk and the daemon
        # would carry on loading the one already in the config. Only pass it
        # when a model was actually named, so the default path leaves a config
        # the user may have tuned alone.
        voxtype setup --download --model "{{ model }}" --activate --no-post-install
    else
        voxtype setup --download --no-post-install
    fi

    echo
    voxtype setup systemd
    systemctl --user enable --now voxtype.service

    immutablue bind_dictation_key

    # Under GNOME the whole typing path depends on a system service the user
    # has to start themselves. Without it dictation still "works" -- the text
    # lands on the clipboard instead of at the cursor -- which is a confusing
    # way to find out, so say it here rather than letting it be discovered.
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] \
        && ! systemctl is-active --quiet ydotool.service 2>/dev/null
    then
        echo
        echo "NOTE: GNOME cannot use wtype, so typing goes through ydotool,"
        echo "      whose daemon is not running. Until you start it, transcriptions"
        echo "      land on the clipboard instead of at the cursor:"
        echo
        echo "        sudo systemctl enable --now ydotool.service"
    fi

    echo
    echo "Dictation is ready. Press Super+D to start, Super+D again to stop."
    echo "Check it with: immutablue dictation_status"


# Bind Super+D to dictation toggle (GNOME); no-op elsewhere
[group('dictation')]
bind_dictation_key:
    #!/bin/bash
    set -euo pipefail

    # Only GNOME's settings-daemon owns this schema. Under gowl the keybinding
    # belongs in the compositor config, so say so rather than silently doing
    # nothing that looks like success.
    if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]
    then
        echo "Not a GNOME session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})."
        echo "Bind this in your compositor config instead:"
        echo "    voxtype record toggle"
        exit 0
    fi

    path="{{ DICTATE_KEYBIND_PATH }}"
    schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${path}"

    gsettings set "${schema}" name    'Dictate (voxtype)'
    gsettings set "${schema}" command 'voxtype record toggle'
    gsettings set "${schema}" binding '{{ DICTATE_KEYBIND }}'

    # The list of custom keybindings is a single array in the user's dconf
    # database, which is why this cannot ship as a system default: a user with
    # any custom keybinding of their own has their whole array in user-db, and
    # user-db shadows system-db entirely. Appending to whatever is already
    # there is the only way to add one without discarding the rest.
    python3 - "${path}" <<'PY'
    import subprocess, sys

    path = sys.argv[1]
    key = ("org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings")

    current = subprocess.run(["gsettings", "get", *key],
                             capture_output=True, text=True, check=True).stdout.strip()

    # "@as []" is how an empty array comes back; anything else is a GVariant
    # list literal that ast.literal_eval handles once the type prefix is gone.
    if current.startswith("@as "):
        current = current[4:]
    import ast
    try:
        paths = list(ast.literal_eval(current))
    except (ValueError, SyntaxError):
        print(f"Could not parse existing keybinding list: {current!r}", file=sys.stderr)
        sys.exit(1)

    if path in paths:
        print(f"Already bound: {path}")
        sys.exit(0)

    paths.append(path)
    literal = "[" + ", ".join(f"'{p}'" for p in paths) + "]"
    subprocess.run(["gsettings", "set", *key, literal], check=True)
    print(f"Added {path} ({len(paths)} custom keybindings total)")
    PY

    echo "Super+D -> voxtype record toggle"


# Show dictation status: daemon, model, typing backend, keybinding
[group('dictation')]
dictation_status:
    #!/bin/bash
    # No -e: every probe is allowed to fail and still leave a useful report.
    set -uo pipefail

    echo "── voxtype ──────────────────────────────────────────────────"
    if command -v voxtype &>/dev/null
    then
        printf '  %-22s %s\n' "binary" "$(command -v voxtype)"
        printf '  %-22s %s\n' "version" "$(voxtype --version 2>/dev/null | head -1)"
    else
        echo "  not installed"
        exit 0
    fi

    printf '  %-22s %s\n' "config" \
        "$([[ -f "${HOME}/.config/voxtype/config.toml" ]] && echo "${HOME}/.config/voxtype/config.toml" || echo '(not seeded)')"

    echo
    echo "── daemon ───────────────────────────────────────────────────"
    if systemctl --user list-unit-files voxtype.service &>/dev/null
    then
        printf '  %-22s %s\n' "enabled" "$(systemctl --user is-enabled voxtype.service 2>&1)"
        printf '  %-22s %s\n' "active"  "$(systemctl --user is-active  voxtype.service 2>&1)"
    else
        echo "  no user unit -- run: immutablue enable_dictation"
    fi
    voxtype status 2>/dev/null | sed 's/^/  /'

    echo
    echo "── typing backend ───────────────────────────────────────────"
    # Which driver can actually work depends on the session, not on what is
    # installed: wtype needs wlr-virtual-keyboard-v1, which GNOME does not
    # implement, and ydotool needs its daemon holding /dev/uinput.
    for b in wtype ydotool wl-copy
    do
        printf '  %-22s %s\n' "${b}" "$(command -v "${b}" || echo 'not installed')"
    done
    printf '  %-22s %s\n' "session" "${XDG_CURRENT_DESKTOP:-unset}"
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]
    then
        echo "  GNOME ignores wtype; ydotool or the clipboard fallback carries this session."
        if ! systemctl is-active --quiet ydotool.service 2>/dev/null
        then
            echo "  ydotoold is NOT running -- typing will fall back to the clipboard."
            echo "  start it with: sudo systemctl enable --now ydotool.service"
        fi
    fi

    echo
    echo "── keybinding ───────────────────────────────────────────────"
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]
    then
        schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{{ DICTATE_KEYBIND_PATH }}"
        binding="$(gsettings get "${schema}" binding 2>/dev/null)"
        command_="$(gsettings get "${schema}" command 2>/dev/null)"
        if [[ -n "${binding}" && "${binding}" != "''" ]]
        then
            printf '  %-22s %s -> %s\n' "bound" "${binding}" "${command_}"
        else
            echo "  not bound -- run: immutablue bind_dictation_key"
        fi
    else
        echo "  compositor-managed (bind 'voxtype record toggle' in your config)"
    fi


# Stop dictation and remove the Super+D keybinding
[group('dictation')]
disable_dictation:
    #!/bin/bash
    set -uo pipefail

    systemctl --user disable --now voxtype.service 2>/dev/null \
        && echo "Stopped and disabled voxtype.service"

    if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]
    then
        python3 - "{{ DICTATE_KEYBIND_PATH }}" <<'PY'
    import ast, subprocess, sys

    path = sys.argv[1]
    key = ("org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings")
    current = subprocess.run(["gsettings", "get", *key],
                             capture_output=True, text=True, check=True).stdout.strip()
    if current.startswith("@as "):
        current = current[4:]
    try:
        paths = [p for p in ast.literal_eval(current) if p != path]
    except (ValueError, SyntaxError):
        sys.exit(0)
    literal = "[" + ", ".join(f"'{p}'" for p in paths) + "]" if paths else "@as []"
    subprocess.run(["gsettings", "set", *key, literal], check=True)
    print("Removed the Super+D dictation keybinding")
    PY
    fi

    echo
    echo "The config and the downloaded model are left in place."
    echo "Remove them with: rm -rf ~/.config/voxtype ~/.local/share/voxtype"
