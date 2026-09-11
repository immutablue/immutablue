# 07-agents.justfile - AI coding agent harnesses
#
# The harnesses are declared in packages.yaml under
# .immutablue.agent_harnesses, so adding one is a data change rather than a
# code change. The logic lives in /usr/libexec/immutablue/immutablue-agents;
# these recipes are the interactive front end to it.
#
# They are installed on demand rather than baked into the image because every
# one installs into the user's home, self-updates on its own schedule, and is
# authenticated per user -- none of which survives a read-only /usr that is
# replaced wholesale on the next update.

IMMUTABLUE_AGENTS := "/usr/libexec/immutablue/immutablue-agents"


# List the agent harnesses, where each is installed, and what it is
[group('agents')]
list_agents:
    #!/bin/bash
    set -euo pipefail
    {{ IMMUTABLUE_AGENTS }} list


# Install agent harnesses: no args picks with fzf, or name(s), or 'all'
[group('agents')]
install_agents *names:
    #!/bin/bash
    set -euo pipefail

    agents="{{ IMMUTABLUE_AGENTS }}"
    requested="{{ names }}"

    # Explicit names bypass the picker entirely. That matters beyond
    # convenience: an fzf picker hangs where there is no terminal, so a script
    # or a pre_update hook has to be able to name what it wants.
    if [[ -n "${requested}" ]]
    then
        exec "${agents}" install ${requested}
    fi

    if ! command -v fzf &>/dev/null
    then
        echo "fzf is not installed; name the harnesses explicitly instead:" >&2
        echo "  immutablue install_agents claude-code codex" >&2
        echo "  immutablue install_agents all" >&2
        exit 1
    fi

    # The picker is built from the same `list` output the plain command shows,
    # so the two never disagree about what is installed. The header row is
    # dropped and the columns are already aligned by immutablue-agents.
    #
    # --layout=reverse puts the prompt at the top and reads downward, which is
    # the natural direction for a list you are choosing from. --with-nth hides
    # nothing: the whole aligned row is the label, and the harness name is
    # recovered from the first field afterwards.
    selected="$(
        "${agents}" list \
            | tail -n +2 \
            | fzf --multi \
                  --layout=reverse \
                  --height='60%' \
                  --border=rounded \
                  --border-label=' agent harnesses ' \
                  --prompt='install > ' \
                  --pointer='▸' \
                  --marker='✓ ' \
                  --header=$'TAB to mark \u00b7 ENTER to install \u00b7 ESC to cancel\nalready-installed harnesses are skipped' \
                  --header-first \
                  --preview="${agents} list | awk -v n={1} 'NR==1 || \$1==n' ; echo ; echo 'Installs with:' ; yq -r \".immutablue.agent_harnesses.all[] | select(.name == \\\"{1}\\\") | \\\"  \\\" + .install\" < /usr/immutablue/packages.yaml" \
                  --preview-window='down,7,wrap,border-top' \
            | awk '{ print $1 }'
    )" || true

    if [[ -z "${selected}" ]]
    then
        echo "Nothing selected."
        exit 0
    fi

    exec "${agents}" install ${selected}


# Reinstall a harness even if it is already present
[group('agents')]
reinstall_agent name:
    #!/bin/bash
    set -euo pipefail
    {{ IMMUTABLUE_AGENTS }} install --force {{ name }}


# ═══════════════════════════════════════════════════════════════════════════
# The built-in harness: `ai` (ai-glib), the /immutablue skill, and crash triage
# ═══════════════════════════════════════════════════════════════════════════
#
# `ai` ships in the image rather than being installed on demand like the
# harnesses above -- it is built from /usr/src/gitlab/ai-glib as part of the
# build, so it is present on first boot and needs no vendor installer.

IMMUTABLUE_CRASH := "/usr/libexec/immutablue/immutablue-crash"
IMMUTABLUE_SKILL_SRC := "/usr/share/immutablue/skills/immutablue"


