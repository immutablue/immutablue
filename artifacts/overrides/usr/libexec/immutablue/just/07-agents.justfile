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
