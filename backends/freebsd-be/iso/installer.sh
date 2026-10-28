#!/usr/local/bin/bash
# installer.sh - The Immutablue FreeBSD installer on the live ISO
#
# Started from /etc/rc.local on the ISO built by make-iso.sh. Asks for the
# target disk and a hostname, confirms, and runs install-disk.sh with the live
# root (which is the image) as the source. The first user is created later by
# GNOME's first-login setup on desktop images.
#
# Unattended: when the loader variable immutablue.autoinstall names a disk
# (set in /boot/loader.conf.local by 'make-iso.sh --autoinstall <disk>', or
# at the loader prompt), that disk is installed without questions and the
# machine powers off. That mode exists for automated testing.
#
# Usage:
#   installer.sh
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Exit codes:
#   0 - Installed (or the user chose the shell)
#   1 - The installation failed

set -uo pipefail

INSTALL_DISK_SH="/usr/immutablue/backends/freebsd-be/install-disk.sh"
LOG="/tmp/immutablue-install.log"
TITLE="Immutablue FreeBSD"

case "${1:-}" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --license) echo 'installer.sh - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac


# Every disk except the installer medium itself.
list_disks() {
    local d
    for d in $(sysctl -n kern.disks)
    do
        case "${d}" in
            cd*|md*) continue ;;
            *) ;;
        esac
        echo "${d}"
    done | sort
}


run_install() {
    local disk="$1"
    local hostname="$2"

    bash "${INSTALL_DISK_SH}" --yes --source-root / --hostname "${hostname}" "${disk}" > "${LOG}" 2>&1
}


unattended() {
    local disk="$1"

    echo "${TITLE}: unattended install to /dev/${disk}"
    if run_install "${disk}" "immutablue"
    then
        echo "${TITLE}: installed; powering off"
        cat "${LOG}"
        poweroff
    else
        echo "${TITLE}: installation FAILED"
        cat "${LOG}"
    fi
    exit 0
}


interactive() {
    local items=()
    local d
    local size
    local disk
    local hostname

    for d in $(list_disks)
    do
        size="$(diskinfo "${d}" 2>/dev/null | awk '{ printf "%.0fG", $3 / 1073741824 }')"
        items+=("${d}" "${size} $(geom disk list "${d}" 2>/dev/null | awk -F': ' '/descr/ { print $2; exit }')")
    done

    if [[ ${#items[@]} -eq 0 ]]
    then
        bsddialog --title "${TITLE}" --msgbox "No disk to install to was found." 0 0
        return 1
    fi

    disk="$(bsddialog --title "${TITLE}" --menu "Install Immutablue to which disk? Everything on it will be erased." 0 0 0 "${items[@]}" 3>&1 1>&2 2>&3)" || return 0
    hostname="$(bsddialog --title "${TITLE}" --inputbox "Hostname" 0 0 "immutablue" 3>&1 1>&2 2>&3)" || return 0
    bsddialog --title "${TITLE}" --yesno "Erase /dev/${disk} and install Immutablue on it?" 0 0 || return 0

    bsddialog --title "${TITLE}" --infobox "Installing to /dev/${disk}. This takes a few minutes..." 0 0
    if run_install "${disk}" "${hostname}"
    then
        bsddialog --title "${TITLE}" --msgbox "Installed. Remove the installation medium; the machine will reboot. On first boot GNOME asks you to create your user." 0 0
        reboot
    else
        bsddialog --title "${TITLE}" --textbox "${LOG}" 0 0
        return 1
    fi
}


auto="$(kenv -q immutablue.autoinstall 2>/dev/null || true)"
if [[ -n "${auto}" ]]
then
    unattended "${auto}"
fi

while true
do
    if interactive
    then
        choice="$(bsddialog --title "${TITLE}" --menu "Installer finished or cancelled." 0 0 0 \
            install "Run the installer again" shell "Open a shell" reboot "Reboot" 3>&1 1>&2 2>&3)" || choice=shell
    else
        choice="$(bsddialog --title "${TITLE}" --menu "The installation failed (log: ${LOG})." 0 0 0 \
            install "Try again" shell "Open a shell" reboot "Reboot" 3>&1 1>&2 2>&3)" || choice=shell
    fi
    case "${choice}" in
        install) continue ;;
        reboot) reboot ;;
        *) exit 0 ;;
    esac
done
