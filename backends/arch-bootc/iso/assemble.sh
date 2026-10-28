#!/bin/bash
# assemble.sh - Assemble the Immutablue Arch ISO tree (runs in the image)
#
# Run by make-iso.sh inside a container of the image being packaged, with
# that image's root filesystem as a tar stream on stdin and the work
# directory at /out. Uses the image's own kernel, dracut and systemd-boot,
# so the live system boots exactly what it installs:
#
#   /out/iso/LiveOS/squashfs.img   the image's root (+ the installer)
#   /out/esp.img                   FAT ESP: systemd-boot, kernel, live initrd
#
# Usage:
#   podman export <cid> | podman run -i ... <image> bash assemble.sh <label> [autoinstall-disk]
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Exit codes:
#   0 - Assembled
#   1 - A step failed

set -euo pipefail

SRC="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --license) echo 'assemble.sh - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac

label="$1"
autoinstall="${2:-}"
kver="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -V | tail -n 1)"
cmdline="root=live:CDLABEL=${label} rd.live.image rd.live.overlay.overlayfs=1 immutablue.live systemd.unit=multi-user.target systemd.wants=immutablue-live-installer.service quiet"
if [[ -n "${autoinstall}" ]]
then
    cmdline="${cmdline} immutablue.autoinstall=${autoinstall} console=ttyS0 console=tty0"
fi

pacman -Sy --noconfirm --needed squashfs-tools mtools > /dev/null

# -----------------------------------
# The live root: the image, plus the installer and its unit as pseudo files
# -----------------------------------
mkdir -p /out/iso/LiveOS
mksquashfs - /out/iso/LiveOS/squashfs.img -tar -comp zstd -noappend -quiet -no-progress \
    -p "/usr/bin/immutablue-live-installer f 755 0 0 cat ${SRC}/installer.sh" \
    -p "/usr/lib/systemd/system/immutablue-live-installer.service f 644 0 0 cat ${SRC}/immutablue-live-installer.service"

# -----------------------------------
# The live initramfs: generic, with dmsquash-live, without the ostree and
# bootc hooks an installed system boots through
# -----------------------------------
# (the image's /var is empty -- bootc populates it at install -- so dracut
# gets /tmp for its scratch space)
if ! dracut --no-hostonly --force --tmpdir /tmp --kver "${kver}" \
    --add "dmsquash-live" --omit "ostree bootc plymouth" \
    /out/initrd.img > /tmp/dracut.log 2>&1
then
    cat /tmp/dracut.log >&2
    exit 1
fi

# -----------------------------------
# The ESP, an image appended to the ISO as its EFI partition
# -----------------------------------
mkdir -p /out/esp/EFI/BOOT /out/esp/loader/entries
cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi /out/esp/EFI/BOOT/BOOTX64.EFI
cp "/usr/lib/modules/${kver}/vmlinuz" /out/esp/vmlinuz
mv /out/initrd.img /out/esp/initrd.img
printf 'default immutablue-install.conf\ntimeout 3\n' > /out/esp/loader/loader.conf
cat > /out/esp/loader/entries/immutablue-install.conf <<EOF
title   Install Immutablue
linux   /vmlinuz
initrd  /initrd.img
options ${cmdline}
EOF
size_kib=$(( $(du -sk /out/esp | cut -f1) + 16384 ))
rm -f /out/esp.img
mkfs.fat -C -n ESP /out/esp.img "${size_kib}" > /dev/null
mcopy -s -i /out/esp.img /out/esp/* ::/
rm -rf /out/esp
