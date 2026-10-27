#!/bin/bash
# backends/gnomeos/runtime.sh
#
# Verbs for /usr/bin/immutablue-backend on gnomeos images. GNOME OS images are
# deployed by bootc with composefs; there is no rpm-ostree and no package
# database, so the package verbs are deliberately absent.


# '--verbose' is what the shared recipes pass (rpm-ostree's flag); bootc's
# status takes it too, so it passes through.
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


rt_image_ref() {
    bootc status --format=json 2>/dev/null | jq -r '.status.booted.image.image.image // empty' 2>/dev/null
}
