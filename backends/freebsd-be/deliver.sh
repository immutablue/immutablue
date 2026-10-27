#!/bin/bash
# deliver.sh - Stage an Immutablue image as a new ZFS boot environment (freebsd-be)
#
# The FreeBSD counterpart of 'bootc switch/update'. FreeBSD has no bootc, but
# ZFS boot environments give the same guarantees: the running system is never
# modified, the new image boots from its own dataset, and the previous boot
# environment stays selectable in the loader menu (and via 'bectl activate').
#
# What it does:
#   1. Pulls the image with podman and exports its root filesystem.
#   2. Clones the running boot environment ('bectl create').
#   3. Replaces everything in the clone with the image's tree, except state
#      and configuration: /var, /home, /root, /tmp, /usr/home, /boot's local
#      loader settings and the ZFS cache.
#   4. Merges /etc and /usr/local/etc three ways using the stock trees each
#      image records under /usr/share/immutablue/stock: a file the
#      administrator never changed takes the new image's version, a changed
#      file is kept and listed as a conflict.
#   5. Activates the new boot environment for the next boot.
#
# EXPERIMENTAL: written against bectl(8), podman(8) on FreeBSD 15.1 and the
# freebsd-be image layout; not yet run on hardware.
#
# Usage:
#   deliver.sh [--dry-run] <image:tag>
#
# Options:
#   -n, --dry-run  Pull and export, then print what would change; touch no BE
#   -h, --help     Show this help message
#   --license      Show license information
#
# Examples:
#   sudo /usr/immutablue/backends/freebsd-be/deliver.sh quay.io/immutablue/immutablue:15.1-freebsd
#   sudo immutablue-backend upgrade
#   sudo immutablue-backend rebase quay.io/immutablue/immutablue:15.1-freebsd-nucleus
#
# Exit codes:
#   0 - Boot environment staged (or dry run complete)
#   1 - A step failed; the running system is unchanged
#   2 - Usage error

set -euo pipefail

STOCK_REL="usr/share/immutablue/stock"
WORK_BASE="${IMMUTABLUE_DELIVER_WORKDIR:-/var/tmp}"
BE_PREFIX="immutablue"

# Paths in the boot environment that belong to the machine, not the image.
# rsync filter form, relative to the BE root.
PRESERVE=(
    "/var/"
    "/home/"
    "/usr/home/"
    "/root/"
    "/tmp/"
    "/etc/"
    "/usr/local/etc/"
    "/boot/loader.conf.local"
    "/boot/entropy"
    "/boot/zfs/"
    "/etc/zfs/"
)