# Choose the default AI provider and model interactively (ai --setup)
[group('agents')]
ai_setup:
    #!/bin/bash
    set -euo pipefail

    if ! command -v ai &>/dev/null
    then
        echo "'ai' is not installed. It ships with the image, so this variant" >&2
        echo "either predates it or is a headless build without ai-glib." >&2
        exit 1
    fi

    # `ai` is copied in from the deps container, which is built and pushed on its
    # own schedule -- so a freshly built image can still carry an older ai-glib
    # than the submodule in the repo. --setup is recent enough for that to bite,
    # and the bare failure ("Unknown option --setup") explains nothing. Probe for
    # it and say what is actually wrong.
    if ! ai --help 2>&1 | grep -q -- '--setup'
    then
        echo "This image's 'ai' predates --setup." >&2
        echo >&2
        echo "It comes from the deps container, which is rebuilt separately:" >&2
        echo "    make build-deps && make push-deps    # then rebuild the image" >&2
        echo >&2
        echo "Until then, write the defaults by hand:" >&2
        echo "    mkdir -p ~/.config/ai-glib" >&2
        echo "    cat > ~/.config/ai-glib/config.yaml <<'YAML'" >&2
        echo "    apps:" >&2
        echo "      ai:" >&2
        echo "        default_provider: claude-code" >&2
        echo "        default_model: sonnet" >&2
        echo "    YAML" >&2
        echo >&2
        echo "Providers: $(ai --list-providers 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ' ')" >&2
        exit 1
    fi

    # `ai --setup` writes the user scope, ~/.config/ai-glib/config.yaml, which is
    # the top of a three-file cascade:
    #
    #   /usr/share/ai-glib/config.yaml   image defaults  (read-only)
    #   /etc/ai-glib/config.yaml         system override
    #   ~/.config/ai-glib/config.yaml    this file       (highest priority)
    #
    # Each overrides the previous, and environment variables override all three
    # at access time -- so an AI_PROVIDER in the environment beats what is set
    # here. `ai -p default -m default` deliberately bypasses AI_PROVIDER and uses
    # the saved defaults, which is what the crash analysis uses.
    exec ai --setup


# Show the resolved AI defaults and where they came from
[group('agents')]
ai_defaults:
    #!/bin/bash
    set -uo pipefail

    echo "── binaries ─────────────────────────────────────────────────"
    if command -v ai &>/dev/null
    then
        printf '  %-22s %s\n' "ai" "$(command -v ai) ($(ai --version 2>/dev/null | head -1))"
    else
        echo "  'ai' is not installed"
    fi
    if command -v ai-tui &>/dev/null
    then
        printf '  %-22s %s\n' "ai-tui" "$(command -v ai-tui)"
        # The crash analysis pipes its prompt in, which older builds reject.
        printf '  %-22s %s\n' "piped prompt" \
            "$(ai-tui --help 2>&1 | grep -qi 'piped prompt' && echo 'supported' || echo 'NOT supported -- rebuild deps')"
    else
        echo "  'ai-tui' is not installed"
    fi
    printf '  %-22s %s\n' "AI_PROVIDER (env)" "${AI_PROVIDER:-unset}"

    # ai and ai-tui keep INDEPENDENT defaults. Setting one does not set the
    # other, which is worth stating plainly: `immutablue analyze_crash` runs
    # ai-tui, so configuring only the `ai` scope leaves the crash path on the
    # built-in fallback rather than the model that was chosen.
    echo
    echo '  ai and ai-tui have separate saved defaults; ai --setup asks which.'

    echo
    echo "── config cascade (lowest priority first) ───────────────────"
    for f in /usr/share/ai-glib/config.yaml \
             /etc/ai-glib/config.yaml \
             "${HOME}/.config/ai-glib/config.yaml"
    do
        if [[ -f "${f}" ]]
        then
            echo "  ${f}"
            sed 's/^/      /' "${f}"
        else
            echo "  ${f}  (absent)"
        fi
    done

    echo
    echo "Change the user scope with: immutablue ai_setup"


