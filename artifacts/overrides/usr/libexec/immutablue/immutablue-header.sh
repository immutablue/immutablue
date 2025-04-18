#!/bin/bash 
# The purpose of this file is to not be ran directly
# rather to be sourced in other files. It provides 
# useful functions that can be used elsewhere.
#
# To Use:
# source /usr/libexec/immutablue/immutablue-header.sh
#
# This is the central utility script that provides common functionality
# for all Immutablue scripts. It includes functions to:
# - Query information about the current Immutablue image
# - Check if certain build options were enabled
# - Check for internet connectivity
# - Interact with system services
# - Find appropriate terminal commands
# - Retry operations that might fail due to timing issues

# C style defs for boolean returns
# Using these constants makes the code more readable and consistent
TRUE=1
FALSE=0


# Extract the full image name from the current deployment
# Format example: quay.io/immutablue/immutablue:41-lts
# returns: immutablue:41-lts
immutablue_get_image_full() {
    # Check if we're running during the build process or on an installed system
    # If IMMUTABLUE_BUILD is set, we're in the build process (see Containerfile)
    if [[ -z "${IMMUTABLUE_BUILD}" ]]
    then 
        # We're on an installed system, extract the image from rpm-ostree status
        rpm-ostree status | grep -i quay | head -n 1 | awk -F/ '{ printf "%s\n", $3 }'
    else
        # We're in the build process, use the IMAGE_TAG environment variable
        echo "${IMAGE_TAG}"
    fi
}

# Extract just the tag portion of the image
# Format example: quay.io/immutablue/immutablue:41-lts
# returns: 41-lts
immutablue_get_image_tag() {
    # Use awk to split the output of immutablue_get_image_full on the colon and take the second part
    immutablue_get_image_full | awk -F: '{printf "%s\n", $2 }'
}

# Extract just the base image name (without tag)
# Format example: quay.io/immutablue/immutablue:41-lts
# returns: immutablue
immutablue_get_image_base() {
    # Use awk to split the output of immutablue_get_image_full on the colon and take the first part
    immutablue_get_image_full | awk -F: '{printf "%s\n", $1 }'
}


# Parse and output all build options from the build_options file
# This provides a list of all the options that were enabled during the build
# Used to determine what features are available in the current image
get_immutablue_build_options() {
    # Read the build options from the file, splitting on commas
    IFS=',' read -ra entry_array < "/usr/immutablue/build_options"
    # Output each option on a separate line
    for entry in "${entry_array[@]}"
    do
        echo -e "${entry}"
    done 
}

# Check if a specific build option was enabled during the build
# param $1: The option to check for (e.g., "gui", "nucleus", "cyan")
# returns: TRUE if the option was enabled, FALSE otherwise
immutablue_is_option_in_build_options() {
    local option="$1"
    # Read the build options from the file, splitting on commas
    IFS=',' read -ra entry_array < "/usr/immutablue/build_options"
    # Check each option to see if it matches the requested option
    for entry in "${entry_array[@]}"
    do
        if [[ "${option}" == "${entry}" ]]
        then 
            # Option found, return TRUE
            echo "${TRUE}"
            return 0
        fi
    done 
    # Option not found, return FALSE
    echo "${FALSE}"
}

immutablue_build_is_gui() {
    immutablue_is_option_in_build_options gui
}

immutablue_build_is_silverblue() {
    immutablue_is_option_in_build_options silverblue
}

immutablue_build_is_kinoite() {
    immutablue_is_option_in_build_options kionite
}

immutablue_build_is_vauxite() {
    immutablue_is_option_in_build_options vauxite
}

immutablue_build_is_lazurite() {
    immutablue_is_option_in_build_options lazurite
}

immutablue_build_is_nucleus() {
    immutablue_is_option_in_build_options nucleus
}

immutablue_build_is_kuberblue() {
    immutablue_is_option_in_build_options kuberblue
}

immutablue_build_is_trueblue() {
    immutablue_is_option_in_build_options trueblue
}

immutablue_build_is_lts() {
    immutablue_is_option_in_build_options lts
}

