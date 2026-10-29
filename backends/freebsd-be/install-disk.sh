#!/bin/bash
# install-disk.sh - Install a freebsd-be Immutablue image onto whole disks
#
# The FreeBSD counterpart of 'bootc install to-disk': turns one or more empty
# disks into a bootable Immutablue FreeBSD system, optionally mirrored or in
# a raidz, optionally encrypted. Runs as root on a FreeBSD host that has the
# image in its podman storage (the builder VM, or any FreeBSD 15.1 machine
# with podman), or from the installer ISO (--source-root), with the target
# disks attached but not in use.
#
# Every disk gets the same partitions (the shape bsdinstall's ZFS install
# uses, so bectl, deliver.sh and every other boot-environment tool work
# unchanged), and the machine boots from any of them:
#
#   p1  efi           260M  FAT32, EFI/BOOT/BOOTX64.EFI + EFI/FreeBSD/loader.efi
#   p2  freebsd-boot  512K  gptzfsboot, for BIOS boot
#   p3  freebsd-swap  SIZE  only with --swap; GELI one-time encrypted with --encrypt
#   pN  freebsd-zfs   rest  a vdev member of pool <pool> (through GELI with
#                           --encrypt: <disk>pN.eli)
#
#   pool <pool>, layout stripe | mirror | raidz1 | raidz2 | raidz3:
#         <pool>/ROOT/immutablue-<date>   /  (the boot environment, bootfs)
#         <pool>/home                     /home
#         <pool>/tmp                      /tmp
#         <pool>/var/{audit,crash,log,mail,tmp}
#         <pool>/containers               /var/db/containers (podman storage)
#
# Encryption (--encrypt) is GELI under ZFS, as bsdinstall's "Encrypt disks":
# every ZFS partition is a GELI provider (AES-XTS, 256-bit, 4K sectors)
# initialised for boot (-b, -g), so FreeBSD's loader asks for the passphrase
# once, unlocks every provider with it, and hands the keys to the kernel.
# The boot environments live inside the pool, so delivery and rollback are
# unchanged. Each provider's metadata backup is written to
# /var/backups/zfs<i>.eli on the installed system, named after the
# partition's GPT label ('geli restore /var/backups/zfs0.eli
# /dev/gpt/zfs0' if the metadata is ever damaged). The passphrase prompt uses the US
# keyboard layout.
#
# The image's root filesystem is laid into the boot environment, its recorded
# setuid/setgid/schg modes are restored (buildah drops them, see
# backend_finalize), and the machine-specific files are written: loader.conf
# (ZFS, video console), rc.conf (hostname, DHCP on every interface),
# and the pool cache. No user is created: GNOME images ask for the first user
# through gnome-initial-setup at first login; --ssh-key installs a root key for
# headless access.
#
# Usage:
#   install-disk.sh [options] <image:tag> <disk>...
#   install-disk.sh [options] --source-root <dir> <disk>...
#
# Options:
#   --layout LAYOUT   stripe (one disk, or disks added together), mirror,
#                     raidz1, raidz2 or raidz3 (default: stripe for one disk,
#                     mirror for several). Minimum disks: mirror and raidz1 2,
#                     raidz2 3, raidz3 4
#   --encrypt         GELI-encrypt every disk; needs --passphrase-file
#   --passphrase-file FILE
#                     the GELI passphrase, the whole file (a trailing newline
#                     is removed)
#   --swap SIZE       a swap partition of SIZE (e.g. 2g) on every disk
#                     (default: none); encrypted with a one-time key at every
#                     boot when --encrypt
#   --pool NAME       zpool name (default: zimmutablue; must not exist on the host)
#   --hostname NAME   hostname (default: immutablue)
#   --ssh-key FILE    install FILE as root's authorized_keys
#   --yes             do not ask before destroying the disk's contents
#   --source-root DIR install from a directory tree instead of a podman image:
#                     the installer ISO's live root, which is the image
#                     (make-iso.sh keeps the image's /var at
#                     /.immutablue-image/var, since the live /var is a RAM disk)
#   -h, --help        Show this help message
#   --license         Show license information
#
# Examples:
#   sudo backends/freebsd-be/install-disk.sh quay.io/immutablue/immutablue:15.1-freebsd vtbd2
#   sudo backends/freebsd-be/install-disk.sh --yes --hostname desk \
#       quay.io/immutablue/immutablue:15.1-freebsd-nucleus ada1
#   sudo backends/freebsd-be/install-disk.sh --layout mirror --encrypt \
#       --passphrase-file /tmp/pw --swap 2g \
#       quay.io/immutablue/immutablue:15.1-freebsd ada0 ada1
#   sudo backends/freebsd-be/install-disk.sh --layout raidz1 \
#       quay.io/immutablue/immutablue:15.1-freebsd nda0 nda1 nda2
#   backends/freebsd-be/builder-vm.sh --libvirt install
#
# Exit codes:
#   0 - Installed
#   1 - A step failed (the disk is left partially written)
#   2 - Usage error, or the disk is in use

