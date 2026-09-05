# 07-agents.justfile - AI coding agent harnesses
#
# The harnesses themselves are declared in packages.yaml under
# .immutablue.agent_harnesses, not here, so adding one is a data change rather
# than a code change.
#
# They are installed on demand rather than baked into the image because every
# one of them installs into the user's home, self-updates on its own schedule,
# and is authenticated per user -- none of which survives being put in a
# read-only /usr that is replaced wholesale on the next update.

IMMUTABLUE_PACKAGES := "/usr/immutablue/packages.yaml"


# List the agent harnesses and whether each is installed
[group('agents')]
list_agents:
    #!/bin/bash
    set -euo pipefail

    printf '%-14s %-10s %s\n' "HARNESS" "STATUS" "DESCRIPTION"
    while IFS=$'\t' read -r name bin desc
    do
        if command -v "${bin}" &>/dev/null
        then
            status="installed"
        else
            status="-"
        fi
        printf '%-14s %-10s %s\n' "${name}" "${status}" "${desc}"
    done < <(yq -r '.immutablue.agent_harnesses.all[] | [.name, .bin, .desc] | @tsv' \
                < "{{ IMMUTABLUE_PACKAGES }}")


# Install AI coding agent harnesses (fzf multi-select; TAB to mark, ENTER to confirm)
[group('agents')]
install_agents *names:
    #!/bin/bash
    set -euo pipefail

    packages="{{ IMMUTABLUE_PACKAGES }}"
    requested="{{ names }}"

    # Names can be passed directly for non-interactive use (scripts, a
    # first-boot hook); otherwise fall back to the picker.
    if [[ -n "${requested}" ]]
    then
        selected="${requested}"
    else
        if ! command -v fzf &>/dev/null
        then
            echo "fzf is not installed; pass harness names explicitly, e.g." >&2
            echo "  immutablue install_agents claude-code codex" >&2
            exit 1
        fi

        # The picker shows installed state so an existing harness is not
        # reinstalled by accident, and the preview carries the exact command
        # that will run -- these are all curl-to-shell or npm-global
        # installers, so the user should see what they are agreeing to.
        selected="$(
            yq -r '.immutablue.agent_harnesses.all[] | [.name, .bin, .desc] | @tsv' < "${packages}" \
                | while IFS=$'\t' read -r name bin desc
                  do
                      if command -v "${bin}" &>/dev/null
                      then
                          printf '%s\t[installed] %s\n' "${name}" "${desc}"
                      else
                          printf '%s\t[          ] %s\n' "${name}" "${desc}"
                      fi
                  done \
                | fzf --multi \
                      --delimiter='\t' \
                      --with-nth=1,2 \
                      --header='TAB to mark, ENTER to install, ESC to cancel' \
                      --preview="yq -r '.immutablue.agent_harnesses.all[] | select(.name == \"{1}\") | \"Installs with:\\n  \" + .install' < '${packages}'" \
                      --preview-window=down,4,wrap \
                | cut -f1
        )" || true
    fi

    if [[ -z "${selected}" ]]
    then
        echo "Nothing selected."
        exit 0
    fi

    failed=()
    for name in ${selected}
    do
        install_cmd="$(yq -r ".immutablue.agent_harnesses.all[] | select(.name == \"${name}\") | .install" < "${packages}")"
        bin="$(yq -r ".immutablue.agent_harnesses.all[] | select(.name == \"${name}\") | .bin" < "${packages}")"

        if [[ -z "${install_cmd}" ]] || [[ "${install_cmd}" == "null" ]]
        then
            echo "Unknown harness: ${name}" >&2
            failed+=("${name}")
            continue
        fi

        echo ""
        echo "=== ${name} ==="
        echo "+ ${install_cmd}"

        # Each harness is installed in its own subshell so one failure does not
        # abort the rest of the selection -- these are independent third-party
        # installers and any of them can be down.
        if bash -c "${install_cmd}"
        then
            if command -v "${bin}" &>/dev/null
            then
                echo "${name}: installed (${bin})"
            else
                echo "${name}: installer finished but '${bin}' is not on PATH yet"
                echo "  open a new shell, or check the installer's PATH instructions above"
            fi
        else
            echo "${name}: install failed" >&2
            failed+=("${name}")
        fi
    done

    echo ""
    if [[ ${#failed[@]} -gt 0 ]]
    then
        echo "Failed: ${failed[*]}"
        exit 1
    fi
    echo "Done."