immutablue_build_is_zfs() {
    immutablue_is_option_in_build_options zfs
}

immutablue_build_is_cyan() {
    immutablue_is_option_in_build_options cyan
}

immutablue_build_is_asahi() {
    immutablue_is_option_in_build_options asahi
}


# takes two args:
# arg1: regex of package 
# arg2: exclude package regex (if not needed pass "null")
immutablue_build_has_package() {
    local pkg_search="$1"
    local pkg_exclude="$2"
    pkg=$(rpm -qa | grep -P "${pkg_search}" | grep -vP "${pkg_exclude}")
    if [[ "$pkg" != "" ]]
    then 
        echo ${TRUE}
    else
        echo ${FALSE}
    fi
}

immutablue_build_has_zfs() {
    immutablue_build_has_package "^zfs" "zfs-fuse"
}

immutablue_build_has_gnome() {
    immutablue_build_has_package "^gnome-session-\d{1,3}" "null"
}

immutablue_build_has_working_tailscale() {
    type tailscale &>/dev/null
    if [[ $? -eq 0 ]]
    then 
        if [[ "$(tailscale status --json | jq .BackendState)" == "\"Running\"" ]]
        then
            if [[ "$(tailscale ip -4)" =~ ^100\. ]]
            then
                echo $TRUE
            fi
        fi
    else
        echo $FALSE
    fi
}

# Check if the system has IPv4 internet connectivity
# This tests connectivity by pinging a configured IPv4 host
# returns: TRUE if connected, FALSE otherwise
immutablue_has_internet_v4() {
    # Check if internet check is overridden in settings
    # This is useful for testing or development environments
    if [[ "$(immutablue-settings .immutablue.header.force_always_has_internet_v4)" == "true" ]]
    then 
        echo "${TRUE}"
        return 0
    fi
    
    # Get the configured test host from settings
    local test_host=$(immutablue-settings .immutablue.header.has_internet_host_v4)
    
    # Ping the test host with a short timeout
    # Redirect output to avoid clutter
    ping -c1 -W2 "${test_host}" >/dev/null 2>/dev/null
    
    # Check the result of the ping command
    if [[ $? -eq 0 ]]
    then
        # Ping successful, we have IPv4 connectivity
        echo $TRUE 
    else
        # Ping failed, no IPv4 connectivity
        echo $FALSE
    fi
}

# Check if the system has IPv6 internet connectivity
# This tests connectivity by pinging a configured IPv6 host
# returns: TRUE if connected, FALSE otherwise
immutablue_has_internet_v6() {
    # Check if internet check is overridden in settings
    if [[ "$(immutablue-settings .immutablue.header.force_always_has_internet_v6)" == "true" ]]
    then 
        echo "${TRUE}"
        return 0
    fi

    # Get the configured IPv6 test host from settings
    local test_host=$(immutablue-settings .immutablue.header.has_internet_host_v6)
    
    # Ping the IPv6 test host with a short timeout
    ping -c1 -W2 "${test_host}" >/dev/null 2>/dev/null
    
    # Check the result of the ping command
    if [[ $? -eq 0 ]]
    then
        # Ping successful, we have IPv6 connectivity
        echo $TRUE 
    else
        # Ping failed, no IPv6 connectivity
        echo $FALSE
    fi
}

# Check if the system has internet connectivity (either IPv4 or IPv6)
# returns: TRUE if connected via either IPv4 or IPv6, FALSE otherwise
immutablue_has_internet() {
    # Check if internet check is globally overridden in settings
    if [[ "$(immutablue-settings .immutablue.header.force_always_has_internet)" == "true" ]]
    then 
        echo "${TRUE}"
        return 0
    fi

    # First check IPv4 connectivity
    if [[ "$(immutablue_has_internet_v4)" == "${FALSE}" ]]
    then
        # No IPv4 connectivity, check IPv6
        if [[ "$(immutablue_has_internet_v6)" == "${FALSE}" ]]
        then
            # Neither IPv4 nor IPv6 connectivity
            echo "${FALSE}"
        else
            # IPv6 connectivity but no IPv4
            echo "${TRUE}"
        fi
    else 
        # IPv4 connectivity
        echo "${TRUE}"
    fi
}