set -euo pipefail

STOCK_REL="usr/share/immutablue/stock"
POOL="zimmutablue"
HOSTNAME_NEW="immutablue"
SSH_KEY=""
SOURCE_ROOT=""
ASSUME_YES=0
LAYOUT=""
ENCRYPT=0
PASSFILE=""
SWAP=""
KEYFILE=""
GELI_ATTACHED=()
ALTROOT=""
CID=""


show_help() {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


log() {
    echo "install-disk: $*" >&2
}


# Export the pool and remove the temporary container whatever happened, so a
# failed install never leaves the target pool imported on the host.
cleanup() {
    if [[ -n "${CID}" ]]
    then
        podman rm -f "${CID}" > /dev/null 2>&1 || true
    fi
    if zpool list -H -o name "${POOL}" > /dev/null 2>&1
    then
        zpool export "${POOL}" || zpool export -f "${POOL}" || true
    fi
    local prov
    for prov in "${GELI_ATTACHED[@]}"
    do
        geli detach "${prov}" > /dev/null 2>&1 || true
    done
    if [[ -n "${KEYFILE}" ]]
    then
        rm -f "${KEYFILE}"
    fi
    if [[ -n "${ALTROOT}" ]] && [[ -d "${ALTROOT}" ]] && ! mount | grep -q " on ${ALTROOT}"
    then
        rmdir "${ALTROOT}" 2>/dev/null || true
    fi
}


# Restore the mode and flags of every path the image recorded (see
# backend_finalize / deliver.sh restore_modes).
#
# param $1: root of the installed tree
restore_modes() {
    local root="$1"
    local mode
    local flags
    local path
    local restored=0

    [[ -f "${root}/${STOCK_REL}/modes" ]] || return 0
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
    done < "${root}/${STOCK_REL}/modes"
    log "restored mode and flags on ${restored} setuid/setgid/schg path(s)"
}


# Smallest number of disks a layout needs.
#
# param $1: layout
# returns: the number on stdout, nothing for an unknown layout
layout_min_disks() {
    case "$1" in
        stripe) echo 1 ;;
        mirror|raidz1) echo 2 ;;
        raidz2) echo 3 ;;
        raidz3) echo 4 ;;
        *) ;;
    esac
}


# Check that a disk can be wiped: a whole disk, in no imported pool, nothing
# of it mounted.
#
# param $1: disk name (ada0, nda1, vtbd2, ...)
# returns: 0 when usable, 2 (with a message) when not
check_disk() {
    local disk="$1"

    if ! geom disk list "${disk}" > /dev/null 2>&1
    then
        log "${disk} is not a disk (see 'geom disk list')"
        return 2
    fi
    if zpool status 2>/dev/null | grep -qE "^[[:space:]]+${disk}(p[0-9]+)?(\.eli)?[[:space:]]"
    then
        log "${disk} belongs to an imported pool; refusing"
        return 2
    fi
    if mount | grep -qE "^/dev/${disk}(p[0-9]+)? "
    then
        log "${disk} has mounted partitions; refusing"
        return 2
    fi
    if swapctl -l 2>/dev/null | grep -qE "^/dev/${disk}p[0-9]+"
    then
        log "${disk} has active swap; refusing"
        return 2
    fi
    return 0
}


