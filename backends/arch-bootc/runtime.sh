#!/bin/bash
# backends/arch-bootc/runtime.sh
#
# Verbs for /usr/bin/immutablue-backend on arch-bootc images: bootc for
# deployments, pacman for package queries, ostree for kernel arguments.


rt_status() {
    bootc status "$@"
}


rt_deployments() {
    echo "=== bootc status ==="
    bootc status
}


rt_healthy() {
    bootc status &>/dev/null
}


rt_pending() {
    bootc status --format=json 2>/dev/null | jq -r 'if .status.staged then 1 else 0 end' 2>/dev/null || echo 0
}


rt_upgrade() {
    bootc update
}


rt_rollback() {
    bootc rollback
}


rt_rebase() {
    local ref="${1:-}"

    if [[ -z "${ref}" ]]
    then
        echo "usage: immutablue-backend rebase <image:tag>" >&2
        return 2
    fi
    bootc switch "${ref}"
}


# There is no rpm-ostree here; ostree edits the kernel arguments of the
# deployment, and the change takes effect on the next boot.
rt_kargs() {
    ostree admin kargs edit-in-place "$@"
}


rt_cleanup() {
    ostree admin cleanup
}


rt_list_pkgs() {
    pacman -Qq
}


rt_pkg_owner() {
    pacman -Qo "$@"
}


rt_image_ref() {
    bootc status --format=json 2>/dev/null | jq -r '.status.booted.image.image.image // empty' 2>/dev/null
}
