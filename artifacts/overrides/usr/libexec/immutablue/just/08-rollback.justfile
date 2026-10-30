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

    immutablue-backend deployments


# Roll back to the previous deployment
[group('rollback')]
rollback:
    #!/bin/bash
    set -euo pipefail

    # The backend keeps one previous deployment (rpm-ostree, bootc) or a list
    # of boot environments (FreeBSD); either way the useful thing is showing
    # what the rollback lands on before doing it, since the pending/rollback
    # distinction is easy to misread in the raw status output.
    echo "Current deployments:"
    immutablue-backend status
    echo ""

    if ! immutablue-backend healthy
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

    sudo immutablue-backend rollback
    echo ""
    # systemd backends reboot with systemctl; freebsd-be (rc) has none.
    echo "Rollback staged. Reboot to apply:  $(command -v systemctl > /dev/null && echo 'systemctl reboot' || echo 'shutdown -r now')"


# Rebase onto another Immutablue variant, chosen from the registry
# (only this machine's backend; --force to name a tag of another one)
[group('rollback')]
rebase tag="" *FLAGS:
    #!/bin/bash
    set -euo pipefail

    image="{{ IMMUTABLUE_IMAGE }}"
    tag="{{ tag }}"
    force=0
    for flag in {{ FLAGS }}
    do
        case "${flag}" in
            --force) force=1 ;;
            *) echo "Unknown flag: ${flag} (only --force)" >&2; exit 1 ;;
        esac
    done
    # 'immutablue rebase --force' with no tag arrives with --force as the tag.
    if [[ "${tag}" == "--force" ]]
    then
        tag=""
        force=1
    fi

    # The registry holds every backend's images and the build containers under
    # one repository; a machine may only move between its own backend's images
    # (immutablue-rebase-tags documents the naming).
    tags_helper="/usr/libexec/immutablue/immutablue-rebase-tags"
    backend="$("${tags_helper}" current)"

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
        tags="$(skopeo list-tags "docker://${image}" 2>/dev/null | jq -r '.Tags[]' \
            | "${tags_helper}" filter "${backend}" | sort -rV)"

        if [[ -z "${tags}" ]]
        then
            echo "Could not list ${backend} tags for ${image}." >&2
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

    # A tag typed by hand is checked too: a build container is never bootable,
    # and another backend's image is refused unless --force says it is meant.
    tag_backend="$("${tags_helper}" backend "${tag}")"
    if [[ "${tag_backend}" == "none" ]]
    then
        echo "${image}:${tag} is not a bootable Immutablue image (a build container, or an unknown tag)." >&2
        exit 1
    fi
    if [[ "${tag_backend}" != "${backend}" ]] && [[ ${force} -eq 0 ]]
    then
        echo "${tag} is a ${tag_backend} image; this machine runs ${backend}." >&2
        echo "Switching an installed system between backends is not supported." >&2
        echo "Pass --force to try anyway: immutablue rebase ${tag} --force" >&2
        exit 1
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

    # How a rebase is staged is the backend's business (bootc switch, with an
    # rpm-ostree fallback, on fedora-bootc).
    sudo immutablue-backend rebase "${image}:${tag}"

    echo ""
    # systemd backends reboot with systemctl; freebsd-be (rc) has none.
    echo "Rebase staged. Reboot to apply:  $(command -v systemctl > /dev/null && echo 'systemctl reboot' || echo 'shutdown -r now')"


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