show_help() {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


show_license() {
    echo 'deliver.sh - part of Immutablue. AGPL-3.0-or-later.'
    echo 'This program comes with ABSOLUTELY NO WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.'
}


log() {
    echo "deliver: $*" >&2
}


# Three-way merge of one configuration tree.
#
# For every file in the new image's tree:
#   - absent locally            -> install it
#   - local == old stock        -> administrator never touched it: take new
#   - local == new              -> nothing to do
#   - otherwise                 -> keep local, report a conflict
# Files that only exist locally are kept untouched.
#
# param $1: new image's tree (from the exported image)
# param $2: old stock tree (from the running image, may not exist)
# param $3: target tree in the new boot environment (starts as a copy of local)
# param $4: label for messages, e.g. /etc
# returns: 0; conflicts are printed to stderr
merge_config_tree() {
    local new_tree="$1"
    local old_stock="$2"
    local target="$3"
    local label="$4"
    local rel
    local conflicts=0

    while IFS= read -r -d '' rel
    do
        rel="${rel#./}"
        if [[ ! -e "${target}/${rel}" ]] && [[ ! -L "${target}/${rel}" ]]
        then
            mkdir -p "$(dirname "${target}/${rel}")"
            cp -a "${new_tree}/${rel}" "${target}/${rel}"
        elif cmp -s "${target}/${rel}" "${new_tree}/${rel}"
        then
            continue
        elif [[ -e "${old_stock}/${rel}" ]] && cmp -s "${target}/${rel}" "${old_stock}/${rel}"
        then
            cp -a "${new_tree}/${rel}" "${target}/${rel}"
        else
            log "kept local ${label}/${rel} (changed locally and in the new image)"
            conflicts=$((conflicts + 1))
        fi
    done < <(cd "${new_tree}" && find . \( -type f -o -type l \) -print0)

    log "${label}: ${conflicts} locally modified file(s) kept"
}


main() {
    local dry_run=0
    local ref=""
    local work
    local cid
    local be
    local mnt
    local filter=()
    local path

    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -h|--help) show_help; return 0 ;;
            --license) show_license; return 0 ;;
            -n|--dry-run) dry_run=1 ;;
            -*) log "unknown option $1"; return 2 ;;
            *) ref="$1" ;;
        esac
        shift
    done

    if [[ -z "${ref}" ]]
    then
        show_help >&2
        return 2
    fi

    if [[ "$(uname -s)" != "FreeBSD" ]]
    then
        log "freebsd-be images are delivered on FreeBSD only"
        return 1
    fi

    # -----------------------------------
    # 1. Pull and export the image's root filesystem
    # -----------------------------------
    work="$(mktemp -d "${WORK_BASE}/immutablue-deliver.XXXXXX")"
    trap 'rm -rf "${work}"; [[ -n "${cid:-}" ]] && podman rm -f "${cid}" > /dev/null 2>&1; true' EXIT

    log "pulling ${ref}"
    podman pull "${ref}"
    cid="$(podman create "${ref}" /bin/true)"
    mkdir -p "${work}/rootfs"
    podman export "${cid}" | tar -xpf - -C "${work}/rootfs"

    if [[ ! -f "${work}/rootfs/usr/immutablue/backend" ]] || \
       [[ "$(head -n 1 "${work}/rootfs/usr/immutablue/backend")" != "freebsd-be" ]]
    then
        log "${ref} is not a freebsd-be Immutablue image"
        return 1
    fi

    for path in "${PRESERVE[@]}"
    do
        filter+=("--exclude=${path}")
    done

    if [[ ${dry_run} -eq 1 ]]
    then
        log "dry run: changes relative to the running system"
        rsync -aHn --delete --itemize-changes "${filter[@]}" "${work}/rootfs/" / | head -n 200
        return 0
    fi

    # -----------------------------------
    # 2. Clone the running boot environment
    # -----------------------------------
    be="${BE_PREFIX}-$(date -u +%Y%m%dT%H%M%SZ)"
    log "creating boot environment ${be}"
    bectl create "${be}"
    mnt="${work}/be"
    mkdir -p "${mnt}"
    bectl mount "${be}" "${mnt}"

    # -----------------------------------
    # 3. Lay the image over the clone, keeping machine state
    # -----------------------------------
    log "installing image tree"
    rsync -aH --delete "${filter[@]}" "${work}/rootfs/" "${mnt}/"

    # -----------------------------------
    # 4. Three-way merge of the configuration trees
    # -----------------------------------
    merge_config_tree "${work}/rootfs/etc" "/${STOCK_REL}/etc" "${mnt}/etc" /etc
    if [[ -d "${work}/rootfs/usr/local/etc" ]]
    then
        mkdir -p "${mnt}/usr/local/etc"
        merge_config_tree "${work}/rootfs/usr/local/etc" "/${STOCK_REL}/usr-local-etc" "${mnt}/usr/local/etc" /usr/local/etc
    fi

    # -----------------------------------
    # 5. Activate for the next boot
    # -----------------------------------
    bectl umount "${be}"
    bectl activate "${be}"
    log "staged ${ref} as ${be}; reboot to use it (previous environments stay in the loader menu)"
}


main "$@"
