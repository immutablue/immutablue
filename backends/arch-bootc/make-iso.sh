#!/bin/bash
# make-iso.sh - Build a bootable Immutablue Arch installer ISO from an image
#
# bootc-image-builder does not support Arch, so this builds a live ISO the
# dracut way: the image's root as LiveOS/squashfs.img (dmsquash-live), its
# kernel and a live initramfs on a systemd-boot ESP, and the image itself as
# a compressed OCI image layout that the installer on tty1 hands to 'bootc install
# to-disk'. UEFI only (bootc on Arch installs systemd-boot).
#
# Assembly runs in a container of the image (iso/assemble.sh), so the host
# needs podman and xorriso only.
#
# Usage:
#   make-iso.sh [--autoinstall DISK] <image:tag> <output.iso>
#
# Options:
#   --autoinstall DISK  Install to DISK (e.g. /dev/vda) unattended at boot and
#                       power off (for automated tests; wipes DISK)
#   -h, --help          Show this help message
#   --license           Show license information
#
# Examples:
#   backends/arch-bootc/make-iso.sh quay.io/immutablue/immutablue:arch iso/immutablue-arch.iso
#   make ARCHLINUX=1 iso
#
# Exit codes:
#   0 - ISO written
#   1 - A step failed
#   2 - Usage error

set -euo pipefail

LABEL="IMMUTABLUE"
HERE="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK=""
CID=""


show_help() {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


log() {
    echo "make-iso: $*" >&2
}


cleanup() {
    if [[ -n "${CID}" ]]
    then
        podman rm -f "${CID}" > /dev/null 2>&1 || true
    fi
    if [[ -n "${WORK}" ]] && [[ -d "${WORK}" ]]
    then
        # Files written by the container may belong to subuids.
        podman unshare rm -rf "${WORK}"
    fi
}


main() {
    local autoinstall=""
    local args=()
    local image
    local out

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
    out="$(realpath -m "${args[1]}")"
    command -v xorriso > /dev/null || { log "xorriso is required (Fedora: xorriso)"; return 1; }

    trap cleanup EXIT
    mkdir -p "$(dirname "${out}")"
    WORK="$(mktemp -d "$(dirname "${out}")/.iso-build.XXXXXX")"
    mkdir -p "${WORK}/iso"

    # -----------------------------------
    # Live root, kernel, initramfs and ESP, built by the image itself
    # -----------------------------------
    log "assembling the live system from ${image}"
    CID="$(podman create "${image}" /bin/true)"
    podman export "${CID}" | podman run --rm -i --security-opt label=disable \
        -v "${WORK}:/out" -v "${HERE}/iso:/iso-src:ro" \
        "${image}" bash /iso-src/assemble.sh "${LABEL}" "${autoinstall}"

    # -----------------------------------
    # The image the installer installs, as an OCI layout (read in place; an
    # oci-archive would be unpacked into the live system's RAM-backed /var/tmp),
    # and the reference updates come from
    # -----------------------------------
    log "archiving ${image}"
    podman push --compression-format zstd --force-compression --quiet \
        "${image}" "oci:${WORK}/iso/image"
    echo "${image}" > "${WORK}/iso/image.ref"

    # -----------------------------------
    # ISO 9660 (level 3: the squashfs and image layers can exceed 4 GiB). The ESP
    # image sits inside the ISO tree as the UEFI El Torito image -- OVMF
    # rejects one appended outside the ISO volume -- and is also exposed as
    # a GPT partition, so the same file boots written to a USB stick.
    # -----------------------------------
    log "writing ${out}"
    rm -f "${out}"
    mv "${WORK}/esp.img" "${WORK}/iso/efiboot.img"
    xorriso -as mkisofs -iso-level 3 -rock -joliet -volid "${LABEL}" \
        -e efiboot.img -no-emul-boot -isohybrid-gpt-basdat \
        -o "${out}" "${WORK}/iso"
    log "wrote ${out} ($(du -h "${out}" | cut -f1))"
}


main "$@"
