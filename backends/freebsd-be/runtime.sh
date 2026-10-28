#!/bin/bash
# backends/freebsd-be/runtime.sh
#
# Verbs for /usr/bin/immutablue-backend on freebsd-be images. Deployments are
# ZFS boot environments (bectl); staging a new image is deliver.sh.

FREEBSD_BE_DELIVER="/usr/immutablue/backends/freebsd-be/deliver.sh"


# The image this system tracks: registry + image:tag from image-info.json.
freebsd_be_current_ref() {
    local info="/usr/share/immutablue/image-info.json"
    local image
    local tag

    image="$(jq -r '.image // empty' "${info}" 2>/dev/null)"
    tag="$(jq -r '.tag // empty' "${info}" 2>/dev/null)"
    if [[ -z "${image}" ]] || [[ -z "${tag}" ]]
    then
        return 1
    fi
    echo "${IMMUTABLUE_IMAGE_REGISTRY:-quay.io/immutablue}/${image}:${tag}"
}


# The shared recipes pass rpm-ostree's '--verbose'; bectl has no such flag,
# so it becomes 'bectl list -a' (every dataset and snapshot).
rt_status() {
    if [[ "${1:-}" == "--verbose" ]]
    then
        bectl list -a
    else
        bectl list "$@"
    fi
}


rt_deployments() {
    echo "=== boot environments (bectl list) ==="
    bectl list
}


rt_healthy() {
    bectl list > /dev/null 2>&1
}


# A boot environment marked active on reboot ('R') but not now ('N').
rt_pending() {
    bectl list -H | awk '$2 ~ /R/ && $2 !~ /N/ { n++ } END { print n + 0 }'
}


rt_upgrade() {
    local ref

    if ! ref="$(freebsd_be_current_ref)"
    then
        echo "cannot tell which image this system tracks (no image-info.json)" >&2
        return 1
    fi
    bash "${FREEBSD_BE_DELIVER}" "${ref}"
}


rt_rebase() {
    local ref="${1:-}"

    if [[ -z "${ref}" ]]
    then
        echo "usage: immutablue-backend rebase <image:tag>" >&2
        return 2
    fi
    bash "${FREEBSD_BE_DELIVER}" "${ref}"
}


# Activate the newest boot environment created before the running one.
rt_rollback() {
    local current
    local previous

    current="$(bectl list -H | awk '$2 ~ /N/ { print $1 }')"
    previous="$(bectl list -H -c creation | awk -v cur="${current}" '$1 == cur { print prev; exit } { prev = $1 }')"
    if [[ -z "${previous}" ]]
    then
        echo "no boot environment older than ${current} to roll back to" >&2
        return 1
    fi
    bectl activate "${previous}"
    echo "Activated ${previous}; reboot to use it."
}


# Kernel tunables live in /boot/loader.conf(.local) on FreeBSD; there is no
# kernel command line to edit.
rt_kargs() {
    echo "freebsd-be: set loader tunables in /boot/loader.conf.local instead" >&2
    return 2
}


rt_cleanup() {
    pkg clean -ay
    pkg autoremove -y
}


rt_list_pkgs() {
    pkg query '%n'
}


rt_has_pkg() {
    local name
    local missing=0

    for name in "$@"
    do
        pkg info -e "${name}" && continue
        echo "${name}"
        missing=1
    done
    return "${missing}"
}


rt_pkg_owner() {
    pkg which -q "$@"
}


rt_image_ref() {
    freebsd_be_current_ref
}
