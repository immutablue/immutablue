#!/usr/local/bin/bash
# installer.sh - The Immutablue FreeBSD installer on the live ISO
#
# Started from /etc/rc.local on the ISO built by make-iso.sh. A bsddialog
# text installer: choose one or more disks, how ZFS lays them out (stripe,
# mirror, raidz1/2/3 -- only what the chosen number of disks allows),
# whether to encrypt them (GELI; one passphrase, asked by the loader at
# boot), swap and hostname, then confirm on a summary before anything is
# erased. It runs install-disk.sh with the live root (which is the image) as
# the source. The first user is created later by GNOME's first-login setup
# on desktop images.
#
# Unattended: when the loader variable immutablue.autoinstall names disks
# (space-separated; set in /boot/loader.conf.local by 'make-iso.sh
# --autoinstall', or at the loader prompt), they are installed without
# questions and the machine powers off. immutablue.autoinstall_layout,
# immutablue.autoinstall_swap and immutablue.autoinstall_passphrase (which
# turns encryption on) choose the rest. That mode exists for automated
# testing: a passphrase in loader.conf is readable by anyone with the ISO.
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
PASSFILE=""

case "${1:-}" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --license) echo 'installer.sh - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac


# The passphrase file lives on the live system's RAM disk; never leave it.
cleanup() {
    if [[ -n "${PASSFILE}" ]]
    then
        rm -f "${PASSFILE}"
    fi
}
trap cleanup EXIT


# bsddialog writes its answer to stderr; swap it onto stdout.
#
# param $@: bsddialog arguments
# returns: bsddialog's exit status (0 OK, 1 Cancel, ...)
dlg() {
    bsddialog --title "${TITLE}" "$@" 3>&1 1>&2 2>&3
}


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


# "<size> <model>" for the disk menus.
#
# param $1: disk
describe_disk() {
    local disk="$1"
    local size
    local model

    size="$(diskinfo "${disk}" 2>/dev/null | awk '{ printf "%.0fG", $3 / 1073741824 }')"
    model="$(geom disk list "${disk}" 2>/dev/null | awk -F': ' '/descr/ { print $2; exit }')"
    echo "${size} ${model:-disk}"
}


# Run install-disk.sh, logging to LOG.
#
# param $1: layout
# param $2: swap size ("" or "0" for none)
# param $3: hostname
# param $4: passphrase file ("" for no encryption)
# param $5...: disks
run_install() {
    local layout="$1"
    local swap="$2"
    local hostname="$3"
    local passfile="$4"
    local opts=()
    shift 4

    opts=(--yes --source-root / --hostname "${hostname}" --layout "${layout}")
    if [[ -n "${swap}" ]] && [[ "${swap}" != "0" ]]
    then
        opts+=(--swap "${swap}")
    fi
    if [[ -n "${passfile}" ]]
    then
        opts+=(--encrypt --passphrase-file "${passfile}")
    fi
    bash "${INSTALL_DISK_SH}" "${opts[@]}" "$@" > "${LOG}" 2>&1
}


# Write a passphrase to a fresh mode-0600 file on the RAM disk.
#
# param $1: passphrase
new_passfile() {
    PASSFILE="$(mktemp /tmp/immutablue-pass.XXXXXX)"
    chmod 0600 "${PASSFILE}"
    printf '%s' "$1" > "${PASSFILE}"
}


