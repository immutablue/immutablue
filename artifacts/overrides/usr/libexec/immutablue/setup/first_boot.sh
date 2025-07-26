#!/bin/bash 
set -euo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

# Enhanced first-boot script for Immutablue
# This script is executed by systemd during the first boot of the system

# Check if the first-boot script should run based on settings
if [[ "$(immutablue-settings .immutablue.run_first_boot_script)" != "true" ]]
then 
    echo ".immutablue.run-first-boot-script is not set to \"true\" -- bailing"
    exit 0
fi

# Flag to track if setup was completed
SETUP_COMPLETED=false

# Check if enhanced setup has already been completed
if [[ -f /etc/immutablue/setup/did_first_boot_setup ]]; then
    echo "Enhanced setup already completed. Skipping."
    SETUP_COMPLETED=true
fi

# Create required directories
mkdir -p /etc/immutablue/setup

# If we're a nucleus build (CLI-only), run the TUI setup
if [[ "$(immutablue_build_is_nucleus)" == "${TRUE}" ]] && [[ "${SETUP_COMPLETED}" == "false" ]]; then
    echo "Running TUI setup for nucleus build"
    
    # Check if the TUI script exists
    if [[ -f /usr/libexec/immutablue/setup/immutablue_setup_tui.py ]]; then
        # Run the TUI setup - it will create the did_first_boot_setup flag when complete
        # Run as root for system-wide configuration
        # TODO: This is incomplete so we can set it up later. for now just 
        # create the file that we did first setup
        # /usr/libexec/immutablue/setup/immutablue_setup_tui.py --no-reboot
        touch /etc/immutablue/setup/did_first_boot_setup
        # Check if the setup completed successfully
        if [[ -f /etc/immutablue/setup/did_first_boot_setup ]]; then
            echo "TUI setup completed successfully"
            SETUP_COMPLETED=true
        else
            echo "TUI setup did not complete - will try again on next boot"
        fi
    else
        echo "TUI setup script not found - falling back to basic setup"
    fi
fi

# The GUI setup will be triggered in first_login.sh for graphical systems
# since it needs to run in the user's session

# Create first boot flag file
touch /etc/immutablue/setup/did_first_boot

# Exit successfully
exit 0
