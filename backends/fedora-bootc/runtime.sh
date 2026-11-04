#!/bin/bash
# backends/fedora-bootc/runtime.sh
#
# Verbs for /usr/bin/immutablue-backend on fedora-bootc images. Sourced by the
# dispatcher; each rt_<verb> is exactly the rpm-ostree / bootc / rpm command
# the scripts and justfiles used before they went through the dispatcher.


rt_status() {
    rpm-ostree status "$@"
}


rt_deployments() {
    if command -v bootc &>/dev/null
    then
        echo "=== bootc status ==="
        bootc status || true
        echo ""
    fi

    echo "=== rpm-ostree deployments ==="
    rpm-ostree status
}


rt_healthy() {
    rpm-ostree status &>/dev/null
}


rt_pending() {
    rpm-ostree status | grep -c "pending" || true
}


rt_upgrade() {
    bootc update
}


rt_rollback() {
    rpm-ostree rollback
}


# bootc is preferred where present; it handles the signed/unsigned transport
# consistently with how the system was installed.
rt_rebase() {
    local ref="${1:-}"

    if [[ -z "${ref}" ]]
    then
        echo "usage: immutablue-backend rebase <image:tag>" >&2
        return 2
    fi

    if command -v bootc &>/dev/null
    then
        bootc switch "${ref}"
    else
        rpm-ostree rebase "ostree-unverified-registry:${ref}"
    fi
}


rt_kargs() {
    rpm-ostree kargs "$@"
}


rt_cleanup() {
    rpm-ostree cleanup -bm
}


rt_list_pkgs() {
    rpm -qa
}


# Resolve each name the way dnf5 did at install time: package names and
# virtual provides through rpm --whatprovides, and a bare binary name
# (packages.yaml lists 'bemenu-run') through the file it provides.
rt_has_pkg() {
    local pkg
    local dir
    local missing=0

    for pkg in "$@"
    do
        rpm --quiet -q --whatprovides "${pkg}" && continue
        for dir in /usr/bin /usr/sbin
        do
            rpm --quiet -qf "${dir}/${pkg}" 2>/dev/null && continue 2
        done
        echo "${pkg}"
        missing=1
    done
    return "${missing}"
}


rt_pkg_owner() {
    rpm -qf "$@"
}


# Fallback for images built before image-info.json existed: scrape the
# registry host out of the booted deployment.
rt_image_ref() {
    rpm-ostree status | grep -i quay | head -n 1 | awk -F/ '{ printf "%s\n", $3 }'
}
