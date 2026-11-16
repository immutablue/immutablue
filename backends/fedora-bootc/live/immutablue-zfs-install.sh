#!/bin/bash
# immutablue-zfs-install - Install Immutablue with its root on ZFS
#
# Runs on the live ISO of an image that ships ZFS (ZFS=1, TRUEBLUE=1, LTS=1),
# where Anaconda cannot help: it has no ZFS support. Turns one or more empty
# disks into a ZFS pool and installs the image on the ISO into it, so the
# installed system updates, rolls back and rebases like any other bootc
# system -- only its root is a ZFS dataset.
#
# 'bootc install to-filesystem' refuses a ZFS root ("Unknown filesystem"),
# so this does what it does by hand, as Anaconda's ostreecontainer does:
# 'ostree container image deploy' into a fresh sysroot, the image's
# kargs.d, 'bootupctl backend install' for shim and GRUB, and an fstab.
#
# Every disk gets the same partitions, so a mirror or raidz has equal-sized
# members; the first disk's ESP and /boot are the ones used:
#
#   p1  BIOS   1M    BIOS boot partition (GRUB core image, BIOS machines)
#   p2  ESP    512M  FAT32: shim and GRUB (bootupd)
#   p3  /boot  2G    ext4: kernels and initramfs (GRUB cannot read ZFS)
#   p4  ZFS    rest  a vdev member of pool <pool>
#
#   pool <pool>, layout stripe | mirror | raidz1 | raidz2 | raidz3:
#         <pool>/ROOT/immutablue   /          (ostree's physical root: deployments
#                                              and the stateroot's /var)
#         <pool>/home              /var/home  (user data, snapshot it on its own)
#
# Encryption (--encrypt) is ZFS native encryption (aes-256-gcm) on the whole
# pool with a passphrase: the initramfs asks for it at boot.
#
# The pool gets a fixed hostid, written to the installed system's /etc/hostid
# and passed as spl_hostid= on the kernel command line. The image's initramfs
# carries whatever hostid its build machine had, which changes from build to
# build; without this the pool would refuse to import after an update.
#
# Usage:
#   immutablue-zfs-install [options] <disk>...
#
# Options:
#   --layout LAYOUT   stripe, mirror, raidz1, raidz2 or raidz3 (default:
#                     stripe for one disk, mirror for several). Minimum
#                     disks: mirror and raidz1 2, raidz2 3, raidz3 4
#   --encrypt         Encrypt the pool; needs --passphrase-file
#   --passphrase-file FILE
#                     the passphrase (at least 8 characters), the whole file
#                     (a trailing newline is removed)
#   --pool NAME       zpool name (default: zimmutablue; must not exist)
#   --hostname NAME   hostname (default: immutablue)
#   --source IMGREF   image to install (default: the OCI layout on the ISO,
#                     oci:/run/initramfs/live/image)
#   --target-imgref REF
#                     registry reference updates come from (default: the one
#                     recorded on the ISO, /run/initramfs/live/image.ref)
#   --yes             do not ask before destroying the disks' contents
#   -h, --help        Show this help message
#   --license         Show license information
#
# Examples:
#   sudo immutablue-zfs-install /dev/nvme0n1
#   sudo immutablue-zfs-install --layout mirror /dev/sda /dev/sdb
#   sudo immutablue-zfs-install --encrypt --passphrase-file /tmp/pw --layout raidz1 \
#       /dev/sda /dev/sdb /dev/sdc
#
# Exit codes:
#   0 - Installed
#   1 - A step failed (the disks are left partially written)
#   2 - Usage error, or a disk is in use

set -euo pipefail

LIVE="/run/initramfs/live"
TARGET="/run/immutablue-zfs-target"
POOL="zimmutablue"
HOSTNAME_NEW="immutablue"
LAYOUT=""
ENCRYPT=0
PASSFILE=""
SOURCE="oci:${LIVE}/image"
TARGET_REF=""
ASSUME_YES=0
DISKS=()
POOL_CREATED=0


