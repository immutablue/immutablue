#!/bin/bash
# make-iso.sh - Build a bootable Immutablue FreeBSD installer ISO from an image
#
# The ISO's root filesystem is the image itself (cd9660, read-only), booted
# the way FreeBSD's own install media are: /tmp and /var are RAM disks, the
# desktop and Immutablue's services stay off, and /etc/rc.local starts the
# text installer (iso/installer.sh), which runs install-disk.sh with the live
# root as its source. Boots under BIOS (cdboot) and UEFI (loader.efi).
#
# Runs as root on a FreeBSD host with the image in podman storage. On Linux
# it hands the job to the builder VM (builder-vm.sh iso), where freebsd-be
# images are built, and copies the ISO back; FREEBSD_VM_LIBVIRT=1 selects the
# libvirt builder, as for builder-vm.sh.
#
# Usage:
#   make-iso.sh [--autoinstall DISK] <image:tag> <output.iso>
#
# Options:
#   --autoinstall DISK  Install to DISK unattended at boot and power off
#                       (for automated tests; wipes DISK without asking)
#   -h, --help          Show this help message
#   --license           Show license information
#
# Examples:
#   sudo backends/freebsd-be/make-iso.sh quay.io/immutablue/immutablue:15.1-freebsd /var/tmp/immutablue.iso
#   make FREEBSD=1 iso
#
# Exit codes:
#   0 - ISO written
#   1 - A step failed
#   2 - Usage error

set -euo pipefail

LABEL="IMMUTABLUE"
STOCK_REL="usr/share/immutablue/stock"
WORK=""
CID=""
MD=""


show_help() {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


log() {
    echo "make-iso: $*" >&2
}


cleanup() {
    if [[ -n "${MD}" ]]
    then
        umount "${WORK}/esp" 2>/dev/null || true
        mdconfig -d -u "${MD}" 2>/dev/null || true
    fi
    if [[ -n "${CID}" ]]
    then
        podman rm -f "${CID}" > /dev/null 2>&1 || true
    fi
    if [[ -n "${WORK}" ]] && [[ -d "${WORK}" ]]
    then
        chflags -R noschg "${WORK}" 2>/dev/null || true
        rm -rf "${WORK}"
    fi
}


main() {
    local autoinstall=""
    local args=()
    local image
    local out
    local root
    local mode
    local flags
    local path

    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -h|--help) show_help; return 0 ;;
            --license) echo 'make-iso.sh - part of Immutablue. AGPL-3.0-or-later.'; return 0 ;;
            --autoinstall) autoinstall="$2"; shift ;;
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
    out="${args[1]}"

    if [[ "$(uname -s)" != "FreeBSD" ]]
    then
        log "not on FreeBSD: building in the builder VM"
        FREEBSD_IMAGE_REF="${image}" FREEBSD_ISO_AUTOINSTALL="${autoinstall}" \
            exec bash "$(dirname "$0")/builder-vm.sh" iso "${out}"
    fi
    if [[ "$(id -u)" -ne 0 ]]
    then
        log "run as root"
        return 2
    fi
    if ! command -v xorriso > /dev/null
    then
        log "xorriso is required: pkg install xorriso"
        return 1
    fi

    trap cleanup EXIT
    WORK="$(mktemp -d /var/tmp/immutablue-iso.XXXXXX)"
    root="${WORK}/root"
    mkdir -p "${root}"

    # -----------------------------------
    # The image's tree, with the modes buildah dropped put back
    # -----------------------------------
    log "exporting ${image}"
    CID="$(podman create "${image}" /bin/true)"
    podman export "${CID}" | tar -xpf - -C "${root}"
    if [[ -f "${root}/${STOCK_REL}/modes" ]]
    then
        while IFS=$'\t' read -r mode flags path
        do
            [[ -n "${path}" ]] && [[ -e "${root}${path}" ]] || continue
            # A hard link of an earlier entry already carries its schg flag.
            chflags noschg "${root}${path}" 2>/dev/null || true
            chmod "${mode}" "${root}${path}"
            if [[ "${flags}" != "-" ]]
            then
                chflags "${flags}" "${root}${path}"
            fi
        done < "${root}/${STOCK_REL}/modes"
    fi

    # The live /var is a RAM disk; the image's own /var (package database
    # included) is kept aside for install-disk.sh --source-root.
    mkdir -p "${root}/.immutablue-image"
    mv "${root}/var" "${root}/.immutablue-image/var"
    mkdir -p "${root}/var" "${root}/tmp"

    # -----------------------------------
    # The live session
    # -----------------------------------
    printf '/dev/iso9660/%s / cd9660 ro 0 0\n' "${LABEL}" > "${root}/etc/fstab"
    cat > "${root}/etc/rc.conf.local" <<'EOF'
