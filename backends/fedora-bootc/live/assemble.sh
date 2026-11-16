#!/bin/bash
# assemble.sh - Assemble the fedora-bootc live ISO (runs in the live image)
#
# Run by make-live-iso.sh inside a container of the live image (built from
# live/Containerfile), with that image's root filesystem as a tar stream on
# stdin and the work directory at /out. Uses the live image's own kernel,
# dracut, shim and GRUB, so the ISO boots what it installs and boots under
# Secure Boot with Fedora's signed shim, GRUB and kernel:
#
#   /out/iso/LiveOS/squashfs.img     the live root
#   /out/iso/images/pxeboot/         kernel and live initramfs
#   /out/iso/EFI/BOOT/               shim, CD GRUB, grub.cfg (also in efiboot.img)
#   /out/iso/boot/grub2/             BIOS GRUB modules and grub.cfg (x86_64)
#   /out/iso/images/eltorito.img     BIOS El Torito GRUB image (x86_64)
#   /out/efiboot.img                 FAT ESP, appended to the ISO as a partition
#   /out/boot_hybrid.img             MBR boot code for BIOS USB boot (x86_64)
#
# Usage:
#   podman export <cid> | podman run -i ... <live-image> bash assemble.sh <label> <title> [autoinstall-kargs]
#
#   autoinstall-kargs: immutablue.autoinstall=... (and _layout=, _passphrase=)
#   for an unattended test install; empty for an interactive ISO
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Exit codes:
#   0 - Assembled
#   1 - A step failed

set -euo pipefail

case "${1:-}" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --license) echo 'assemble.sh - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac

if [[ $# -lt 2 ]]
then
    echo 'assemble.sh requires 2 positional arguments' >&2
    echo 'assemble.sh <label> <title> [autoinstall-kargs]' >&2
    exit 1
fi

label="$1"
title="$2"
autoinstall="${3:-}"
kver="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -V | tail -n 1)"
arch="$(uname -m)"

# SELinux stays permissive in the live session: the squashfs is built from a
# tar stream and carries no labels. The installed system is labelled by
# ostree and enforces as usual.
cmdline="root=live:CDLABEL=${label} rd.live.image rd.live.overlay.overlayfs=1 enforcing=0"
if [[ -n "${autoinstall}" ]]
then
    cmdline="${cmdline} ${autoinstall} systemd.unit=multi-user.target systemd.wants=immutablue-live-autoinstall.service console=tty0 console=ttyS0"
else
    cmdline="${cmdline} quiet rhgb"
fi


# -----------------------------------
# The live root
# -----------------------------------
mkdir -p /out/iso/LiveOS /out/iso/images/pxeboot
mksquashfs - /out/iso/LiveOS/squashfs.img -tar -comp zstd -Xcompression-level 15 \
    -noappend -quiet -no-progress


# -----------------------------------
# The live initramfs: generic, with dmsquash-live, without the ostree hook an
# installed system boots through, and without ZFS: on a ZFS image the zfs
# module imports every pool it finds, under the hostid of the machine that
# built the image, and never exports it -- so booting the ISO on a machine
# with ZFS pools (or once more after installing onto one) leaves them "in
# use from another system" and that machine's own initramfs refuses to
# import them. The installer loads ZFS itself. The image's /var is empty --
# bootc populates it at install -- so dracut gets /tmp for its scratch space.
# -----------------------------------
cp "/usr/lib/modules/${kver}/vmlinuz" /out/iso/images/pxeboot/vmlinuz
if ! DRACUT_NO_XATTR=1 dracut --no-hostonly --force --reproducible --tmpdir /tmp \
    --kver "${kver}" --add "dmsquash-live dmsquash-live-autooverlay" \
    --omit "ostree bootc plymouth zfs" \
    /out/iso/images/pxeboot/initrd.img > /tmp/dracut.log 2>&1
then
    cat /tmp/dracut.log >&2
    exit 1
fi
if lsinitrd -m /out/iso/images/pxeboot/initrd.img 2> /dev/null | grep -qx zfs
then
    echo "assemble.sh: the live initramfs still contains the zfs module" >&2
    exit 1
fi


# -----------------------------------
# GRUB menu, shared by UEFI and BIOS. The search sets root to the ISO
# whichever device GRUB started from (the El Torito image, the appended ESP).
# -----------------------------------
grub_cfg="/out/grub.cfg"
cat > "${grub_cfg}" <<EOF
set default=0
set timeout=5
search --no-floppy --set=root -l '${label}'

menuentry 'Start ${title}' --class fedora --class gnu-linux --class os {
    linux /images/pxeboot/vmlinuz ${cmdline}
    initrd /images/pxeboot/initrd.img
}
menuentry 'Start ${title} (basic graphics)' --class fedora --class gnu-linux --class os {
    linux /images/pxeboot/vmlinuz ${cmdline} nomodeset
    initrd /images/pxeboot/initrd.img
}
EOF


# -----------------------------------
# UEFI: shim as the removable-media loader, chaining the El Torito build of
# GRUB (gcdx64.efi) under the name shim looks for, plus MokManager.
# -----------------------------------
case "${arch}" in
    x86_64)  efi_arch="x64";  efi_upper="X64" ;;
    aarch64) efi_arch="aa64"; efi_upper="AA64" ;;
    *) echo "assemble.sh: unsupported architecture ${arch}" >&2; exit 1 ;;
esac
find_efi () {
    find /usr/lib/efi /boot/efi -name "$1" -print -quit 2> /dev/null
}
shim="$(find_efi "shim${efi_arch}.efi")"
gcd="$(find_efi "gcd${efi_arch}.efi")"
mm="$(find_efi "mm${efi_arch}.efi")"
if [[ -z "${shim}" ]] || [[ -z "${gcd}" ]]
then
    echo "assemble.sh: shim${efi_arch}.efi or gcd${efi_arch}.efi missing (shim-${efi_arch}, grub2-efi-${efi_arch}-cdboot)" >&2
    exit 1
fi
mkdir -p /out/iso/EFI/BOOT
cp "${shim}" "/out/iso/EFI/BOOT/BOOT${efi_upper}.EFI"
cp "${gcd}" "/out/iso/EFI/BOOT/grub${efi_arch}.efi"
if [[ -n "${mm}" ]]
then
    cp "${mm}" "/out/iso/EFI/BOOT/mm${efi_arch}.efi"
fi
cp "${grub_cfg}" /out/iso/EFI/BOOT/grub.cfg

size_kib=$(( $(du -sk /out/iso/EFI | cut -f1) + 4096 ))
rm -f /out/efiboot.img
mkfs.fat -C -n ESP /out/efiboot.img "${size_kib}" > /dev/null
mcopy -s -i /out/efiboot.img /out/iso/EFI ::/


# -----------------------------------
# BIOS (x86_64): GRUB as an El Torito no-emulation image, and the hybrid MBR
# boot code so a USB stick written with dd boots too.
# -----------------------------------
if [[ "${arch}" == "x86_64" ]] && [[ -d /usr/lib/grub/i386-pc ]]
then
    mkdir -p /out/iso/boot/grub2
    cp -a /usr/lib/grub/i386-pc /out/iso/boot/grub2/
    cp "${grub_cfg}" /out/iso/boot/grub2/grub.cfg
    grub2-mkimage -O i386-pc-eltorito -d /usr/lib/grub/i386-pc \
        -o /out/iso/images/eltorito.img -p /boot/grub2 \
        iso9660 biosdisk search search_label normal linux configfile echo
    cp /usr/lib/grub/i386-pc/boot_hybrid.img /out/boot_hybrid.img
fi

rm -f "${grub_cfg}"
