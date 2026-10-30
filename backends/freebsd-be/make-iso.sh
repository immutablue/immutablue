#!/bin/bash
# make-iso.sh - Build a bootable Immutablue FreeBSD installer ISO from an image
#
# The ISO's root filesystem is the image itself (cd9660, read-only), booted
# the way FreeBSD's own install media are: /tmp and /var are RAM disks, the
# desktop and Immutablue's services stay off, and /etc/rc.local starts the
# text installer (iso/installer.sh), which runs install-disk.sh with the live
# root as its source. Boots under BIOS (cdboot) and UEFI (loader.efi), as a
# CD and, being a hybrid image, written raw to a USB stick (dd).
#
# Runs as root on a FreeBSD host with the image in podman storage. On Linux
# it hands the job to the builder VM (builder-vm.sh iso), where freebsd-be
# images are built, and copies the ISO back; FREEBSD_VM_LIBVIRT=1 selects the
# libvirt builder, as for builder-vm.sh.
#
# Usage:
#   make-iso.sh [--autoinstall DISKS [--autoinstall-layout L]
#               [--autoinstall-swap SIZE] [--autoinstall-passphrase P]
#               [--autoinstall-user NAME --autoinstall-user-password P]
#               [--autoinstall-display-manager gdm|lightdm]]
#               <image:tag> <output.iso>
#
# Options:
#   --autoinstall DISKS  Install to DISKS (space-separated) unattended at boot
#                        and power off (for automated tests; wipes them
#                        without asking)
#   --autoinstall-layout L      stripe, mirror, raidz1, raidz2 or raidz3
#   --autoinstall-swap SIZE     swap on each disk, e.g. 2g
#   --autoinstall-user NAME     create user NAME (with --autoinstall-user-
#                               password P, also in loader.conf.local)
#   --autoinstall-display-manager DM  the login screen, gdm or lightdm
#   --autoinstall-passphrase P  GELI-encrypt with passphrase P. It is stored
#                               in the ISO's loader.conf.local: tests only
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