# Immutablue installer ISO (make-iso.sh): read-only root, RAM-backed /tmp and
# /var, nothing but the installer.
root_rw_mount="NO"
tmpmfs="YES"
tmpsize="1024m"
varmfs="YES"
varsize="1024m"
populate_var="YES"
hostname="immutablue-installer"
gdm_enable="NO"
dbus_enable="NO"
immutablue_first_boot_enable="NO"
immutablue_onboot_enable="NO"
immutablue_readonly_usr_enable="NO"
immutablue_xorg_enable="NO"
immutablue_procfs_enable="NO"
sshd_enable="NO"
tailscaled_enable="NO"
cloudinit_enable="NO"
cron_enable="NO"
zfs_enable="NO"
EOF
    cat > "${root}/boot/loader.conf.local" <<EOF
# Immutablue installer ISO (make-iso.sh)
vfs.root.mountfrom="cd9660:/dev/iso9660/${LABEL}"
autoboot_delay="3"
# Screen first, serial second: with "vidconsole" alone the UEFI loader
# still adds a serial port it finds in the firmware's ConOut (libvirt
# domains have one) and makes it the primary console, where rc(8) output --
# the installer -- goes.
console="vidconsole,comconsole"
EOF
    if [[ -n "${autoinstall}" ]]
    then
        printf 'immutablue.autoinstall="%s"\n' "${autoinstall}" >> "${root}/boot/loader.conf.local"
    fi
    mkdir -p "${root}/usr/libexec/immutablue"
    install -m 0555 "$(dirname "$0")/iso/installer.sh" "${root}/usr/libexec/immutablue/freebsd-installer"
    cat > "${root}/etc/rc.local" <<'EOF'
#!/bin/sh
# Immutablue installer ISO: run the installer on the console during boot,
# as FreeBSD's own install media run bsdinstall.
export TERM=xterm
/usr/local/bin/bash /usr/libexec/immutablue/freebsd-installer
EOF
    chmod 0555 "${root}/etc/rc.local"

    # -----------------------------------
    # Boot images: cdboot (BIOS) and an ESP image with loader.efi (UEFI)
    # -----------------------------------
    # (newfs_msdos on an md(4) device: makefs -t msdos wrote a FAT here
    # whose BOOTX64.EFI cluster chain was truncated, which UEFI refuses.)
    truncate -s 8m "${WORK}/efiboot.img"
    MD="$(mdconfig -a -t vnode -f "${WORK}/efiboot.img")"
    newfs_msdos -F 12 -L EFISYS "/dev/${MD}" > /dev/null
    mkdir -p "${WORK}/esp"
    mount -t msdosfs "/dev/${MD}" "${WORK}/esp"
    mkdir -p "${WORK}/esp/EFI/BOOT"
    cp "${root}/boot/loader.efi" "${WORK}/esp/EFI/BOOT/BOOTX64.EFI"
    umount "${WORK}/esp"
    mdconfig -d -u "${MD}"
    MD=""

    log "writing ${out}"
    # xorriso, not makefs(8): makefs -t cd9660 segfaults on this tree (KDE's
    # headers have directories differing only in case, e.g. KF6/Solid/Solid
    # and KF6/Solid/solid). Rock Ridge carries the real names; deep trees are
    # written in place rather than relocated, which FreeBSD's cd9660 reads.
    # efiboot.img is grafted at the ISO root, outside the live tree.
    xorriso -as mkisofs -quiet -iso-level 3 -R -V "${LABEL}" -publisher "Immutablue" \
        -disable-deep-relocation \
        -b boot/cdboot -no-emul-boot -boot-load-size 4 \
        -eltorito-alt-boot -e efiboot.img -no-emul-boot \
        -graft-points -o "${out}" \
        "/=${root}" "/efiboot.img=${WORK}/efiboot.img"
    log "wrote ${out} ($(du -h "${out}" | cut -f1))"
}


main "$@"
