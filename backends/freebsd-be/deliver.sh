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
# Verified on a FreeBSD 15.1-RELEASE ZFS system (the builder VM): first
# delivery, boot, and rollback. Not yet run on hardware.
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
#
# /var is machine state except /var/db/pkg: on FreeBSD's ZFS layout it lives
# in the boot environment and is the package database for the image's files,
# so it must come from the image (FILTER_FIRST lets it through before /var is
# excluded). /boot/loader.conf carries the machine's zfs_load and console
# settings and stays local too.
FILTER_FIRST=(
    "--include=/var/"
    "--include=/var/db/"
    "--include=/var/db/pkg/***"
    "--exclude=/var/db/*"
)
PRESERVE=(
    "/var/*"
    "/home/"
    "/usr/home/"
    "/root/"
    "/tmp/"
    "/etc/"
    "/usr/local/etc/"
    "/boot/loader.conf"
    "/boot/loader.conf.local"
    "/boot/entropy"
    "/boot/zfs/"
    "/etc/zfs/"
)

# Configuration files that identify this machine and its users. They are never
# replaced, not even on a first delivery: taking the image's passwd or fstab
# would lock the administrator out or leave the pool unmounted.
KEEP_LOCAL=(
    "passwd" "master.passwd" "group" "pwd.db" "spwd.db" "login.conf.db"
    "fstab" "hostid" "resolv.conf" "localtime" "rc.conf.local"
    "wpa_supplicant.conf" "ssh/ssh_host_*"
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
# The first delivery onto a plain FreeBSD install has no old stock tree, so
# "did the administrator change it" cannot be answered. Then the image wins
# (otherwise its rc.conf, sudoers and the rest would never apply) and the
# local file is kept next to it as <file>.pre-immutablue. Machine identity
# (KEEP_LOCAL) and rc.conf (merged key by key) are excepted.
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
    local first_delivery=0

    if [[ ! -d "${old_stock}" ]]
    then
        first_delivery=1
        log "${label}: no previous stock tree (first delivery); image versions win, local copies kept as *.pre-immutablue"
    fi

    while IFS= read -r -d '' rel
    do
        rel="${rel#./}"
        if [[ "${label}" == "/etc" ]] && is_keep_local "${rel}"
        then
            continue
        fi
        if [[ "${label}" == "/etc" ]] && [[ "${rel}" == "rc.conf" ]]
        then
            merge_rc_conf "${new_tree}/rc.conf" "${target}/rc.conf"
            continue
        fi
        if [[ ! -e "${target}/${rel}" ]] && [[ ! -L "${target}/${rel}" ]]
        then
            mkdir -p "$(dirname "${target}/${rel}")"
            cp -a "${new_tree}/${rel}" "${target}/${rel}"
        elif cmp -s "${target}/${rel}" "${new_tree}/${rel}"
        then
            continue
        elif [[ ${first_delivery} -eq 1 ]]
        then
            cp -a "${target}/${rel}" "${target}/${rel}.pre-immutablue"
            cp -a "${new_tree}/${rel}" "${target}/${rel}"
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


# Is an /etc-relative path one of the KEEP_LOCAL machine files?
#
# param $1: path relative to /etc
# returns: 0 when it must stay local
is_keep_local() {
    local rel="$1"
    local pattern

    for pattern in "${KEEP_LOCAL[@]}"
    do
        # shellcheck disable=SC2053 # pattern match is the point
        if [[ "${rel}" == ${pattern} ]]
        then
            return 0
        fi
    done
    return 1
}


# Merge the image's rc.conf into the machine's, key by key.
#
# rc.conf mixes what the image decides (which services run) with what only
# this machine knows (hostname, network, ZFS). Every variable the image sets
# is applied with sysrc; everything else in the machine's file is kept.
#
# param $1: the image's rc.conf
# param $2: the boot environment's rc.conf
merge_rc_conf() {
    local image_rc="$1"
    local target_rc="$2"
    local line
    local applied=0

    local name
    local value

    # 'sysrc -a' prints "name: value" with the value unquoted; feeding the
    # shell-quoted 'sysrc -a -e' form back to sysrc would nest quotes on every
    # delivery until rc(8) rejects the variable (sshd_enable stops working).
    touch "${target_rc}"
    while IFS= read -r line
    do
        name="${line%%: *}"
        value="${line#*: }"
        [[ "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        sysrc -f "${target_rc}" "${name}=${value}" > /dev/null
        applied=$((applied + 1))
    done < <(sysrc -f "${image_rc}" -a 2>/dev/null)
    log "/etc/rc.conf: applied ${applied} setting(s) from the image, kept the machine's others"
}


# Global, not local to main: the EXIT trap that cleans them up runs after main
# has returned.
work=""
cid=""
be=""
staged=0

# rsync options for laying a FreeBSD tree down: -H hard links, --file-flags to
# carry chflags (schg on libc, init, su, ...), --force-change to replace files
# that carry them. Without the last two every system-immutable file fails.
RSYNC_OPTS=(-aH --file-flags --force-change)


# EXIT trap. A boot environment that was created but not activated is
# unmounted and destroyed; nothing is ever deleted through its mountpoint.
# The exported image tree carries schg flags, so they are cleared first.
cleanup() {
    if [[ -n "${be}" ]] && [[ ${staged} -eq 0 ]]
    then
        log "cleaning up unfinished boot environment ${be}"
        bectl umount -f "${be}" > /dev/null 2>&1 || true
        bectl destroy -F "${be}" > /dev/null 2>&1 || true
    fi
    if [[ -n "${cid}" ]]
    then
        podman rm -f "${cid}" > /dev/null 2>&1 || true
    fi
    if [[ -n "${work}" ]] && [[ -d "${work}" ]] && ! mount | grep -q " on ${work}/"
    then
        chflags -R noschg "${work}" 2>/dev/null || true
        rm -rf "${work}"
    fi
}

# Reapply file modes and flags the image recorded at build time.
#
# Images built with buildah on FreeBSD lose setuid/setgid bits and schg flags
# when their layers are committed, so the tree that arrives here has a su,
# passwd and sudo nobody can use. backend_finalize wrote the correct mode and
# flags of every such file to stock/modes; they are restored in the new boot
# environment.
#
# param $1: the recorded modes file (from the image)
# param $2: the boot environment's mountpoint
restore_modes() {
    local modes_file="$1"
    local root="$2"
    local mode
    local flags
    local path
    local restored=0

    if [[ ! -f "${modes_file}" ]]
    then
        log "no ${STOCK_REL}/modes in the image; setuid bits are not restored"
        return 0
    fi

    while IFS=$'\t' read -r mode flags path
    do
        [[ -n "${path}" ]] && [[ -e "${root}${path}" ]] || continue
        chflags noschg "${root}${path}" 2>/dev/null || true
        chmod "${mode}" "${root}${path}"
        if [[ "${flags}" != "-" ]]
        then
            chflags "${flags}" "${root}${path}"
        fi
        restored=$((restored + 1))
    done < "${modes_file}"
    log "restored mode and flags on ${restored} setuid/setgid/schg path(s)"
}


# Add the image's system accounts that this machine lacks.
#
# passwd, master.passwd and group stay local (they hold this machine's users),
# but packages create accounts of their own -- gdm, messagebus, polkitd -- and
# an image that gains such a package needs them. Every user and group the
# image defines that the machine does not is appended; existing entries are
# never changed. The password databases are then rebuilt.
#
# param $1: the image's etc directory
# param $2: the boot environment's etc directory
merge_accounts() {
    local image_etc="$1"
    local target_etc="$2"
    local line
    local name
    local added_users=0
    local added_groups=0

    while IFS= read -r line
    do
        [[ -z "${line}" ]] || [[ "${line}" == \#* ]] && continue
        name="${line%%:*}"
        if ! grep -q "^${name}:" "${target_etc}/group"
        then
            echo "${line}" >> "${target_etc}/group"
            added_groups=$((added_groups + 1))
        fi
    done < "${image_etc}/group"

    while IFS= read -r line
    do
        [[ -z "${line}" ]] || [[ "${line}" == \#* ]] && continue
        name="${line%%:*}"
        if ! grep -q "^${name}:" "${target_etc}/master.passwd"
        then
            echo "${line}" >> "${target_etc}/master.passwd"
            added_users=$((added_users + 1))
        fi
    done < "${image_etc}/master.passwd"

    if [[ ${added_users} -gt 0 ]]
    then
        pwd_mkdb -d "${target_etc}" -p "${target_etc}/master.passwd"
    fi
    log "accounts: added ${added_users} user(s) and ${added_groups} group(s) the image defines"
}


main() {
    local dry_run=0
    local ref=""
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
    trap cleanup EXIT

    # A locally built image (the build host, or one loaded by hand) is used as
    # is; otherwise it is pulled.
    if podman image exists "${ref}"
    then
        log "using local image ${ref}"
    else
        log "pulling ${ref}"
        podman pull "${ref}"
    fi
    cid="$(podman create "${ref}" /bin/true)"
    mkdir -p "${work}/rootfs"
    podman export "${cid}" | tar -xpf - -C "${work}/rootfs"

    if [[ ! -f "${work}/rootfs/usr/immutablue/backend" ]] || \
       [[ "$(head -n 1 "${work}/rootfs/usr/immutablue/backend")" != "freebsd-be" ]]
    then
        log "${ref} is not a freebsd-be Immutablue image"
        return 1
    fi

    filter=("${FILTER_FIRST[@]}")
    for path in "${PRESERVE[@]}"
    do
        filter+=("--exclude=${path}")
    done

    if [[ ${dry_run} -eq 1 ]]
    then
        log "dry run: changes relative to the running system"
        rsync "${RSYNC_OPTS[@]}" -n --delete --itemize-changes "${filter[@]}" "${work}/rootfs/" / | head -n 200 || true
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
    rsync "${RSYNC_OPTS[@]}" --delete "${filter[@]}" "${work}/rootfs/" "${mnt}/"

    restore_modes "${work}/rootfs/${STOCK_REL}/modes" "${mnt}"

    # -----------------------------------
    # 4. Three-way merge of the configuration trees
    # -----------------------------------
    merge_config_tree "${work}/rootfs/etc" "/${STOCK_REL}/etc" "${mnt}/etc" /etc
    merge_accounts "${work}/rootfs/etc" "${mnt}/etc"
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
    staged=1
    log "staged ${ref} as ${be}; reboot to use it (previous environments stay in the loader menu)"
}


main "$@"