# Install the /immutablue skill into every agent harness that reads skills
[group('agents')]
install_immutablue_skill:
    #!/bin/bash
    set -euo pipefail

    src="{{ IMMUTABLUE_SKILL_SRC }}"
    if [[ ! -d "${src}" ]]
    then
        echo "ERROR: skill not found at ${src}" >&2
        exit 1
    fi

    # One skill directory, symlinked into each harness's own location, so an
    # image update updates every harness at once and there is no copy to drift.
    # The source is under /usr and therefore read-only -- an agent cannot edit
    # the skill that is telling it not to edit /usr.
    #
    # These paths are not guesses: they are the user-scope rows of ai-glib's
    # resource registry, which is the thing that actually resolves /immutablue.
    # The harnesses genuinely disagree -- ~/.claude/skills is read by four of
    # them, ~/.agents/skills by three -- so the union is what gets full coverage.
    #
    # ai-glib's own ~/.config/ai-glib/skills is deliberately NOT linked. ai-glib
    # also searches ~/.agents/skills, so a second link there only made `ai` find
    # the same skill twice.
    declare -A targets=(
        ["${HOME}/.claude/skills"]="claude-code, grok, opencode, cursor"
        ["${HOME}/.agents/skills"]="ai, opencode, cursor"
        ["${HOME}/.grok/skills"]="grok"
        ["${HOME}/.gemini/config/skills"]="antigravity"
        ["${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills"]="opencode"
        ["${HOME}/.cursor/skills"]="cursor"
    )

    linked=0
    for dir in "${!targets[@]}"
    do
        link="${dir}/immutablue"

        # An existing real directory is someone's own skill of the same name.
        # Replacing it would destroy their work, so refuse and say so.
        if [[ -e "${link}" && ! -L "${link}" ]]
        then
            echo "SKIP  ${link}"
            echo "      exists and is not a symlink -- not touching it"
            continue
        fi

        mkdir -p "${dir}"
        ln -sfn "${src}" "${link}"
        printf 'LINK  %-52s (%s)\n' "${link}" "${targets[${dir}]}"
        linked=$(( linked + 1 ))
    done

    # Older installs also linked into ai-glib's own directory. Remove that link,
    # but only when it is ours -- anything else under that name is the user's.
    legacy="${XDG_CONFIG_HOME:-${HOME}/.config}/ai-glib/skills/immutablue"
    if [[ -L "${legacy}" ]] && [[ "$(readlink -f "${legacy}")" == "$(readlink -f "${src}")" ]]
    then
        rm -f "${legacy}"
        printf 'UNLINK %-51s (legacy: ai reads ~/.agents/skills)\n' "${legacy}"
    fi

    echo
    echo "Installed ${linked} skill link(s) -> ${src}"
    echo
    echo "Invoke it explicitly with /immutablue, or let the model load it itself:"
    echo "    ai \"/immutablue why does rpm-ostree install take so long\""


# Remove the /immutablue skill links
[group('agents')]
uninstall_immutablue_skill:
    #!/bin/bash
    set -uo pipefail

    src="{{ IMMUTABLUE_SKILL_SRC }}"
    removed=0

    # ai-glib/skills is no longer linked by install_immutablue_skill, but stays
    # in this list so a link left by an older install is still removed.
    for dir in "${XDG_CONFIG_HOME:-${HOME}/.config}/ai-glib/skills" \
               "${HOME}/.claude/skills" \
               "${HOME}/.agents/skills" \
               "${HOME}/.grok/skills" \
               "${HOME}/.gemini/config/skills" \
               "${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills" \
               "${HOME}/.cursor/skills"
    do
        link="${dir}/immutablue"

        # Only remove a symlink that points at the shipped skill. Anything else
        # under that name belongs to the user.
        if [[ -L "${link}" ]] && [[ "$(readlink -f "${link}")" == "$(readlink -f "${src}")" ]]
        then
            rm -f "${link}"
            echo "removed ${link}"
            removed=$(( removed + 1 ))
        fi
    done

    echo "Removed ${removed} link(s)."


