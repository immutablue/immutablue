#!/bin/bash
# immutablue-zfs-install-gui - Desktop front end for immutablue-zfs-install
#
# The "Install Immutablue on ZFS" launcher of the live ISO of a ZFS image.
# Asks, with zenity dialogs, for the disks, the pool layout and an optional
# encryption passphrase, confirms, and runs immutablue-zfs-install as root
# (sudo: livesys gives liveuser passwordless sudo), showing progress and the
# installer's log when it is done.
#
# Usage:
#   immutablue-zfs-install-gui
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Exit codes:
#   0 - Installed, or the user cancelled
#   1 - The installation failed

set -uo pipefail

# The product name shown in the dialogs; build-live.sh sets it to the ISO's
# --name (make-live-iso.sh)
PRODUCT="Immutablue"
TITLE="Install ${PRODUCT} on ZFS"
LOG="/tmp/immutablue-zfs-install.log"

case "${1:-}" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --license) echo 'immutablue-zfs-install-gui - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac


error () {
    zenity --error --title="${TITLE}" --width=420 --text="$1"
}


# The disk the live system runs from, which must not be offered
live_disk () {
    local src

    src="$(findmnt -n -o SOURCE /run/initramfs/live 2> /dev/null)"
    if [[ -n "${src}" ]]
    then
        lsblk -n -o PKNAME "${src}" 2> /dev/null | head -n 1
        basename "${src}"
    fi
}


# zenity checklist rows: FALSE /dev/x "size" "model"
disk_rows () {
    local skip
    local name
    local size
    local type
    local model

    skip="$(live_disk)"
    while read -r name size type model
    do
        [[ "${type}" == "disk" ]] || continue
        if grep -qx "${name}" <<< "${skip}"
        then
            continue
        fi
        echo "FALSE"
        echo "/dev/${name}"
        echo "${size}"
        echo "${model:--}"
    done < <(lsblk -d -n -o NAME,SIZE,TYPE,MODEL -e 1,7,11,251)
}


main () {
    local rows=()
    local disks=()
    local layouts=()
    local layout
    local encrypt=()
    local pass1
    local pass2
    local passfile=""
    local enc_label=""
    local rc

    mapfile -t rows < <(disk_rows)
    if [[ ${#rows[@]} -eq 0 ]]
    then
        error "No disks to install to were found."
        return 1
    fi

    # -----------------------------------
    # Disks
    # -----------------------------------
    IFS='|' read -r -a disks < <(zenity --list --checklist --title="${TITLE}" \
        --width=640 --height=380 \
        --text="Choose the disk(s) for the ZFS pool. <b>Everything on them is erased.</b>" \
        --column="Use" --column="Disk" --column="Size" --column="Model" \
        --separator='|' "${rows[@]}") || return 0
    [[ ${#disks[@]} -gt 0 ]] || { error "No disk was chosen."; return 0; }

    # -----------------------------------
    # Layout, limited to what the number of disks allows
    # -----------------------------------
    case ${#disks[@]} in
        1) layouts=(TRUE stripe "One disk, no redundancy") ;;
        2) layouts=(TRUE mirror "Each disk holds a full copy" FALSE stripe "Capacity of both, no redundancy") ;;
        3) layouts=(TRUE raidz1 "Survives one failed disk" FALSE mirror "Three-way copy" FALSE stripe "No redundancy" FALSE raidz2 "Survives two failed disks") ;;
        *) layouts=(TRUE raidz1 "Survives one failed disk" FALSE raidz2 "Survives two failed disks" FALSE raidz3 "Survives three failed disks" FALSE mirror "N-way copy" FALSE stripe "No redundancy") ;;
    esac
    if [[ ${#disks[@]} -eq 1 ]]
    then
        layout="stripe"
    else
        layout="$(zenity --list --radiolist --title="${TITLE}" --width=520 --height=300 \
            --text="How should the ${#disks[@]} disks form the pool?" \
            --column="" --column="Layout" --column="" "${layouts[@]}")" || return 0
    fi

    # -----------------------------------
    # Encryption
    # -----------------------------------
    if zenity --question --title="${TITLE}" --width=420 \
        --text="Encrypt the pool?\n\nThe passphrase is asked for at every boot."
    then
        while true
        do
            pass1="$(zenity --password --title="Encryption passphrase (at least 8 characters)")" || return 0
            pass2="$(zenity --password --title="Repeat the passphrase")" || return 0
            if [[ "${pass1}" != "${pass2}" ]]
            then
                error "The passphrases differ."
            elif [[ ${#pass1} -lt 8 ]]
            then
                error "The passphrase must be at least 8 characters."
            else
                break
            fi
        done
        passfile="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/zfs-pass.XXXXXX")"
        printf '%s' "${pass1}" > "${passfile}"
        unset pass1 pass2
        encrypt=(--encrypt --passphrase-file "${passfile}")
        enc_label=", encrypted"
    fi

    # -----------------------------------
    # Last chance, then install
    # -----------------------------------
    zenity --question --title="${TITLE}" --width=480 --icon=dialog-warning \
        --ok-label="Erase and install" --cancel-label="Cancel" \
        --text="<b>All data on ${disks[*]} will be erased.</b>\n\nPool: ${layout}${enc_label}" \
        || { [[ -n "${passfile}" ]] && rm -f "${passfile}"; return 0; }

    # The log belongs to liveuser, who reads it back below
    # shellcheck disable=SC2024
    sudo -n immutablue-zfs-install --yes --layout "${layout}" "${encrypt[@]}" "${disks[@]}" > "${LOG}" 2>&1 &
    local pid=$!
    zenity --progress --pulsate --no-cancel --auto-close --title="${TITLE}" --width=420 \
        --text="Installing ${PRODUCT} on ZFS. This takes a few minutes." < <(while kill -0 "${pid}" 2> /dev/null; do echo "#"; sleep 1; done)
    wait "${pid}"
    rc=$?
    [[ -n "${passfile}" ]] && rm -f "${passfile}"

    if [[ ${rc} -eq 0 ]]
    then
        zenity --info --title="${TITLE}" --width=420 \
            --text="${PRODUCT} is installed. Remove the installation media and restart."
    else
        zenity --text-info --title="${TITLE}: installation failed" --width=760 --height=480 --filename="${LOG}"
    fi
    return "${rc}"
}


main "$@"
