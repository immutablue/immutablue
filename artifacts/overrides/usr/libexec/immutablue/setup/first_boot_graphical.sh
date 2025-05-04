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

# Check if we've already run this script
if [[ -f /etc/immutablue/setup/did_first_boot_graphical ]]
then 
    echo "already did first boot as /etc/immutablue/setup/did_first_boot_graphical exists"
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
    touch /etc/immutablue/setup/did_first_boot_graphical
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
touch /etc/immutablue/setup/did_first_boot_graphical