# Detect and return the appropriate terminal command for the current environment
# This tries multiple terminal emulators in order of preference
# returns: The command to launch a terminal, or empty string if none found
immutablue_get_terminal_command() {
    # Try kitty terminal first
    type kitty &>/dev/null
    if [[ $? -eq 0 ]] 
    then 
        echo "kitty"
        return 0
    fi

    # Try ptyxis terminal next (GNOME's newer terminal, used in GNOME >= 45)
    type ptyxis &>/dev/null
    if [[ $? -eq 0 ]] 
    then 
        # Note the -- is needed for ptyxis to pass arguments to the command
        echo "ptyxis --"
        return 0
    fi
    
    # Finally try the standard GNOME terminal
    type gnome-terminal &>/dev/null
    if [[ $? -eq 0 ]] 
    then 
        # Note the -- is needed for gnome-terminal to pass arguments to the command
        echo "gnome-terminal --"
        return 0
    fi

    # No known terminal found, return empty string
    # This would typically happen in a headless environment
    echo "" 
}


# Enable the setup services to run on the next boot
# This resets the setup flags and unmasks the setup services
# Useful when you want to re-run the setup process after making changes
immutablue_services_enable_setup_for_next_boot() {
    # Unmask the user-level first login service
    systemctl --user unmask immutablue-first-login.service
    # Unmask the system-level first boot service
    sudo systemctl unmask immutablue-first-boot.service
    # Remove the flag files that indicate setup has already run
    rm ${HOME}/.config/.immutablue_did_first_login
    # Remove both the first boot and first boot graphical flag files
    rm /etc/immutablue/setup/did_first_boot{,_graphical}
}

# Force the setup services to run immediately
# This is similar to enable_setup_for_next_boot but also starts the services right away
# Useful when you want to re-run the setup process immediately without rebooting
immutablue_services_force_setup_to_run_now() {
    # Unmask the user-level first login service
    systemctl --user unmask immutablue-first-login.service
    # Unmask the system-level first boot service
    sudo systemctl unmask immutablue-first-boot.service
    # Remove the flag files that indicate setup has already run
    rm ${HOME}/.config/.immutablue_did_first_login
    # Remove both the first boot and first boot graphical flag files
    rm /etc/immutablue/setup/did_first_boot{,_graphical}
    # Start the system-level first boot service immediately
    sudo systemctl start immutablue-first-boot.service
    # Start the user-level first login service immediately
    systemctl --user start immutablue-first-login.service
}


# Try running a command, and if it fails, wait and try again
# This is useful for commands that might fail due to timing issues
# or temporary conditions (like network connectivity)
#
# Parameters:
# arg1: delay - Number of seconds to wait before trying again
# arg2: command - The command to execute
# arg3+: args_to_command - Any additional arguments to pass to the command
#
# Returns: TRUE if the command eventually succeeds, FALSE if it fails twice
immutablue_try_command_and_try_again_on_delay() {
    # Store the delay time for retry
    local delay="$1"
    # Variables to store command output and return code
    local output=""
    local ret_code=0
    
    # Remove the delay parameter, leaving just the command and its arguments
    shift

    # Echo the command for debugging purposes
    echo "$@"
    # Execute the command and capture its output and return code
    output="$(${@})"
    ret_code=$?
    
    # Check if the command failed (either returned FALSE or a non-zero exit code)
    if [[ "${output}" == "${FALSE}" ]] || [[ $ret_code -ne 0 ]]
    then
        # Wait before trying again
        sleep ${delay}

        # Try the command again
        echo "$@"
        output="$(${@})"
        ret_code=$?

        # Check if the command failed again
        if [[ "${output}" == "${FALSE}" ]] || [[ $ret_code -ne 0 ]]
        then 
            # If it failed twice, return FALSE
            echo "${FALSE}"
            return 1
        fi
    fi
    
    # If we get here, either the first or second attempt succeeded
    echo "${TRUE}"
}