# Pick a crash with fzf and hand it to the AI agent for analysis
[group('agents')]
analyze_crash pid="":
    #!/bin/bash
    set -euo pipefail

    crash="{{ IMMUTABLUE_CRASH }}"

    # A named PID skips the picker: a picker hangs where there is no terminal,
    # so a script or a notification action has to be able to name one.
    if [[ -n "{{ pid }}" ]]
    then
        exec "${crash}" analyze "{{ pid }}"
    fi

    if ! command -v fzf &>/dev/null
    then
        echo "fzf is not installed; name a PID instead:" >&2
        echo "  immutablue-crash list --all" >&2
        echo "  immutablue analyze_crash <pid>" >&2
        exit 1
    fi

    # --all here, unlike the watcher: the watcher stays quiet about binaries
    # under $HOME because a developer crashes those on purpose, but when someone
    # deliberately opens this picker they may well be looking for exactly one of
    # those. The CLASS column keeps the distinction visible.
    selected="$(
        "${crash}" list --all \
            | tail -n +2 \
            | fzf --layout=reverse \
                  --height='70%' \
                  --border=rounded \
                  --border-label=' crashes, newest first ' \
                  --prompt='analyze > ' \
                  --pointer='▸' \
                  --header=$'ENTER to analyze · ESC to cancel\nCLASS system = shipped by the image; user = yours' \
                  --header-first \
                  --preview="${crash} prepare {1} >/dev/null 2>&1; coredumpctl info {1} 2>&1 | head -60" \
                  --preview-window='right,60%,wrap,border-left' \
            | awk '{ print $1 }'
    )" || true

    if [[ -z "${selected}" ]]
    then
        echo "Nothing selected."
        exit 0
    fi

    exec "${crash}" analyze "${selected}"


# List crashes of image-shipped binaries, newest first
[group('agents')]
crashes:
    #!/bin/bash
    set -uo pipefail
    {{ IMMUTABLUE_CRASH }} list


# List every crash, including binaries under your home directory
[group('agents')]
crashes_all:
    #!/bin/bash
    set -uo pipefail
    {{ IMMUTABLUE_CRASH }} list --all


# Start notifying about crashes of image-shipped binaries
[group('agents')]
crash_watch_enable:
    #!/bin/bash
    set -euo pipefail

    systemctl --user enable --now immutablue-crash-watch.service
    echo "Crash notifications on."
    echo
    echo "Only binaries the image shipped are announced -- anything under your"
    echo "home directory is ignored, because a crash while developing is not news."
    echo "See everything with: immutablue crashes_all"

    if ! command -v ai &>/dev/null
    then
        echo
        echo "NOTE: 'ai' is not installed, so a notification has nothing to hand"
        echo "      the crash to. Evidence is still collected for reading."
    elif [[ ! -e "${HOME}/.config/ai-glib/config.yaml" ]]
    then
        echo
        echo "NOTE: no AI defaults are saved yet. Set them with:"
        echo "        immutablue ai_setup"
    fi


# Stop notifying about crashes
[group('agents')]
crash_watch_disable:
    #!/bin/bash
    set -uo pipefail
    systemctl --user disable --now immutablue-crash-watch.service
    echo "Crash notifications off. Crashes are still recorded by systemd-coredump."


# Show crash watch and coredump state
[group('agents')]
crash_watch_status:
    #!/bin/bash
    set -uo pipefail

    echo "── watcher ──────────────────────────────────────────────────"
    printf '  %-22s %s\n' "enabled" "$(systemctl --user is-enabled immutablue-crash-watch.service 2>&1)"
    printf '  %-22s %s\n' "active"  "$(systemctl --user is-active  immutablue-crash-watch.service 2>&1)"

    echo
    echo "── coredump storage ─────────────────────────────────────────"
    # Without storage there is nothing to analyse, however good the watcher is.
    for key in Storage Compress MaxUse KeepFree ProcessSizeMax
    do
        printf '  %-22s %s\n' "${key}" \
            "$(grep -rhs "^${key}=" /usr/lib/systemd/coredump.conf.d/ /etc/systemd/coredump.conf.d/ /etc/systemd/coredump.conf 2>/dev/null | tail -1 | cut -d= -f2)"
    done
    printf '  %-22s %s\n' "stored now" "$(coredumpctl list --no-pager --no-legend 2>/dev/null | wc -l)"

    echo
    echo "── agent ────────────────────────────────────────────────────"
    printf '  %-22s %s\n' "ai" "$(command -v ai || echo 'not installed')"
    printf '  %-22s %s\n' "defaults saved" \
        "$([[ -e "${HOME}/.config/ai-glib/config.yaml" ]] && echo yes || echo 'no -- run: immutablue ai_setup')"
    printf '  %-22s %s\n' "skill installed" \
        "$([[ -L "${HOME}/.claude/skills/immutablue" || -L "${HOME}/.agents/skills/immutablue" ]] && echo yes || echo 'no -- run: immutablue install_immutablue_skill')"