show_help () {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


log () {
    echo "immutablue-zfs-install: $*" >&2
}


die () {
    log "ERROR: $*"
    exit 1
}


# Partition N of a disk: /dev/sda -> /dev/sda3, /dev/nvme0n1 -> /dev/nvme0n1p3
#
# param $1: disk
# param $2: partition number
part () {
    if [[ "$1" =~ [0-9]$ ]]
    then
        echo "$1p$2"
    else
        echo "$1$2"
    fi
}


# On failure, leave nothing mounted and the pool exported, so a second run
# (or a reboot) does not trip over it.
cleanup () {
    local rc=$?

    if mountpoint -q "${TARGET}/boot/efi" 2> /dev/null
    then
        umount "${TARGET}/boot/efi" || true
    fi
    if mountpoint -q "${TARGET}/boot" 2> /dev/null
    then
        umount "${TARGET}/boot" || true
    fi
    if [[ ${POOL_CREATED} -eq 1 ]] && zpool list "${POOL}" > /dev/null 2>&1
    then
        zfs unmount -a -f > /dev/null 2>&1 || true
        zpool export "${POOL}" || log "could not export ${POOL}; export it before rebooting"
    fi
    if [[ ${rc} -ne 0 ]]
    then
        log "installation failed (exit ${rc})"
    fi
}


parse_args () {
    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            --license) echo 'immutablue-zfs-install - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
            --layout) LAYOUT="$2"; shift ;;
            --encrypt) ENCRYPT=1 ;;
            --passphrase-file) PASSFILE="$2"; shift ;;
            --pool) POOL="$2"; shift ;;
            --hostname) HOSTNAME_NEW="$2"; shift ;;
            --source) SOURCE="$2"; shift ;;
            --target-imgref) TARGET_REF="$2"; shift ;;
            --yes) ASSUME_YES=1 ;;
            -*) log "unknown option $1"; exit 2 ;;
            *) DISKS+=("$1") ;;
        esac
        shift
    done
}