# Partition one disk: ESP, BIOS boot, optional swap, ZFS. The index makes the
# GPT labels unique across the disks (efiboot<i>, gptboot<i>, swap<i>,
# zfs<i>).
#
# param $1: disk
# param $2: index of the disk (0 for the first)
partition_disk() {
    local disk="$1"
    local i="$2"

    gpart destroy -F "${disk}" > /dev/null 2>&1 || true
    gpart create -s gpt "${disk}"
    gpart add -a 1m -t efi -s 260m -l "efiboot${i}" "${disk}"
    gpart add -t freebsd-boot -s 512k -l "gptboot${i}" "${disk}"
    if [[ -n "${SWAP}" ]]
    then
        gpart add -a 1m -t freebsd-swap -s "${SWAP}" -l "swap${i}" "${disk}"
    fi
    gpart add -a 1m -t freebsd-zfs -l "zfs${i}" "${disk}"
}


main() {
    local args=()
    local disks=()
    local vdevs=()
    local image
    local disk
    local be
    local answer
    local min
    local zpart
    local i
    local spec=()
    local esp

    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -h|--help) show_help; return 0 ;;
            --license) echo 'install-disk.sh - part of Immutablue. AGPL-3.0-or-later.'; return 0 ;;
            --pool) POOL="$2"; shift ;;
            --hostname) HOSTNAME_NEW="$2"; shift ;;
            --ssh-key) SSH_KEY="$2"; shift ;;
            --yes) ASSUME_YES=1 ;;
            --source-root) SOURCE_ROOT="$2"; shift ;;
            --layout) LAYOUT="$2"; shift ;;
            --encrypt) ENCRYPT=1 ;;
            --passphrase-file) PASSFILE="$2"; shift ;;
            --swap) SWAP="$2"; shift ;;
            -*) log "unknown option $1"; return 2 ;;
            *) args+=("$1") ;;
        esac
        shift
    done
    if [[ -n "${SOURCE_ROOT}" ]] && [[ ${#args[@]} -ge 1 ]]
    then
        image="${SOURCE_ROOT}"
        disks=("${args[@]}")
    elif [[ -z "${SOURCE_ROOT}" ]] && [[ ${#args[@]} -ge 2 ]]
    then
        image="${args[0]}"
        disks=("${args[@]:1}")
    else
        show_help >&2
        return 2
    fi
    for i in "${!disks[@]}"
    do
        disks[i]="${disks[i]#/dev/}"
    done
    if [[ -z "${LAYOUT}" ]]
    then
        if [[ ${#disks[@]} -eq 1 ]]
        then
            LAYOUT="stripe"
        else
            LAYOUT="mirror"
        fi
    fi
    min="$(layout_min_disks "${LAYOUT}")"
    if [[ -z "${min}" ]]
    then
        log "unknown layout ${LAYOUT} (stripe, mirror, raidz1, raidz2, raidz3)"
        return 2
    fi
    if [[ ${#disks[@]} -lt ${min} ]]
    then
        log "layout ${LAYOUT} needs at least ${min} disks, got ${#disks[@]}"
        return 2
    fi
    if [[ $(printf '%s\n' "${disks[@]}" | sort -u | wc -l) -ne ${#disks[@]} ]]
    then
        log "a disk is listed twice"
        return 2
    fi
    if [[ ${ENCRYPT} -eq 1 ]] && { [[ -z "${PASSFILE}" ]] || [[ ! -s "${PASSFILE}" ]]; }
    then
        log "--encrypt needs a non-empty --passphrase-file"
        return 2
    fi
    if [[ -n "${SWAP}" ]] && [[ ! "${SWAP}" =~ ^[0-9]+[kKmMgGtT]?$ ]]
    then
        log "--swap takes a size like 2g or 512m"
        return 2
    fi

    # -----------------------------------
    # Refuse anything that is not an idle, whole, non-root disk
    # -----------------------------------
    if [[ "$(uname -s)" != "FreeBSD" ]] || [[ "$(id -u)" -ne 0 ]]
    then
        log "run as root on FreeBSD"
        return 2
    fi
    for disk in "${disks[@]}"
    do
        check_disk "${disk}" || return 2
    done
    if zpool list -H -o name "${POOL}" > /dev/null 2>&1
    then
        log "a pool named ${POOL} is already imported here; choose another --pool"
        return 2
    fi
    if [[ -n "${SOURCE_ROOT}" ]]
    then
        if [[ ! -f "${SOURCE_ROOT}/usr/immutablue/backend" ]]
        then
            log "${SOURCE_ROOT} is not an Immutablue freebsd-be tree"
            return 2
        fi
    elif ! podman image exists "${image}"
    then
        log "${image} is not in local podman storage"
        return 2
    fi
    if [[ ${ASSUME_YES} -ne 1 ]]
    then
        read -r -p "Destroy everything on ${disks[*]} (${LAYOUT}$([[ ${ENCRYPT} -eq 1 ]] && echo ', encrypted')) and install ${image}? [y/N] " answer
        [[ "${answer}" == [yY]* ]] || { log "cancelled"; return 2; }
    fi

    trap cleanup EXIT
    ALTROOT="$(mktemp -d /tmp/immutablue-install.XXXXXX)"
    be="immutablue-$(date -u +%Y%m%dT%H%M%SZ)"

    # -----------------------------------
    # Partitions and boot code
    # -----------------------------------
    for i in "${!disks[@]}"
    do
        log "partitioning /dev/${disks[i]}"
        partition_disk "${disks[i]}" "${i}"
    done
    if [[ -n "${SWAP}" ]]
    then
        zpart=4
    else
        zpart=3
    fi

    # -----------------------------------
    # GELI under every ZFS partition (--encrypt)
    # -----------------------------------
    # The passphrase goes to geli through a copy without its trailing
    # newline (geli takes the file's bytes as they are). -b: attach at boot;
    # -g: the loader unlocks it (one prompt for all providers); metadata
    # backups go to the installed system, not the live one's RAM disk.
    if [[ ${ENCRYPT} -eq 1 ]]
    then
        KEYFILE="$(mktemp /tmp/immutablue-geli.XXXXXX)"
        chmod 0600 "${KEYFILE}"
        printf '%s' "$(cat "${PASSFILE}")" > "${KEYFILE}"
        mkdir -p "${ALTROOT}.geli-backups"
        for i in "${!disks[@]}"
        do
            disk="${disks[i]}"
            log "encrypting /dev/${disk}p${zpart}"
            # Backups are named after the partition's GPT label (zfs<i>),
            # which stays the same on the installed machine; device names
            # do not.
            geli init -b -g -e AES-XTS -l 256 -s 4096 -J "${KEYFILE}" \
                -B "${ALTROOT}.geli-backups/zfs${i}.eli" "/dev/${disk}p${zpart}" > /dev/null
            geli attach -j "${KEYFILE}" "/dev/${disk}p${zpart}"
            GELI_ATTACHED+=("/dev/${disk}p${zpart}")
            vdevs+=("/dev/${disk}p${zpart}.eli")
        done
    else
        for disk in "${disks[@]}"
        do
            vdevs+=("/dev/${disk}p${zpart}")
        done
    fi

    # -----------------------------------
    # Pool and datasets (bsdinstall's layout)
    # -----------------------------------
    spec=()
    if [[ "${LAYOUT}" != "stripe" ]]
    then
        spec=("${LAYOUT}")
    fi
    log "creating pool ${POOL} (${LAYOUT} of ${#disks[@]} disk(s)$([[ ${ENCRYPT} -eq 1 ]] && echo ', encrypted'))"
    zpool create -f -o altroot="${ALTROOT}" -O compress=zstd -O atime=off \
        -O mountpoint=/ -O canmount=off "${POOL}" "${spec[@]}" "${vdevs[@]}"
    zfs create -o mountpoint=none "${POOL}/ROOT"
    zfs create -o mountpoint=/ -o canmount=noauto "${POOL}/ROOT/${be}"
    zfs mount "${POOL}/ROOT/${be}"
    zfs create -o mountpoint=/home "${POOL}/home"
    zfs create -o mountpoint=/tmp -o exec=on -o setuid=off "${POOL}/tmp"
    zfs create -o mountpoint=/var -o canmount=off "${POOL}/var"
    zfs create -o exec=off -o setuid=off "${POOL}/var/audit"
    zfs create -o exec=off -o setuid=off "${POOL}/var/crash"
    zfs create -o exec=off -o setuid=off "${POOL}/var/log"
    zfs create -o atime=on "${POOL}/var/mail"
    zfs create -o setuid=off "${POOL}/var/tmp"
    # podman's zfs storage driver makes each layer a child of the dataset
    # holding its graphroot. Inside the boot environment those children are
    # not part of the next one, so every update would orphan the storage.
    zfs create -o mountpoint=/var/db/containers "${POOL}/containers"
    zpool set bootfs="${POOL}/ROOT/${be}" "${POOL}"

    # -----------------------------------
    # The image's root filesystem
    # -----------------------------------
    log "installing ${image} into ${POOL}/ROOT/${be}"
    if [[ -n "${SOURCE_ROOT}" ]]
    then
        # The live root is the image plus what make-iso.sh added for the
        # live session; those additions and the RAM-backed or virtual
        # trees stay behind, and the image's own /var comes from where
        # make-iso.sh kept it.
        tar -cf - -C "${SOURCE_ROOT}" \
            --exclude ./dev --exclude ./proc --exclude ./tmp --exclude ./var \
            --exclude ./mnt --exclude ./media --exclude ./.immutablue-image \
            --exclude ./etc/rc.conf.local --exclude ./boot/loader.conf.local \
            --exclude ./etc/rc.local --exclude ./etc/fstab --exclude ./efiboot.img . \
            | tar -xpf - -C "${ALTROOT}"
        mkdir -p "${ALTROOT}/dev" "${ALTROOT}/tmp" "${ALTROOT}/var" "${ALTROOT}/mnt" "${ALTROOT}/media"
        tar -cf - -C "${SOURCE_ROOT}/.immutablue-image/var" . | tar -xpf - -C "${ALTROOT}/var"
    else
        CID="$(podman create "${image}" /bin/true)"
        podman export "${CID}" | tar -xpf - -C "${ALTROOT}"
    fi
    restore_modes "${ALTROOT}"
    chmod 1777 "${ALTROOT}/tmp" "${ALTROOT}/var/tmp"

    # -----------------------------------
    # Boot code from the image itself, so loader and kernel match
    # -----------------------------------
    # On every disk, so the machine boots from whichever survives.
    mkdir -p "${ALTROOT}/boot/efi"
    for disk in "${disks[@]}"
    do
        gpart bootcode -b "${ALTROOT}/boot/pmbr" -p "${ALTROOT}/boot/gptzfsboot" -i 2 "${disk}" > /dev/null
        esp="/dev/${disk}p1"
        newfs_msdos -F 32 -c 1 -L EFISYS "${esp}" > /dev/null
        mount -t msdosfs "${esp}" "${ALTROOT}/boot/efi"
        mkdir -p "${ALTROOT}/boot/efi/EFI/BOOT" "${ALTROOT}/boot/efi/EFI/FreeBSD"
        cp "${ALTROOT}/boot/loader.efi" "${ALTROOT}/boot/efi/EFI/BOOT/BOOTX64.EFI"
        cp "${ALTROOT}/boot/loader.efi" "${ALTROOT}/boot/efi/EFI/FreeBSD/loader.efi"
        umount "${ALTROOT}/boot/efi"
    done

    if [[ ${ENCRYPT} -eq 1 ]]
    then
        mkdir -p "${ALTROOT}/var/backups"
        cp "${ALTROOT}.geli-backups/"*.eli "${ALTROOT}/var/backups/"
        chmod 0600 "${ALTROOT}/var/backups/"*.eli
        rm -rf "${ALTROOT}.geli-backups"
    fi

    # -----------------------------------
    # This machine's configuration
    # -----------------------------------
    cat >> "${ALTROOT}/boot/loader.conf" <<EOF
# Written by Immutablue's install-disk.sh
zfs_load="YES"
cryptodev_load="YES"
# Screen first, serial second: with "vidconsole" alone the UEFI loader
# still adds a serial port it finds in the firmware's ConOut (libvirt
# domains have one) and makes it the primary console, where rc(8) output --
# the installer -- goes.
console="vidconsole,comconsole"
autoboot_delay="3"
EOF
    if [[ ${ENCRYPT} -eq 1 ]]
    then
        cat >> "${ALTROOT}/boot/loader.conf" <<'EOF'
# GELI-encrypted pool: the loader asks for the passphrase and passes the
# keys on; the kernel needs the GELI class to attach the providers.
geom_eli_load="YES"
EOF
    fi
    sysrc -f "${ALTROOT}/etc/rc.conf" \
        hostname="${HOSTNAME_NEW}" \
        ifconfig_DEFAULT="SYNCDHCP" \
        zfs_enable="YES" \
        sshd_enable="YES" > /dev/null
    # Everything by GPT label (device names shift when a disk is gone), and
    # failok: with a mirror or raidz the system still boots when the first
    # disk -- the one whose ESP is mounted -- has died; a failed fstab mount
    # would otherwise stop the boot in single-user mode.
    printf '# Device\tMountpoint\tFStype\tOptions\tDump\tPass#\n/dev/gpt/efiboot0\t/boot/efi\tmsdosfs\trw,failok\t2\t2\n' > "${ALTROOT}/etc/fstab"
    # Swap on every disk; with --encrypt as <label>.eli, which swapon(8)
    # attaches with a one-time random key at each boot (swap is never
    # readable later). swapon takes no failok, and a missing swap device does
    # not stop the boot.
    if [[ -n "${SWAP}" ]]
    then
        for i in "${!disks[@]}"
        do
            if [[ ${ENCRYPT} -eq 1 ]]
            then
                printf '/dev/gpt/swap%s.eli\tnone\tswap\tsw\t0\t0\n' "${i}" >> "${ALTROOT}/etc/fstab"
            else
                printf '/dev/gpt/swap%s\tnone\tswap\tsw\t0\t0\n' "${i}" >> "${ALTROOT}/etc/fstab"
            fi
        done
    fi
    zpool set cachefile="${ALTROOT}/boot/zfs/zpool.cache" "${POOL}"

    if [[ -n "${SSH_KEY}" ]]
    then
        mkdir -p "${ALTROOT}/root/.ssh"
        cp "${SSH_KEY}" "${ALTROOT}/root/.ssh/authorized_keys"
        chmod 0700 "${ALTROOT}/root/.ssh"
        chmod 0600 "${ALTROOT}/root/.ssh/authorized_keys"
        # FreeBSD's sshd refuses root by default; allow it with a key only.
        printf '\n# install-disk.sh --ssh-key\nPermitRootLogin prohibit-password\n' >> "${ALTROOT}/etc/ssh/sshd_config"
    fi

    sync
    log "installed ${image} on ${disks[*]} (pool ${POOL}, ${LAYOUT}$([[ ${ENCRYPT} -eq 1 ]] && echo ', GELI-encrypted'), boot environment ${be})"
}


main "$@"
