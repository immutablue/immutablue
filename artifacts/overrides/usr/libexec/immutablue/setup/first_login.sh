#!/bin/bash 
set -euxo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

# Enhanced first-login script for Immutablue
# This script is executed during the first user login

# Don't run for system users (UID < 1000) - this prevents running during
# gnome-initial-setup which runs as the gdm user
if [[ "$UID" -lt 1000 ]]; then
    echo "Skipping first-login for system user (UID=$UID)"
    exit 0
fi

# Check if the first-login script should run based on settings
if [[ "$(immutablue-settings .immutablue.run_first_login_script)" != "true" ]]
then 
    echo ".immutablue.run-first-login-script is not set to \"true\" -- bailing"
    exit 0
fi

# Flag to track if setup was completed
SETUP_COMPLETED=false

# Check if the enhanced setup has already been completed
if [[ -f /etc/immutablue/setup/did_first_boot_setup ]]; then
    echo "Enhanced setup already completed. Skipping."
    SETUP_COMPLETED=true
fi

# If we haven't run the graphical installer yet, run it now
if [[ ! -f /etc/immutablue/setup/did_first_boot_graphical ]]
then 
    # Run the first_boot_graphical script
    bash < /usr/libexec/immutablue/setup/first_boot_graphical.sh
    status_code=$?
    if [[ $status_code -ne 0 ]]
    then 
        exit $status_code
    fi
fi

# If we're not a nucleus build (has GUI) and setup isn't complete, run the GUI setup
if [[ "$(immutablue_build_is_nucleus)" == "${FALSE}" ]] && [[ "${SETUP_COMPLETED}" == "false" ]]; then
    # For graphical systems, run the GUI setup as the current user
    
    # Check if we have a display server running
    if [[ -n "${DISPLAY:-}" ]]; then
        # Check if the GUI script exists
        if [[ -f /usr/libexec/immutablue/setup/immutablue_setup_gui.py ]]; then
            echo "Running GUI setup for graphical build"

            # Run the GUI setup
            # It will create the flag file when completed
            # TODO: This is incomplete so we can set it up later. for now just 
            # create the file that we did first setup
            # /usr/libexec/immutablue/setup/immutablue_setup_gui.py --no-reboot
            sudo touch /etc/immutablue/setup/did_first_boot_setup
            # Check if the setup completed successfully
            if [[ -f /etc/immutablue/setup/did_first_boot_setup ]]; then
                echo "GUI setup completed successfully"
                SETUP_COMPLETED=true
            else
                echo "GUI setup did not complete - will try again on next login"
            fi
        else
            echo "GUI setup script not found - falling back to graphical installer"
        fi
    else
        echo "No display server found - skipping GUI setup"
    fi
fi

# Create first login flag file in user's home directory
mkdir -p "${HOME}/.config"
touch "${HOME}/.config/.immutablue_did_first_login"

# Process settings from setup if completed
if [[ "${SETUP_COMPLETED}" == "true" ]]; then
    echo "Applying setup selections"
    
    # Check if we need to install distroboxes based on settings
    INSTALL_DISTROBOX=$(immutablue-settings .immutablue.setup.install_distrobox || echo "false")
    if [[ "${INSTALL_DISTROBOX}" == "true" ]]; then
        echo "Initiating distrobox installation based on setup selections"
        # The actual installation is handled by the 'immutablue install' command
    fi
    
    # Check if we need to install flatpaks based on settings
    INSTALL_FLATPAKS=$(immutablue-settings .immutablue.setup.install_flatpaks || echo "false")
    if [[ "${INSTALL_FLATPAKS}" == "true" ]]; then
        echo "Initiating Flatpak installation based on setup selections"
        # The actual installation is handled by the 'immutablue install' command
    fi
    
    # Run the immutablue install command to apply settings
    immutablue install
fi

exit 0
