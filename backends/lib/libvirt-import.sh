#!/bin/bash
# libvirt-import.sh - Import a disk image as a libvirt domain (visible in virt-manager)
#
# The system QEMU that libvirt runs cannot read files under a home directory,
# so the disk (and an optional read-only seed disk) are uploaded as volumes of
# a storage pool (the 'default' pool, /var/lib/libvirt/images) and a domain is
# defined around them with virt-install --import: virtio disk and network on
# the 'default' NAT network, SPICE graphics and a virtio GPU, so the console
# shows up in virt-manager. No TPM is emulated (swtpm is not needed by these
# images and is not set up on every host).
#
# Usage:
#   libvirt-import.sh [options] <domain-name> <disk-file>
#
# Options:
#   --uefi            Boot with UEFI firmware, Secure Boot off (bootc images:
#                     unsigned systemd-boot)
#   --osinfo ID       libosinfo id (default: detect, then generic)
#   --seed FILE       Attach FILE (e.g. a cloud-init seed ISO) as a read-only disk
#   --memory MIB      Memory (default 8192)
#   --vcpus N         vCPUs (default 4)
#   --replace         Remove an existing domain and volumes of the same name first
#   --no-start        Define the domain without starting it
#   -h, --help        Show this help message
#   --license         Show license information
#
# Environment:
#   LIBVIRT_DEFAULT_URI   libvirt connection (default qemu:///system)
#   LIBVIRT_POOL          storage pool (default 'default')
#
# Examples:
#   libvirt-import.sh --uefi --osinfo archlinux immutablue-arch images/disk/arch.img
#   libvirt-import.sh --osinfo freebsd15.0 --seed images/freebsd-vm/seed.iso \
#       immutablue-freebsd-builder images/freebsd-vm/builder.qcow2
#   make BACKEND=arch-bootc bootc-disk-libvirt
#
# Exit codes:
#   0 - Domain defined (and started)
#   1 - A step failed
#   2 - Usage error

set -euo pipefail

URI="${LIBVIRT_DEFAULT_URI:-qemu:///system}"
POOL="${LIBVIRT_POOL:-default}"


show_help() {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


vsh() {
    virsh -q -c "${URI}" "$@"
}


# Upload a local file as a pool volume, keeping its format.
#
# param $1: volume name
# param $2: local file
# param $3: replace (1) or fail (0) when the volume exists
upload_volume() {
    local vol="$1"
    local file="$2"
    local replace="$3"
    local format
    local size

    if vsh vol-info --pool "${POOL}" "${vol}" > /dev/null 2>&1
    then
        if [[ "${replace}" -eq 1 ]]
        then
            vsh vol-delete --pool "${POOL}" "${vol}"
        else
            echo "ERROR: volume ${POOL}/${vol} exists (use --replace)" >&2
            return 1
        fi
    fi

    format="$(qemu-img info --output=json "${file}" | jq -r '.format')"
    # A qcow2's virtual size can exceed the file; the volume is sized for the
    # file's bytes, which is what vol-upload writes.
    size="$(stat -c %s "${file}")"
    vsh vol-create-as "${POOL}" "${vol}" "${size}" --format "${format}"
    vsh vol-upload --pool "${POOL}" "${vol}" "${file}" --sparse
    echo "Uploaded ${file} as ${POOL}/${vol} (${format})"
}


main() {
    local uefi=0
    local osinfo="detect=on,require=off"
    local seed=""
    local memory=8192
    local vcpus=4
    local replace=0
    local start=1
    local name
    local disk
    local ext
    local args=()

    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -h|--help) show_help; return 0 ;;
            --license) echo 'libvirt-import.sh - part of Immutablue. AGPL-3.0-or-later.'; return 0 ;;
            --uefi) uefi=1 ;;
            --osinfo) osinfo="$2"; shift ;;
            --seed) seed="$2"; shift ;;
            --memory) memory="$2"; shift ;;
            --vcpus) vcpus="$2"; shift ;;
            --replace) replace=1 ;;
            --no-start) start=0 ;;
            -*) echo "unknown option $1" >&2; return 2 ;;
            *) args+=("$1") ;;
        esac
        shift
    done

    if [[ ${#args[@]} -ne 2 ]]
    then
        show_help >&2
        return 2
    fi
    name="${args[0]}"
    disk="${args[1]}"

    if vsh dominfo "${name}" > /dev/null 2>&1
    then
        if [[ ${replace} -eq 1 ]]
        then
            vsh destroy "${name}" > /dev/null 2>&1 || true
            vsh undefine "${name}" --nvram > /dev/null 2>&1 || vsh undefine "${name}"
        else
            echo "ERROR: domain ${name} exists (use --replace)" >&2
            return 1
        fi
    fi

    ext="${disk##*.}"
    upload_volume "${name}.${ext}" "${disk}" "${replace}"

    local install=(virt-install --connect "${URI}" --name "${name}"
        --memory "${memory}" --vcpus "${vcpus}" --cpu host-passthrough
        --import --osinfo "${osinfo}"
        --disk "vol=${POOL}/${name}.${ext},bus=virtio"
        --network "network=default,model=virtio"
        --graphics spice --video virtio --tpm none
        --noautoconsole)

    if [[ -n "${seed}" ]]
    then
        upload_volume "${name}-seed.${seed##*.}" "${seed}" "${replace}"
        install+=(--disk "vol=${POOL}/${name}-seed.${seed##*.},bus=virtio,readonly=on")
    fi
    if [[ ${uefi} -eq 1 ]]
    then
        # Firmware without Secure Boot: libvirt otherwise picks an OVMF with
        # Microsoft's keys enrolled, which rejects the unsigned systemd-boot
        # that bootc installs.
        install+=(--boot "uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no")
    fi
    if [[ ${start} -eq 0 ]]
    then
        local xml
        xml="$(mktemp)"
        install+=(--print-xml)
        "${install[@]}" > "${xml}"
        vsh define "${xml}"
        rm -f "${xml}"
    else
        "${install[@]}"
    fi
    echo "Domain ${name} defined on ${URI}$( [[ ${start} -eq 1 ]] && echo ' and started')"
}


main "$@"
