#!/bin/bash
# make-live-iso.sh - Build a live installer ISO from an Immutablue fedora-bootc image
#
# The ISO boots a live desktop of the image (GNOME, as liveuser, no
# password) with Anaconda's installer, which installs the image to disk. The
# installed system then tracks the image's registry reference, so
# 'immutablue update' pulls from there. Works offline: the image itself is on
# the ISO.
#
#   1. podman build live/Containerfile on top of <image:tag>: livesys,
#      anaconda-live, dracut-live, the CD boot loaders (build-live.sh)
#   2. live/assemble.sh in that live image: squashfs root, live initramfs,
#      shim + GRUB for UEFI (Secure Boot), GRUB for BIOS
#   3. <image:tag> as a zstd OCI image layout at /image on the ISO, read in
#      place by the installer (ostreecontainer --transport=oci)
#   4. xorriso: one hybrid ISO that boots from optical media and from a USB
#      stick, under UEFI and BIOS
#
# The image must be in local container storage (make build, or podman pull).
# All tools run in containers; the host needs podman only.
#
# Usage:
#   make-live-iso.sh [options] <image:tag> <output.iso>
#
# Options:
#   --autoinstall DISK  Install to DISK (e.g. /dev/vda) unattended at boot and
#                       power off (for automated tests; wipes DISK)
#   --session NAME      livesys session (default: gnome)
#   --keep-live-image   Keep the intermediate live image (localhost/immutablue-live)
#   -h, --help          Show this help message
#   --license           Show license information
#
# Examples:
#   backends/fedora-bootc/make-live-iso.sh quay.io/immutablue/immutablue:44 iso/immutablue-44-live.iso
#   make LIVE=1 iso
#   make LIVE=1 TRUEBLUE=1 VERSION=44 iso
#   make LIVE=1 ISO_AUTOINSTALL=/dev/vda iso
#
# Exit codes:
#   0 - ISO written
#   1 - A step failed
#   2 - Usage error

set -euo pipefail

HERE="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK=""
CID=""
LIVE_IMAGE=""
KEEP_LIVE_IMAGE="false"


show_help () {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


log () {
    echo "make-live-iso: $*" >&2
}


cleanup () {
    if [[ -n "${CID}" ]]
    then
        podman rm -f "${CID}" > /dev/null 2>&1 || true
    fi
    if [[ -n "${WORK}" ]] && [[ -d "${WORK}" ]]
    then
        # Files written by the containers may belong to subuids
        podman unshare rm -rf "${WORK}"
    fi
    if [[ "${KEEP_LIVE_IMAGE}" != "true" ]] && [[ -n "${LIVE_IMAGE}" ]]
    then
        podman rmi -f "${LIVE_IMAGE}" > /dev/null 2>&1 || true
    fi
}


# ISO 9660 volume label from the image tag: upper case, at most 32
# characters of A-Z 0-9 _ - (the kernel argument root=live:CDLABEL= uses it).
#
# param $1: image tag
iso_label () {
    local label

    label="IMMUTABLUE-${1^^}"
    label="${label//[^A-Z0-9_-]/_}"
    echo "${label:0:32}"
}


main () {
    local autoinstall=""
    local session="gnome"
    local args=()
    local image
    local out
    local tag
    local label
    local title
    local hybrid=()

    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -h|--help) show_help; return 0 ;;
            --license) echo 'make-live-iso.sh - part of Immutablue. AGPL-3.0-or-later.'; return 0 ;;
            --autoinstall) autoinstall="$2"; shift ;;
            --session) session="$2"; shift ;;
            --keep-live-image) KEEP_LIVE_IMAGE="true" ;;
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
    tag="${image##*:}"
    label="$(iso_label "${tag}")"
    title="Immutablue ${tag}"
    LIVE_IMAGE="localhost/immutablue-live:${tag}"

    if ! podman image exists "${image}"
    then
        log "${image} is not in local container storage (make build, or podman pull ${image})"
        return 1
    fi

    trap cleanup EXIT
    mkdir -p "$(dirname "${out}")"
    WORK="$(mktemp -d "$(dirname "${out}")/.live-iso-build.XXXXXX")"
    mkdir -p "${WORK}/iso"

    # -----------------------------------
    # 1. The live system: the image plus installer and live session
    # -----------------------------------
    log "building the live system on ${image}"
    podman build --pull=never \
        --build-arg BASE_IMAGE="${image}" \
        --build-arg LIVE_SESSION="${session}" \
        -t "${LIVE_IMAGE}" "${HERE}/live"

    # -----------------------------------
    # 2. Live root, kernel, initramfs and boot loaders, built by the live
    #    image itself
    # -----------------------------------
    log "assembling the ISO tree"
    CID="$(podman create "${LIVE_IMAGE}" /bin/true)"
    podman export "${CID}" | podman run --rm -i --security-opt label=disable \
        -v "${WORK}:/out" -v "${HERE}/live:/live-src:ro" \
        "${LIVE_IMAGE}" bash /live-src/assemble.sh "${label}" "${title}" "${autoinstall}"
    podman rm -f "${CID}" > /dev/null
    CID=""

    # -----------------------------------
    # 3. The image the installer installs, as an OCI layout read in place
    #    (an oci-archive would be unpacked into the live RAM-backed /var/tmp)
    # -----------------------------------
    log "archiving ${image}"
    podman push --compression-format zstd --force-compression --quiet \
        "${image}" "oci:${WORK}/iso/image"
    echo "${image}" > "${WORK}/iso/image.ref"

    # -----------------------------------
    # 4. Hybrid ISO, as Fedora's own media: GPT with the ESP appended as
    #    partition 2 (UEFI, optical and USB), El Torito GRUB plus the hybrid
    #    MBR for BIOS on x86_64. ISO level 3: the squashfs and image layers
    #    can exceed 4 GiB.
    # -----------------------------------
    if [[ -f "${WORK}/boot_hybrid.img" ]]
    then
        hybrid=(
            --grub2-mbr /out/boot_hybrid.img -partition_offset 16
            -c boot.cat --boot-catalog-hide
            -b images/eltorito.img -no-emul-boot -boot-load-size 4
            -boot-info-table --grub2-boot-info
            -eltorito-alt-boot
        )
    fi
    log "writing ${out}"
    rm -f "${out}"
    podman run --rm --security-opt label=disable -v "${WORK}:/out" "${LIVE_IMAGE}" \
        xorriso -as mkisofs -o /out/live.iso -iso-level 3 -rock -volid "${label}" \
            "${hybrid[@]}" \
            -appended_part_as_gpt \
            -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B /out/efiboot.img \
            -iso_mbr_part_type EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 \
            -e '--interval:appended_partition_2:all::' -no-emul-boot \
            /out/iso
    mv "${WORK}/live.iso" "${out}"
    log "wrote ${out} ($(du -h "${out}" | cut -f1))"
}


main "$@"