# Make the ISO a hybrid image, so it also boots written raw to a USB stick
# (dd, or any image writer) under UEFI and BIOS, as FreeBSD's own release
# ISOs do (release/amd64/mkisoimages.sh).
#
# A plain El Torito ISO only boots as a CD: a USB stick has no MBR or GPT
# for the firmware to find. This puts a protective MBR with BIOS boot code
# (pmbr), a freebsd-boot partition carrying isoboot (which reads the loader
# from the ISO9660 filesystem) and an EFI partition pointing at the ESP image
# already inside the ISO into the ISO's 32 KB system area, which ISO9660
# leaves unused. Booted that way the kernel still finds the root, because
# GEOM labels the raw stick (da0) as iso9660/IMMUTABLUE just as it does cd0.
#
# param $1: the live root (for boot/pmbr and boot/isoboot)
# param $2: the ISO to modify in place
make_hybrid() {
    if [[ $# -ne 2 ]]
    then
        echo 'make_hybrid() requires 2 positional arguments' >&2
        echo 'make_hybrid <root> <iso>' >&2
        exit 1
    fi

    local root="${1}"
    local iso="${2}"
    local entry
    local et_platform=""
    local et_lba=""
    local et_sectors=""
    local esp_param=""
    local hybrid="${WORK}/hybrid.img"
    local f

    for f in "${root}/boot/pmbr" "${root}/boot/isoboot"
    do
        if [[ ! -f "${f}" ]]
        then
            log "cannot make a hybrid image: ${f#"${root}"} is not in the image"
            exit 1
        fi
    done

    # Where the El Torito EFI image sits in the ISO: etdump prints each boot
    # catalog entry as one word of ';'-separated shell assignments
    # (et_platform, et_lba in 2048-byte sectors, et_sectors in 512-byte
    # ones), evaluated whole as mkisoimages.sh does -- after checking it is
    # nothing but et_* assignments of plain words.
    for entry in $(etdump --format shell "${iso}")
    do
        if [[ ! "${entry}" =~ ^(et_[a-z]+=[A-Za-z0-9._-]*;?)+$ ]]
        then
            log "unexpected etdump output: ${entry}"
            exit 1
        fi
        eval "${entry}"
        if [[ "${et_platform}" == "efi" ]] && [[ -n "${et_lba}" ]] && [[ -n "${et_sectors}" ]]
        then
            esp_param="-p efi::$(( et_sectors * 512 )):$(( et_lba * 2048 ))"
            break
        fi
    done
    if [[ -z "${esp_param}" ]]
    then
        log "cannot make a hybrid image: no EFI entry in ${iso}'s boot catalog"
        exit 1
    fi

    # The GPT and boot code, sized to the ISO, then only its first 32 KB is
    # written into the ISO: the backup GPT is left out, as on FreeBSD's media
    # (the kernel notes "the secondary GPT header is not in the last LBA").
    # shellcheck disable=SC2086 # esp_param is two words: -p and its value
    mkimg -s gpt --capacity "$(stat -f %z "${iso}")" \
        -b "${root}/boot/pmbr" \
        -p "freebsd-boot:=${root}/boot/isoboot" \
        ${esp_param} \
        -o "${hybrid}"
    dd if="${hybrid}" of="${iso}" bs=32k count=1 conv=notrunc status=none
    rm -f "${hybrid}"
    log "hybrid: GPT with isoboot (BIOS) and the ESP (UEFI) in the system area"
}


main() {
    local autoinstall=""
    local auto_layout=""
    local auto_swap=""
    local auto_pass=""
    local auto_user=""
    local auto_user_pass=""
    local auto_dm=""
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
            --autoinstall-layout) auto_layout="$2"; shift ;;
            --autoinstall-swap) auto_swap="$2"; shift ;;
            --autoinstall-passphrase) auto_pass="$2"; shift ;;
            --autoinstall-user) auto_user="$2"; shift ;;
            --autoinstall-user-password) auto_user_pass="$2"; shift ;;
            --autoinstall-display-manager) auto_dm="$2"; shift ;;
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
            FREEBSD_ISO_AUTOINSTALL_LAYOUT="${auto_layout}" FREEBSD_ISO_AUTOINSTALL_SWAP="${auto_swap}" \
            FREEBSD_ISO_AUTOINSTALL_PASSPHRASE="${auto_pass}" \
            FREEBSD_ISO_AUTOINSTALL_USER="${auto_user}" FREEBSD_ISO_AUTOINSTALL_USER_PASSWORD="${auto_user_pass}" \
            FREEBSD_ISO_AUTOINSTALL_DISPLAY_MANAGER="${auto_dm}" \
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
        if [[ -n "${auto_layout}" ]]
        then
            printf 'immutablue.autoinstall_layout="%s"\n' "${auto_layout}" >> "${root}/boot/loader.conf.local"
        fi
        if [[ -n "${auto_swap}" ]]
        then
            printf 'immutablue.autoinstall_swap="%s"\n' "${auto_swap}" >> "${root}/boot/loader.conf.local"
        fi
        if [[ -n "${auto_pass}" ]]
        then
            printf 'immutablue.autoinstall_passphrase="%s"\n' "${auto_pass}" >> "${root}/boot/loader.conf.local"
        fi
        if [[ -n "${auto_user}" ]]
        then
            printf 'immutablue.autoinstall_user="%s"\nimmutablue.autoinstall_user_password="%s"\n' \
                "${auto_user}" "${auto_user_pass}" >> "${root}/boot/loader.conf.local"
        fi
        if [[ -n "${auto_dm}" ]]
        then
            printf 'immutablue.autoinstall_display_manager="%s"\n' "${auto_dm}" >> "${root}/boot/loader.conf.local"
        fi
    fi
    mkdir -p "${root}/usr/libexec/immutablue"
    install -m 0555 "$(dirname "$0")/iso/installer.sh" "${root}/usr/libexec/immutablue/freebsd-installer"
    cat > "${root}/etc/rc.local" <<'EOF'
#!/bin/sh
# Immutablue installer ISO: run the installer during boot, as FreeBSD's own
# install media run bsdinstall -- on the screen. console="vidconsole,
# comconsole" (loader.conf.local) makes the kernel pick the serial port as
# its primary console whenever the machine has one (every libvirt domain
# does), and rc.local's /dev/console would put the installer there while the
# screen showed a frozen boot log. ttyv0 is the first virtual terminal on
# the screen; a machine without one (headless) keeps the console.
export TERM=xterm
if [ -c /dev/ttyv0 ]; then
    exec /usr/local/bin/bash /usr/libexec/immutablue/freebsd-installer < /dev/ttyv0 > /dev/ttyv0 2>&1
fi
exec /usr/local/bin/bash /usr/libexec/immutablue/freebsd-installer
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
    make_hybrid "${root}" "${out}"
    log "wrote ${out} ($(du -h "${out}" | cut -f1))"
}


main "$@"