# -----------------------------------
# Refuse anything that would surprise: unknown layouts, too few disks,
# disks in use, an existing pool name, a missing passphrase.
# -----------------------------------
validate () {
    local disk
    local need

    [[ ${EUID} -eq 0 ]] || { log "must run as root"; exit 2; }
    [[ ${#DISKS[@]} -gt 0 ]] || { show_help >&2; exit 2; }
    command -v zpool > /dev/null || die "this image has no ZFS (build it with ZFS=1 or TRUEBLUE=1)"
    modprobe zfs || die "the zfs kernel module does not load"

    if [[ -z "${LAYOUT}" ]]
    then
        if [[ ${#DISKS[@]} -eq 1 ]]
        then
            LAYOUT="stripe"
        else
            LAYOUT="mirror"
        fi
    fi
    case "${LAYOUT}" in
        stripe) need=1 ;;
        mirror|raidz1) need=2 ;;
        raidz2) need=3 ;;
        raidz3) need=4 ;;
        *) log "unknown layout ${LAYOUT}"; exit 2 ;;
    esac
    [[ ${#DISKS[@]} -ge ${need} ]] || { log "${LAYOUT} needs at least ${need} disks"; exit 2; }

    for disk in "${DISKS[@]}"
    do
        [[ -b "${disk}" ]] || { log "${disk} is not a block device"; exit 2; }
        if lsblk -nro MOUNTPOINTS "${disk}" | grep -q .
        then
            log "${disk} has mounted filesystems"
            exit 2
        fi
    done

    if zpool list "${POOL}" > /dev/null 2>&1
    then
        log "a pool named ${POOL} is already imported"
        exit 2
    fi
    [[ "${POOL}" =~ ^[A-Za-z][A-Za-z0-9_.:-]*$ ]] || { log "invalid pool name ${POOL}"; exit 2; }

    if [[ ${ENCRYPT} -eq 1 ]]
    then
        [[ -r "${PASSFILE}" ]] || { log "--encrypt needs a readable --passphrase-file"; exit 2; }
        [[ $(tr -d '\n' < "${PASSFILE}" | wc -c) -ge 8 ]] || { log "the passphrase must be at least 8 characters"; exit 2; }
    fi

    if [[ -z "${TARGET_REF}" ]]
    then
        [[ -r "${LIVE}/image.ref" ]] || die "no --target-imgref and no ${LIVE}/image.ref"
        TARGET_REF="$(< "${LIVE}/image.ref")"
    fi
}


confirm () {
    local answer

    if [[ ${ASSUME_YES} -eq 1 ]]
    then
        return 0
    fi
    echo "This ERASES everything on: ${DISKS[*]}"
    echo "Pool ${POOL} (${LAYOUT}$([[ ${ENCRYPT} -eq 1 ]] && echo ', encrypted')), image ${TARGET_REF}"
    read -r -p "Type 'yes' to continue: " answer
    [[ "${answer}" == "yes" ]] || { log "aborted"; exit 2; }
}


# -----------------------------------
# Partitions: identical on every disk. Old filesystem, RAID and ZFS labels
# are wiped first so neither udev nor zpool finds a ghost of a previous pool.
# -----------------------------------
partition_disks () {
    local disk
    local i=0

    for disk in "${DISKS[@]}"
    do
        log "partitioning ${disk}"
        zpool labelclear -f "${disk}" > /dev/null 2>&1 || true
        wipefs -a -q "${disk}"
        sgdisk --zap-all "${disk}" > /dev/null
        sgdisk -n1:1M:+1M -t1:EF02 -c1:"bios${i}" \
            -n2:0:+512M -t2:EF00 -c2:"EFI-SYSTEM" \
            -n3:0:+2G -t3:8300 -c3:"boot${i}" \
            -n4:0:0 -t4:BF00 -c4:"zfs${i}" "${disk}" > /dev/null
        i=$((i + 1))
    done
    udevadm settle
    partprobe "${DISKS[@]}" 2> /dev/null || true
    udevadm settle
}


# -----------------------------------
# The pool and its datasets, mounted under ${TARGET} (altroot).
# -----------------------------------
create_pool () {
    local disk
    local vdevs=()
    local enc=()
    local hostid_hex

    # The hostid the pool is created under, and the installed system's
    hostid_hex="$(od -An -tx4 -N4 /dev/urandom | tr -d ' \n')"
    zgenhostid -f "${hostid_hex}"
    HOSTID="$(hostid)"

    for disk in "${DISKS[@]}"
    do
        vdevs+=("/dev/disk/by-partuuid/$(blkid -s PARTUUID -o value "$(part "${disk}" 4)")")
    done
    if [[ "${LAYOUT}" != "stripe" ]]
    then
        vdevs=("${LAYOUT}" "${vdevs[@]}")
    fi
    if [[ ${ENCRYPT} -eq 1 ]]
    then
        enc=(-O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt)
    fi

    log "creating pool ${POOL} (${LAYOUT}), hostid ${HOSTID}"
    mkdir -p "${TARGET}"
    tr -d '\n' < "${PASSFILE:-/dev/null}" | zpool create -f \
        -o ashift=12 -o autotrim=on -o cachefile=none \
        -O acltype=posixacl -O xattr=sa -O dnodesize=auto \
        -O compression=zstd -O normalization=formD -O relatime=on \
        -O canmount=off -O mountpoint=none \
        "${enc[@]}" \
        -R "${TARGET}" "${POOL}" "${vdevs[@]}"
    POOL_CREATED=1

    # ostree fsyncs every object it writes; on ZFS each fsync is a ZIL
    # write, which makes the deploy ~5x slower (thousands of tiny sync
    # writes a second). Nothing here needs per-file durability: the pool is
    # exported at the end, which flushes everything, and an interrupted
    # install is redone anyway. Restored in finish_pool.
    zfs set sync=disabled "${POOL}"

    zfs create -o canmount=off -o mountpoint=none "${POOL}/ROOT"
    zfs create -o canmount=noauto -o mountpoint=/ "${POOL}/ROOT/immutablue"
    zpool set bootfs="${POOL}/ROOT/immutablue" "${POOL}"
    zfs mount "${POOL}/ROOT/immutablue"
}


# -----------------------------------
# ESP and /boot on the first disk, mounted where ostree and bootupd expect
# them
# -----------------------------------
create_boot () {
    local esp
    local boot

    esp="$(part "${DISKS[0]}" 2)"
    boot="$(part "${DISKS[0]}" 3)"
    mkfs.fat -F 32 -n EFI "${esp}" > /dev/null
    mkfs.ext4 -q -F -L boot "${boot}"
    mkdir -p "${TARGET}/boot"
    mount "${boot}" "${TARGET}/boot"
    mkdir -p "${TARGET}/boot/efi"
    mount -o umask=0077 "${esp}" "${TARGET}/boot/efi"
    BOOT_UUID="$(blkid -s UUID -o value "${boot}")"
    ESP_UUID="$(blkid -s UUID -o value "${esp}")"
}


# -----------------------------------
# Kernel arguments the image asks for in /usr/lib/bootc/kargs.d (bootc
# applies them on install and update; 'ostree container image deploy' does
# not). The live root is the image, so its kargs.d is the image's.
# -----------------------------------
image_kargs () {
    local f
    local arches

    for f in /usr/lib/bootc/kargs.d/*.toml
    do
        [[ -f "${f}" ]] || continue
        arches="$(yq -p toml -o y '.match-architectures // [] | .[]' "${f}" 2> /dev/null)"
        if [[ -n "${arches}" ]] && ! grep -qx "$(uname -m)" <<< "${arches}"
        then
            continue
        fi
        yq -p toml -o y '.kargs // [] | .[]' "${f}"
    done
}


# -----------------------------------
# The image, from the ISO, into a new ostree sysroot on the root dataset;
# its origin points at the registry, so updates come from there. Repo
# settings as bootc's own install: read-only sysroot, and no ostree-managed
# bootloader config (bootupd's static GRUB config reads the BLS entries).
# -----------------------------------
install_image () {
    local repo="${TARGET}/ostree/repo"
    local kargs=(--karg "root=zfs:${POOL}/ROOT/immutablue" --karg rw --karg "spl_hostid=0x${HOSTID}")
    local karg

    while read -r karg
    do
        [[ -n "${karg}" ]] && kargs+=(--karg "${karg}")
    done < <(image_kargs)

    log "installing ${SOURCE} (updates from ${TARGET_REF})"
    ostree admin init-fs --modern "${TARGET}"
    ostree config --repo "${repo}" set sysroot.bootloader none
    ostree config --repo "${repo}" set sysroot.readonly true
    ostree admin stateroot-init --sysroot "${TARGET}" default
    ostree container image deploy --sysroot "${TARGET}" --stateroot default \
        --imgref "ostree-unverified-image:${SOURCE}" \
        --target-imgref "ostree-unverified-registry:${TARGET_REF}" \
        "${kargs[@]}"

    DEPLOY="$(find "${TARGET}/ostree/deploy/default/deploy" -mindepth 1 -maxdepth 1 -type d -name '*.0' | head -n 1)"
    [[ -d "${DEPLOY}/etc" ]] || die "no deployment found under ${TARGET}/ostree"
}


# -----------------------------------
# shim and GRUB, from the deployment, onto the first disk: the ESP, plus the
# BIOS boot partition when the live system booted under BIOS (--auto picks
# the components the firmware uses).
# -----------------------------------
install_bootloader () {
    log "installing the bootloader on ${DISKS[0]}"
    bootupctl backend install --auto --write-uuid --with-static-configs --update-firmware \
        --device "${DISKS[0]}" --src-root "${DEPLOY}" "${TARGET}"
}


# -----------------------------------
# Machine-specific files in the new deployment's /etc (ostree carries them
# across updates), and the home dataset.
# -----------------------------------
configure_target () {
    local deploy_etc="${DEPLOY}/etc"
    local lang

    zgenhostid -f -o "${deploy_etc}/hostid" "${HOSTID}"
    echo "${HOSTNAME_NEW}" > "${deploy_etc}/hostname"

    # Language and console keymap. The live session runs in C.UTF-8, which
    # GNOME's first-login setup shows as "Unspecified"; like Anaconda's
    # default, fall back to en_US.UTF-8 (the setup offers to change both).
    lang="$(. /etc/locale.conf 2> /dev/null && echo "${LANG:-}")"
    if [[ -z "${lang}" ]] || [[ "${lang}" == C* ]] || [[ "${lang}" == POSIX ]]
    then
        lang="en_US.UTF-8"
    fi
    echo "LANG=\"${lang}\"" > "${deploy_etc}/locale.conf"
    if [[ -f /etc/vconsole.conf ]]
    then
        cp /etc/vconsole.conf "${deploy_etc}/vconsole.conf"
    fi

    # / is mounted by the initramfs from root=zfs:..., and the home dataset by
    # zfs-mount.service; fstab only has the partitions
    {
        echo "# Created by immutablue-zfs-install"
        echo "UUID=${BOOT_UUID} /boot ext4 defaults 1 2"
        echo "UUID=${ESP_UUID} /boot/efi vfat umask=0077,shortname=winnt 0 2"
    } > "${deploy_etc}/fstab"

    # /var/home as its own dataset, mounted by zfs-mount.service at boot over
    # the stateroot's empty /var/home. Created after the deploy, so the
    # physical root holds only ostree's tree; the mountpoint directory it
    # leaves there is removed again. Labelled home_root_t, as /var/home is on
    # every other install.
    zfs create -o mountpoint=/var/home -o canmount=on "${POOL}/home"
    chcon system_u:object_r:home_root_t:s0 "${TARGET}/var/home" 2> /dev/null \
        || log "warning: could not label ${POOL}/home (relabel /var/home after first boot)"
    zfs unmount "${POOL}/home"
    rmdir "${TARGET}/var/home" "${TARGET}/var" 2> /dev/null || true
}


# -----------------------------------
# Back to normal write semantics, and the pool exported cleanly so the
# installed system's initramfs imports it on first boot
# -----------------------------------
finish_pool () {
    zfs inherit sync "${POOL}"
    umount "${TARGET}/boot/efi"
    umount "${TARGET}/boot"
    zfs unmount -a
    zpool export "${POOL}"
    POOL_CREATED=0
}


main () {
    parse_args "$@"
    validate
    confirm
    trap cleanup EXIT
    partition_disks
    create_pool
    create_boot
    install_image
    install_bootloader
    configure_target
    finish_pool
    log "installed: pool ${POOL} on ${DISKS[*]}; remove the installation media and reboot"
}


main "$@"
