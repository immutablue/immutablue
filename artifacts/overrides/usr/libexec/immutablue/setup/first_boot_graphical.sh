#!/bin/bash 
# Note, this is ran via first_login.sh as a user.
# This is done so that it provides some sort of 
# "graphical feedback" to the user that the install 
# is running (for builds that are graphical)
#
# This kicks off things such as brew, flatpaks, and 
# distrobox installs as well as post_install.sh
set -euxo pipefail
source /usr/libexec/immutablue/immutablue-header.sh
TERMINAL_CMD=$(immutablue_get_terminal_command)

MARKER_FILE="/etc/immutablue/setup/did_first_boot_graphical"

# Records that the graphical first-boot install has run.
#
# This script executes in the user's own session, not as root, so it cannot
# assume write access to /etc/immutablue/setup. That directory is root:wheel
# 0775 (it was previously world-writable, which let any local user forge or
# delete setup markers), so the plain write succeeds for an administrator and
# sudo is only needed for a user outside wheel.
#
# A marker that cannot be written is deliberately NOT fatal: the install
# itself has already succeeded at this point, and failing here under `set -e`
# would propagate a non-zero exit up through first_login.sh. The cost of a
# missing marker is that the install is offered again on the next login, which
# is a far better outcome than a login that reports failure.
mark_first_boot_graphical_done() {
    if touch "${MARKER_FILE}" 2>/dev/null
    then
        return 0
    fi

    if sudo -n touch "${MARKER_FILE}" 2>/dev/null
    then
        return 0
    fi

    echo "WARNING: could not write ${MARKER_FILE}" >&2
    echo "WARNING: graphical first-boot setup will be offered again on next login" >&2
    return 0
}

# Check if we've already run this script
if [[ -f "${MARKER_FILE}" ]]
then 
    echo "already did first boot as ${MARKER_FILE} exists"
    echo "if you really want to run this again (do you know what you are doing??)"
    echo "just remove that file."
    exit 1
fi

# Check if this script should run based on settings
if [[ "$(immutablue-settings .immutablue.run_first_boot_graphical_installer)" != "true" ]]
then 
    echo ".immutablue.run-first-boot-graphical-installer is not set to \"true\" -- bailing."
    exit 0
fi

# Check for internet connectivity - required for installations
if [[ "$(immutablue_has_internet)" == "${FALSE}" ]]
then
    # If nucleus we can't show a graphical indicator
    # If not we can show a terminal with the message
    if [[ "$(immutablue_build_is_nucleus)" == "${TRUE}" ]] || [[ "${TERMINAL_CMD}" == "" ]]
    then 
        echo "Please connect to the internet first and restart."
        exit 1
    else 
        ${TERMINAL_CMD} bash -c 'echo "Please connect to the internet and then restart to finish installation." && read -p "hit enter to continue, reboot when ready (after setting up internet)"'
        exit 1
    fi
fi

# Check if enhanced setup has already been completed
# If so, we'll skip the regular installation flow and let the enhanced setup handle it
if [[ -f /etc/immutablue/setup/did_first_boot_setup ]]; then
    echo "Enhanced setup already completed. Skipping regular installation flow."
    mark_first_boot_graphical_done
    exit 0
fi

# Check if this is a nucleus build, if so, we can't do a graphical install
# but the terminal-based installation process should still run
if [[ "$(immutablue_build_is_nucleus)" == "${TRUE}" ]] || [[ "${TERMINAL_CMD}" == "" ]]
then
    immutablue install 
else 
    # For graphical builds, show progress in a terminal window
    ${TERMINAL_CMD} bash -c 'immutablue install && echo "please reboot one last time" && read -p "hit enter to continue. reboot when ready"'
fi

echo "Please reboot one last time"
mark_first_boot_graphical_done