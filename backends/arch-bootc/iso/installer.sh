#!/bin/bash
# installer.sh - The Immutablue Arch installer on the live ISO
#
# Runs on tty1 of the live system booted from the ISO that make-iso.sh
# builds (immutablue-live-installer.service). Asks for the target disk,
# confirms, and runs 'bootc install to-disk' from the OCI image layout on the
# ISO, the same install bootc-disk-image.sh does for disk images. The
# installed system tracks the image's registry reference, so 'immutablue
# update' pulls from there. The first user is created by GNOME's first-login
# setup on desktop images.
#
# Unattended: the kernel argument immutablue.autoinstall=<disk> installs to
# that disk without questions and powers off (for automated tests).
#
# Usage:
#   installer.sh
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Exit codes:
#   0 - Installed, or the user left for a shell
#   1 - The installation failed

set -uo pipefail

LIVE="/run/initramfs/live"
LAYOUT="${LIVE}/image"
LOG="/tmp/immutablue-install.log"

case "${1:-}" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --license) echo 'installer.sh - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac


# The registry reference the image was built as, recorded by make-iso.sh.
target_ref() {
    cat "${LIVE}/image.ref"
}


# Value of a kernel argument, empty when absent.
#
# param $1: argument name
karg() {
    local arg
    for arg in $(< /proc/cmdline)
    do
        if [[ "${arg}" == "$1="* ]]
        then
            echo "${arg#*=}"
            return 0
        fi
    done
}


run_install() {
    local disk="$1"

    {
        echo "Installing $(target_ref) to ${disk}"
        bootc install to-disk --wipe --filesystem ext4 \
            --composefs-backend \
            --bootloader systemd \
            --source-imgref "oci:${LAYOUT}" \
            --target-imgref "$(target_ref)" \
            "${disk}"
    } 2>&1 | tee "${LOG}"
    return "${PIPESTATUS[0]}"
}


# Whole disks other than the installer medium and loop/zram devices.
list_disks() {
    lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$NF == "disk" && $1 !~ /\/dev\/(sr|loop|zram)/ { $NF = ""; print }'
}


interactive() {
    local disks=()
    local line
    local choice
    local answer
    local i

    clear
    echo "Immutablue (Arch) installer -- $(target_ref)"
    echo
    mapfile -t disks < <(list_disks)
    if [[ ${#disks[@]} -eq 0 ]]
    then
        echo "No disk to install to was found."
        return 1
    fi
    for i in "${!disks[@]}"
    do
        printf '  %d) %s\n' "$((i + 1))" "${disks[${i}]}"
    done
    echo
    read -rp "Install to which disk (number, or 's' for a shell)? " choice
    if [[ "${choice}" == "s" ]]
    then
        return 2
    fi
    if ! [[ "${choice}" =~ ^[0-9]+$ ]] || [[ "${choice}" -lt 1 ]] || [[ "${choice}" -gt ${#disks[@]} ]]
    then
        return 0
    fi
    line="${disks[$((choice - 1))]}"
    read -rp "Erase ${line%% *} and install Immutablue on it? Type 'yes': " answer
    [[ "${answer}" == "yes" ]] || return 0

    if run_install "${line%% *}"
    then
        echo
        read -rp "Installed. Remove the installation medium and press Enter to reboot. " _
        systemctl reboot
    else
        echo
        echo "The installation failed; the log is ${LOG}."
        read -rp "Press Enter to continue. " _
        return 1
    fi
}


auto="$(karg immutablue.autoinstall)"
if [[ -n "${auto}" ]]
then
    if run_install "${auto}"
    then
        echo "Installed; powering off"
        systemctl poweroff
    fi
    echo "The installation FAILED; the log is ${LOG}"
    exit 1
fi

while true
do
    interactive
    if [[ $? -eq 2 ]]
    then
        echo "Run immutablue-live-installer to start the installer again."
        exec /bin/bash -l
    fi
done
