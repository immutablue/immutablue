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
#
# The image's root filesystem is laid into the boot environment, its recorded
# setuid/setgid/schg modes are restored (buildah drops them, see
# backend_finalize), and the machine-specific files are written: loader.conf
# (ZFS, serial + video console), rc.conf (hostname, DHCP on every interface),
# and the pool cache. No user is created: GNOME images ask for the first user
# through gnome-initial-setup at first login; --ssh-key installs a root key for
# headless access.
#
# Usage:
#   install-disk.sh [options] <image:tag> <disk>
#
# Options:
#   --pool NAME       zpool name (default: zimmutablue; must not exist on the host)
#   --hostname NAME   hostname (default: immutablue)
#   --ssh-key FILE    install FILE as root's authorized_keys
#   --yes             do not ask before destroying the disk's contents
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
            -*) log "unknown option $1"; return 2 ;;
            *) args+=("$1") ;;
        esac
        shift
    done
    if [[ ${#args[@]} -ne 2 ]]
    then
        show_help >&2
        return 2
    fi
    image="${args[0]}"
    disk="${args[1]#/dev/}"

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
    if ! podman image exists "${image}"
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
    zpool set bootfs="${POOL}/ROOT/${be}" "${POOL}"

    # -----------------------------------
    # The image's root filesystem
    # -----------------------------------
    log "installing ${image} into ${POOL}/ROOT/${be}"
    CID="$(podman create "${image}" /bin/true)"
    podman export "${CID}" | tar -xpf - -C "${ALTROOT}"
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
boot_multicons="YES"
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
    fi

    sync
    log "installed ${image} on /dev/${disk} (pool ${POOL}, boot environment ${be})"
}


main "$@"
