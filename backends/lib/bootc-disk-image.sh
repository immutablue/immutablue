#!/bin/bash
# bootc-disk-image.sh - Install a bootc image to a raw disk image file
#
# bootc-image-builder (make qcow2/raw/iso) only understands Fedora/RHEL-family
# images. For other bootc backends (arch-bootc) the image installs itself the
# way bootcrew does it: 'bootc install to-disk' run from the image, in a
# privileged rootful container, onto a loopback-attached file. The result is a
# GPT disk with an ESP, systemd-boot and a composefs root, bootable under
# UEFI (QEMU with OVMF, or dd to real media).
#
# Usage:
#   bootc-disk-image.sh <image:tag> <output.img> [size]
#
# Arguments:
#   image:tag   the image to install (rootless storage is copied to root's)
#   output.img  the disk image file to create or overwrite
#   size        file size for a new image (default 20G)
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Environment:
#   BOOTC_DISK_FILESYSTEM  root filesystem (default ext4)
#   BOOTC_DISK_KARGS       extra kernel arguments, space separated
#                          (default: console=ttyS0 console=tty0)
#   BOOTC_DISK_SSH_KEY     a public key file installed for root (bootc
#                          --root-ssh-authorized-keys), for testing the
#                          installed system over SSH
#
# Examples:
#   bootc-disk-image.sh quay.io/immutablue/immutablue:arch-nucleus images/disk/arch-nucleus.img
#   make BACKEND=arch-bootc NUCLEUS=1 bootc-disk-image
#
# Exit codes:
#   0 - Disk image written
#   1 - A step failed
#   2 - Usage error

set -euo pipefail

show_help() {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}

case "${1:-}" in
    -h|--help) show_help; exit 0 ;;
    --license) echo 'bootc-disk-image.sh - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac

if [[ $# -lt 2 ]]
then
    show_help >&2
    exit 2
fi

image="${1}"
output="${2}"
size="${3:-20G}"
filesystem="${BOOTC_DISK_FILESYSTEM:-ext4}"
read -ra kargs <<< "${BOOTC_DISK_KARGS:-console=ttyS0 console=tty0}"

out_dir="$(CDPATH='' cd -- "$(dirname "${output}")" 2>/dev/null && pwd || true)"
if [[ -z "${out_dir}" ]]
then
    mkdir -p "$(dirname "${output}")"
    out_dir="$(CDPATH='' cd -- "$(dirname "${output}")" && pwd)"
fi
out_name="$(basename "${output}")"

# -----------------------------------
# The install runs in root's container storage (it needs --privileged and the
# host's /dev); an image built rootless is copied across first.
# -----------------------------------
# Compared by image ID: a rebuilt image keeps its name, and installing the
# stale copy root already has would test the wrong build.
user_id="$(podman image inspect --format '{{.Id}}' "${image}" 2>/dev/null || true)"
root_id="$(sudo podman image inspect --format '{{.Id}}' "${image}" 2>/dev/null || true)"
if [[ -n "${user_id}" ]] && [[ "${user_id}" != "${root_id}" ]]
then
    echo "Copying ${image} into root's container storage"
    podman save --format oci-archive "${image}" | sudo podman load
fi

# A fresh sparse file each time: --wipe would reuse a stale layout otherwise.
rm -f "${out_dir}/${out_name}"
fallocate -l "${size}" "${out_dir}/${out_name}"

karg_flags=()
for karg in "${kargs[@]}"
do
    karg_flags+=(--karg "${karg}")
done

key_flags=()
key_mount=()
if [[ -n "${BOOTC_DISK_SSH_KEY:-}" ]]
then
    key_mount=(-v "$(realpath "${BOOTC_DISK_SSH_KEY}"):/run/root-ssh-key.pub:ro,z")
    key_flags=(--root-ssh-authorized-keys /run/root-ssh-key.pub)
fi

# SELinux hosts need the label exemption and selinuxfs for bootc to relabel;
# both are harmless elsewhere.
selinux_opts=()
if [[ -d /sys/fs/selinux ]]
then
    selinux_opts=(-v /sys/fs/selinux:/sys/fs/selinux --security-opt label=type:unconfined_t)
fi

sudo podman run --rm --privileged --pid=host \
    -v /var/lib/containers:/var/lib/containers \
    -v /dev:/dev \
    "${selinux_opts[@]}" \
    -v "${out_dir}:/data" \
    "${key_mount[@]}" \
    "${image}" \
    bootc install to-disk \
        --composefs-backend \
        --via-loopback "/data/${out_name}" \
        --filesystem "${filesystem}" \
        --wipe \
        --bootloader systemd \
        "${karg_flags[@]}" \
        "${key_flags[@]}"

# The file was written by root inside the container; hand it back.
sudo chown "$(id -u):$(id -g)" "${out_dir}/${out_name}"
echo "Wrote ${out_dir}/${out_name}"
