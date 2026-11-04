#!/bin/bash
# backends/arch-bootc/runtime.sh
#
# Verbs for /usr/bin/immutablue-backend on arch-bootc images: bootc for
# deployments, pacman for package queries, ostree for kernel arguments.


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


# Kernel arguments, taking the rpm-ostree flags the shared recipes use.
#
# There is no rpm-ostree here. ostree's 'admin kargs edit-in-place' edits the
# booted deployment (effective next boot) but only knows --append-if-missing;
# removal has no in-place form, so it is refused with the image-side
# alternative rather than silently ignored. --unchanged-exit-77 is emulated
# against the booted command line, which is what rpm-ostree compares too.
rt_kargs() {
    local arg
    local appends=()
    local unchanged_77=0
    local changed=0

    if [[ $# -eq 0 ]]
    then
        cat /proc/cmdline
        return 0
    fi

    for arg in "$@"
    do
        case "${arg}" in
            --append-if-missing=*)
                appends+=("${arg}")
                ;;
            --unchanged-exit-77)
                unchanged_77=1
                ;;
            --delete-if-present=*|--delete=*)
                echo "arch-bootc: removing a kernel argument in place is not supported by ostree;" >&2
                echo "            ship it from the image in /usr/lib/bootc/kargs.d instead" >&2
                return 2
                ;;
            *)
                echo "arch-bootc: unsupported kargs option '${arg}'" >&2
                return 2
                ;;
        esac
    done

    for arg in "${appends[@]}"
    do
        if ! grep -qw -- "${arg#--append-if-missing=}" /proc/cmdline
        then
            changed=1
        fi
    done

    if [[ ${changed} -eq 0 ]] && [[ ${unchanged_77} -eq 1 ]]
    then
        return 77
    fi
    ostree admin kargs edit-in-place "${appends[@]}"
}


rt_cleanup() {
    ostree admin cleanup
}


rt_list_pkgs() {
    pacman -Qq
}


# 'pacman -T' resolves provides like a dependency would; a pacman group
# (packages.yaml asks for 'gnome') counts when its members are installed.
rt_has_pkg() {
    local pkg
    local missing=0

    for pkg in "$@"
    do
        pacman -T "${pkg}" > /dev/null 2>&1 && continue
        pacman -Qqg "${pkg}" > /dev/null 2>&1 && continue
        echo "${pkg}"
        missing=1
    done
    return "${missing}"
}


rt_pkg_owner() {
    pacman -Qo "$@"
}


rt_image_ref() {
    bootc status --format=json 2>/dev/null | jq -r '.status.booted.image.image.image // empty' 2>/dev/null
}