unattended() {
    local disks=()
    local layout
    local swap
    local pass

    read -r -a disks <<< "$1"
    layout="$(kenv -q immutablue.autoinstall_layout 2>/dev/null || true)"
    swap="$(kenv -q immutablue.autoinstall_swap 2>/dev/null || true)"
    pass="$(kenv -q immutablue.autoinstall_passphrase 2>/dev/null || true)"
    if [[ -z "${layout}" ]]
    then
        if [[ ${#disks[@]} -gt 1 ]]
        then
            layout="mirror"
        else
            layout="stripe"
        fi
    fi
    if [[ -n "${pass}" ]]
    then
        new_passfile "${pass}"
    fi

    echo "${TITLE}: unattended install to ${disks[*]} (${layout}${pass:+, encrypted}${swap:+, swap ${swap}})"
    if run_install "${layout}" "${swap}" "immutablue" "${PASSFILE}" "${disks[@]}"
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


# The layouts n disks allow, as bsddialog menu items.
#
# param $1: number of disks
layout_items() {
    local n="$1"

    if [[ ${n} -eq 1 ]]
    then
        echo "stripe" "Single disk"
        return
    fi
    echo "mirror" "Mirror: every disk holds a full copy (survives $((n - 1)) failed disk(s))"
    echo "raidz1" "RAID-Z1: one disk of parity (survives 1 failed disk)"
    if [[ ${n} -ge 3 ]]
    then
        echo "raidz2" "RAID-Z2: two disks of parity (survives 2 failed disks)"
    fi
    if [[ ${n} -ge 4 ]]
    then
        echo "raidz3" "RAID-Z3: three disks of parity (survives 3 failed disks)"
    fi
    echo "stripe" "Stripe: all space, no redundancy (any failed disk loses the pool)"
}


# Ask for the passphrase twice until both match and it is not empty.
#
# returns: 0 with the passphrase in PASS_ANSWER, 1 when cancelled
ask_passphrase() {
    local p1
    local p2

    while true
    do
        p1="$(dlg --insecure --passwordbox "Disk encryption passphrase.\n\nThe boot loader asks for it at every boot (US keyboard layout). There is no way back in without it." 12 64)" || return 1
        p2="$(dlg --insecure --passwordbox "Repeat the passphrase." 8 64)" || return 1
        if [[ -z "${p1}" ]]
        then
            dlg --msgbox "The passphrase cannot be empty." 6 50
        elif [[ "${p1}" != "${p2}" ]]
        then
            dlg --msgbox "The passphrases do not match." 6 50
        else
            PASS_ANSWER="${p1}"
            return 0
        fi
    done
}


interactive() {
    local items=()
    local disks=()
    local d
    local answer
    local layout
    local lay_items=()
    local encrypt="no"
    local swap
    local hostname
    local summary

    # -----------------------------------
    # Disks
    # -----------------------------------
    for d in $(list_disks)
    do
        items+=("${d}" "$(describe_disk "${d}")" "off")
    done
    if [[ ${#items[@]} -eq 0 ]]
    then
        dlg --msgbox "No disk to install to was found." 6 50
        return 1
    fi
    while true
    do
        answer="$(dlg --checklist "Install Immutablue to which disk(s)? Space selects, Enter continues. Everything on them will be erased." 0 0 0 "${items[@]}")" || return 0
        read -r -a disks <<< "${answer//\"/}"
        if [[ ${#disks[@]} -gt 0 ]]
        then
            break
        fi
        dlg --msgbox "Select at least one disk (Space)." 6 50
    done

    # -----------------------------------
    # Layout
    # -----------------------------------
    mapfile -t lay_items < <(layout_items "${#disks[@]}" | while read -r key desc; do printf '%s\n%s\n' "${key}" "${desc}"; done)
    if [[ ${#disks[@]} -eq 1 ]]
    then
        layout="stripe"
    else
        layout="$(dlg --default-item mirror --menu "How should ZFS use the ${#disks[@]} disks?" 0 0 0 "${lay_items[@]}")" || return 0
    fi

    # -----------------------------------
    # Encryption, swap, hostname
    # -----------------------------------
    if dlg --defaultno --yesno "Encrypt the disk(s)?\n\nGELI full-disk encryption: the boot loader asks for a passphrase at every boot. Updates and rollbacks work as without it." 10 64
    then
        ask_passphrase || return 0
        encrypt="yes"
    fi
    swap="$(dlg --inputbox "Swap on each disk (e.g. 2g, 512m; 0 for none).$([[ ${encrypt} == yes ]] && printf '%s' '\n\nIt is encrypted with a new random key at every boot.')" 0 0 "2g")" || return 0
    if [[ ! "${swap}" =~ ^[0-9]+[kKmMgGtT]?$ ]]
    then
        dlg --msgbox "Not a size: ${swap}" 6 50
        return 0
    fi
    hostname="$(dlg --inputbox "Hostname" 0 0 "immutablue")" || return 0

    # -----------------------------------
    # Summary, then go
    # -----------------------------------
    summary="Disks:       ${disks[*]}\nLayout:      ${layout}\nEncryption:  ${encrypt}\nSwap/disk:   ${swap}\nHostname:    ${hostname}\n\nEVERYTHING on ${disks[*]} will be erased. Continue?"
    dlg --defaultno --yes-label "Install" --no-label "Cancel" --yesno "${summary}" 14 64 || return 0

    if [[ "${encrypt}" == "yes" ]]
    then
        new_passfile "${PASS_ANSWER}"
        PASS_ANSWER=""
    fi
    bsddialog --title "${TITLE}" --infobox "Installing to ${disks[*]}. This takes a few minutes..." 5 64
    if run_install "${layout}" "${swap}" "${hostname}" "${PASSFILE}" "${disks[@]}"
    then
        cleanup
        PASSFILE=""
        dlg --msgbox "Installed. Remove the installation medium; the machine will reboot.$([[ ${encrypt} == yes ]] && printf '%s' '\n\nThe loader asks for the disk passphrase at boot.') On first boot GNOME asks you to create your user." 10 64
        reboot
    else
        cleanup
        PASSFILE=""
        dlg --textbox "${LOG}" 0 0
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
        choice="$(dlg --menu "Installer finished or cancelled." 0 0 0 \
            install "Run the installer again" shell "Open a shell" reboot "Reboot")" || choice=shell
    else
        choice="$(dlg --menu "The installation failed (log: ${LOG})." 0 0 0 \
            install "Try again" shell "Open a shell" reboot "Reboot")" || choice=shell
    fi
    case "${choice}" in
        install) continue ;;
        reboot) reboot ;;
        *) exit 0 ;;
    esac
done
