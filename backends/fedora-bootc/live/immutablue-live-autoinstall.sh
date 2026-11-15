#!/bin/bash
# immutablue-live-autoinstall - Unattended install from the Immutablue live ISO
#
# Runs on the live system (immutablue-live-autoinstall.service) when the
# kernel command line carries immutablue.autoinstall=<disk>. Wipes <disk>,
# installs the image on the ISO with Anaconda in command-line mode -- the
# same kickstart defaults the interactive installer uses -- and powers off.
# For automated tests: there are no questions and no first user (GNOME's
# first-login setup creates one).
#
# Usage:
#   immutablue-live-autoinstall
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Examples:
#   Boot the ISO with: immutablue.autoinstall=/dev/vda systemd.wants=immutablue-live-autoinstall.service
#
# Exit codes:
#   0 - Installed (the machine is powering off)
#   1 - The installation failed

set -euo pipefail

KS="/run/immutablue-autoinstall.ks"

case "${1:-}" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --license) echo 'immutablue-live-autoinstall - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac


# Value of a kernel argument, empty when absent.
#
# param $1: argument name
karg () {
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


main () {
    local disk

    disk="$(karg immutablue.autoinstall)"
    if [[ -z "${disk}" ]] || [[ ! -b "${disk}" ]]
    then
        echo "immutablue-live-autoinstall: '${disk}' is not a block device" >&2
        return 1
    fi

    # The interactive defaults (image source, %pre/%post sections) plus the
    # answers the installer's screens would otherwise ask for. A text-mode
    # install defaults the new system to multi-user.target; xconfig
    # --startxonboot keeps graphical.target, as the GUI installer would.
    cat > "${KS}" <<EOF
%include /usr/share/anaconda/interactive-defaults.ks
cmdline
lang en_US.UTF-8
keyboard us
timezone UTC --utc
ignoredisk --only-use=${disk#/dev/}
clearpart --all --initlabel --disklabel=gpt --drives=${disk#/dev/}
autopart --type=btrfs --noswap
rootpw --lock
xconfig --startxonboot
poweroff
EOF

    echo "immutablue-live-autoinstall: installing to ${disk}"
    if ! anaconda --cmdline --kickstart "${KS}"
    then
        echo "immutablue-live-autoinstall: anaconda failed; /tmp/anaconda.log follows" >&2
        tail -n 100 /tmp/anaconda.log >&2 || true
        return 1
    fi
}


main "$@"
