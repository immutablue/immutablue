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

if [[ -f /etc/immutablue/setup/did_first_boot_graphical ]]
then 
    echo "already did first boot as /etc/immutablue/setup/did_first_boot exists"
    echo "if you really want to run this again (do you know what you are doing??)"
    echo "just remove that file."
    exit 1
fi

if [[ "$(immutablue_has_internet)" == "${FALSE}" ]]
then
    # If nuclues we can't show a graphical indicator
    # If not we can show a terminal with the message
    if [[ "$(immutablue_build_is_nucleus)" == "${TRUE}" ]] || [[ "${TERMINAL_CMD}" == "" ]]
    then 
        echo "Please connect to the internet first and restart."
        exit 1
    else 
        ${TERMINAL_CMD} bash -c 'echo "Please connect to the internet and then restart to finish installation." && read -p "hit inter to continure, reboot when ready (after setting up internet)"'
        exit 1
    fi
fi


# Check if this is a nucleus build, if so, this can't be done in a graphical install
if [[ "$(immutablue_build_is_nucleus)" == "${TRUE}" ]] || [[ "${TERMINAL_CMD}" == "" ]]
then
    immutablue install 
else 
    ${TERMINAL_CMD} bash -c 'immutablue install && echo "please reboot one last time" && read -p "hit enter to continue. reboot when ready"'
fi

echo "Please reboot one last time"
touch /etc/immutablue/setup/did_first_boot_graphical

