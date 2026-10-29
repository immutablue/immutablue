#!/bin/bash
# install-disk.sh - Install a freebsd-be Immutablue image onto a whole disk
#
# The FreeBSD counterpart of 'bootc install to-disk': turns an empty disk into
# a bootable Immutablue FreeBSD system. Runs as root on a FreeBSD host that
# has the image in its podman storage (the builder VM, or any FreeBSD 15.1
# machine with podman), with the target disk attached but not in use.
#
# Layout (the same shape bsdinstall's ZFS install uses, so bectl, deliver.sh
# and every other boot-environment tool work unchanged):
#
#   p1  efi           260M  FAT32, EFI/BOOT/BOOTX64.EFI + EFI/FreeBSD/loader.efi
#   p2  freebsd-boot  512K  gptzfsboot, for BIOS boot
#   p3  freebsd-zfs   rest  pool <pool>
#         <pool>/ROOT/immutablue-<date>   /  (the boot environment, bootfs)
#         <pool>/home                     /home
#         <pool>/tmp                      /tmp
#         <pool>/var/{audit,crash,log,mail,tmp}
#         <pool>/containers               /var/db/containers (podman storage)
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
#   install-disk.sh [options] <image:tag> <disk>
#   install-disk.sh [options] --source-root <dir> <disk>
#
# Options:
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


main() {
    local args=()
    local image
    local disk
    local be
    local answer

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
            -*) log "unknown option $1"; return 2 ;;
            *) args+=("$1") ;;
        esac
        shift
    done
    if [[ -n "${SOURCE_ROOT}" ]] && [[ ${#args[@]} -eq 1 ]]
    then
        image="${SOURCE_ROOT}"
        disk="${args[0]#/dev/}"
    elif [[ -z "${SOURCE_ROOT}" ]] && [[ ${#args[@]} -eq 2 ]]
    then
        image="${args[0]}"
        disk="${args[1]#/dev/}"
    else
        show_help >&2
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
    if ! geom disk list "${disk}" > /dev/null 2>&1
    then
        log "${disk} is not a disk (see 'geom disk list')"
        return 2
    fi
    if zpool status 2>/dev/null | grep -qE "^[[:space:]]+${disk}(p[0-9]+)?[[:space:]]"
    then
        log "${disk} belongs to an imported pool; refusing"
        return 2
    fi
    if mount | grep -qE "^/dev/${disk}(p[0-9]+)? "
    then
        log "${disk} has mounted partitions; refusing"
        return 2
    fi
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
        read -r -p "Destroy everything on /dev/${disk} and install ${image}? [y/N] " answer
        [[ "${answer}" == [yY]* ]] || { log "cancelled"; return 2; }
    fi

    trap cleanup EXIT
    ALTROOT="$(mktemp -d /tmp/immutablue-install.XXXXXX)"
    be="immutablue-$(date -u +%Y%m%dT%H%M%SZ)"

    # -----------------------------------
    # Partitions and boot code
    # -----------------------------------
    log "partitioning /dev/${disk}"
    gpart destroy -F "${disk}" > /dev/null 2>&1 || true
    gpart create -s gpt "${disk}"
    gpart add -t efi -s 260m -l efiboot0 "${disk}"
    gpart add -t freebsd-boot -s 512k -l gptboot0 "${disk}"
    gpart add -t freebsd-zfs -l zfs0 "${disk}"

    # -----------------------------------
    # Pool and datasets (bsdinstall's layout)
    # -----------------------------------
    log "creating pool ${POOL}"
    zpool create -f -o altroot="${ALTROOT}" -O compress=zstd -O atime=off \
        -O mountpoint=/ -O canmount=off "${POOL}" "/dev/${disk}p3"
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
    gpart bootcode -b "${ALTROOT}/boot/pmbr" -p "${ALTROOT}/boot/gptzfsboot" -i 2 "${disk}"
    newfs_msdos -F 32 -c 1 -L EFISYS "/dev/${disk}p1" > /dev/null
    mkdir -p "${ALTROOT}/boot/efi"
    mount -t msdosfs "/dev/${disk}p1" "${ALTROOT}/boot/efi"
    mkdir -p "${ALTROOT}/boot/efi/EFI/BOOT" "${ALTROOT}/boot/efi/EFI/FreeBSD"
    cp "${ALTROOT}/boot/loader.efi" "${ALTROOT}/boot/efi/EFI/BOOT/BOOTX64.EFI"
    cp "${ALTROOT}/boot/loader.efi" "${ALTROOT}/boot/efi/EFI/FreeBSD/loader.efi"
    umount "${ALTROOT}/boot/efi"

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
    sysrc -f "${ALTROOT}/etc/rc.conf" \
        hostname="${HOSTNAME_NEW}" \
        ifconfig_DEFAULT="SYNCDHCP" \
        zfs_enable="YES" \
        sshd_enable="YES" > /dev/null
    printf '# Device\tMountpoint\tFStype\tOptions\tDump\tPass#\n/dev/gpt/efiboot0\t/boot/efi\tmsdosfs\trw\t2\t2\n' > "${ALTROOT}/etc/fstab"
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
    log "installed ${image} on /dev/${disk} (pool ${POOL}, boot environment ${be})"
}


main "$@"
