# 08-rollback.justfile - Deployment rollback, rebase discovery, and snapshots
#
# Immutablue publishes an 18-variant matrix, and the tags are not guessable from
# the running system: knowing you are on '44' tells you nothing about whether
# '44-cyan', '44-trueblue' or '44-lts' exist for the version you want. Rebasing
# therefore meant reading the docs, or the Makefile, to hand-type a tag.
#
# These recipes discover the options instead -- deployments from the local
# system, tags from the registry, snapshots from immutablue-snapshot -- and
# present them through fzf.

IMMUTABLUE_IMAGE := "quay.io/immutablue/immutablue"


# Show the current deployment and what is available to roll back to
[group('rollback')]
deployments:
    #!/bin/bash
    set -euo pipefail

    if command -v bootc &>/dev/null
    then
        echo "=== bootc status ==="
        bootc status || true
        echo ""
    fi

    echo "=== rpm-ostree deployments ==="
    rpm-ostree status


# Roll back to the previous deployment
[group('rollback')]
rollback:
    #!/bin/bash
    set -euo pipefail

    # rpm-ostree keeps exactly one previous deployment, so there is nothing to
    # choose between -- the useful thing is showing what the rollback lands on
    # before doing it, since the pending/rollback distinction is easy to
    # misread in the raw status output.
    echo "Current deployments:"
    rpm-ostree status
    echo ""

    if ! rpm-ostree status | grep -q "^  ostree-\|^  quay\|^●"
    then
        echo "Could not read deployments." >&2
        exit 1
    fi

    read -r -p "Roll back to the previous deployment and reboot? [y/N] " answer
    case "${answer}" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            echo "Cancelled."
            exit 0
            ;;
    esac

    sudo rpm-ostree rollback
    echo ""
    echo "Rollback staged. Reboot to apply:  systemctl reboot"


# Rebase onto another Immutablue variant, chosen from the registry
[group('rollback')]
rebase tag="":
    #!/bin/bash
    set -euo pipefail

    image="{{ IMMUTABLUE_IMAGE }}"
    tag="{{ tag }}"

    # Tags come from the registry rather than a hardcoded list, so a variant
    # added to the build matrix shows up here without this file changing, and a
    # tag that was never actually pushed does not.
    if [[ -z "${tag}" ]]
    then
        if ! command -v skopeo &>/dev/null
        then
            echo "skopeo is required to list tags; pass one explicitly:" >&2
            echo "  immutablue rebase 44-cyan" >&2
            exit 1
        fi

        echo "Fetching available tags from ${image}..." >&2
        tags="$(skopeo list-tags "docker://${image}" 2>/dev/null | jq -r '.Tags[]' | sort -rV)"

        if [[ -z "${tags}" ]]
        then
            echo "Could not list tags for ${image}." >&2
            exit 1
        fi

        # Show what is running so the choice is informed. This reads
        # image-info.json via the header getter rather than scraping
        # rpm-ostree.
        current="$(
            source /usr/libexec/immutablue/immutablue-header.sh 2>/dev/null
            immutablue_get_image_tag 2>/dev/null || true
        )"

        if command -v fzf &>/dev/null
        then
            tag="$(printf '%s\n' "${tags}" \
                | fzf --header="Current tag: ${current:-unknown}   |   ENTER to rebase, ESC to cancel" \
                      --preview="echo 'Would rebase to:'; echo '  ${image}:{}'" \
                      --preview-window=down,3,wrap)" || true
        else
            echo "Available tags:"
            printf '  %s\n' ${tags}
            read -r -p "Tag to rebase to: " tag
        fi
    fi

    if [[ -z "${tag}" ]]
    then
        echo "Nothing selected."
        exit 0
    fi

    echo ""
    echo "About to rebase to: ${image}:${tag}"
    read -r -p "Continue? [y/N] " answer
    case "${answer}" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            echo "Cancelled."
            exit 0
            ;;
    esac

    # bootc is preferred where present; it is what immutablue-update already
    # uses, and it handles the signed/unsigned transport consistently with how
    # the system was installed.
    if command -v bootc &>/dev/null
    then
        sudo bootc switch "${image}:${tag}"
    else
        sudo rpm-ostree rebase "ostree-unverified-registry:${image}:${tag}"
    fi

    echo ""
    echo "Rebase staged. Reboot to apply:  systemctl reboot"


# List the /var snapshots taken before updates
[group('rollback')]
snapshots:
    #!/bin/bash
    set -euo pipefail
    /usr/libexec/immutablue/immutablue-snapshot list


# Take a /var snapshot now, outside of an update
[group('rollback')]
snapshot:
    #!/bin/bash
    set -euo pipefail
    sudo /usr/libexec/immutablue/immutablue-snapshot create


# Restore a /var snapshot, chosen with fzf; applies at the next boot
[group('rollback')]
restore_snapshot name="":
    #!/bin/bash
    set -euo pipefail

    snapshot="{{ name }}"

    if [[ -z "${snapshot}" ]]
    then
        available="$(/usr/libexec/immutablue/immutablue-snapshot list)"

        if [[ -z "${available}" ]] || [[ "${available}" == No\ snapshots* ]]
        then
            echo "No snapshots to restore."
            echo "One is taken before each update, or run: immutablue snapshot"
            exit 0
        fi

        if ! command -v fzf &>/dev/null
        then
            echo "fzf is not installed; name the snapshot explicitly:"
            printf '%s\n' "${available}"
            exit 1
        fi

        # The preview spells out what restoring does, because the consequence
        # is not obvious from a timestamp: this replaces the whole of /var --
        # system flatpaks, container storage, logs and machine state -- with
        # its contents as of that moment.
        snapshot="$(printf '%s\n' "${available}" \
            | fzf --header='Select a /var snapshot to restore, ESC to cancel' \
                  --preview='echo "Restoring {} will:"; echo; echo "  - replace /var with its contents from that snapshot"; echo "    (system flatpaks, container storage, logs, machine state)"; echo "  - keep the current /var alongside, renamed, so this is reversible"; echo "  - take effect at the NEXT BOOT, not immediately"' \
                  --preview-window=down,7,wrap)" || true
    fi

    if [[ -z "${snapshot}" ]]
    then
        echo "Nothing selected."
        exit 0
    fi

    # Typed confirmation rather than y/N. This is the most destructive thing in
    # the command surface -- it swaps out the whole of /var -- and it should not
    # be reachable by a stray keypress.
    echo ""
    echo "This will make ${snapshot} the live /var at the next boot."
    echo "The current /var is kept, renamed, so it can be swapped back."
    echo ""
    read -r -p "Type 'restore' to continue: " answer

    if [[ "${answer}" != "restore" ]]
    then
        echo "Cancelled."
        exit 0
    fi

    sudo /usr/libexec/immutablue/immutablue-snapshot restore "${snapshot}"
