#!/bin/bash 
set -euxo pipefail 

# the sourcing must come after we bootstrap the above
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# Ensure TRUE/FALSE constants are defined (fallback if not sourced from immutablue-header.sh)
if [[ -z "${TRUE:-}" ]]; then
    TRUE=1
    FALSE=0
fi

# Only run this for kuberblue builds
if [[ "$(is_option_in_build_options kuberblue)" == "${FALSE}" ]]; then
    echo "Skipping kuberblue autocluster setup - not a kuberblue build"
    exit 0
fi

echo "Setting up kuberblue autocluster configuration..."

# Handle role-specific first_boot.sh logic
if [[ "$(is_option_in_build_options control_plane)" == "${TRUE}" ]]; then
    echo "Configuring for control plane role..."
    cp /usr/libexec/kuberblue/setup/first_boot_control_plane.sh /usr/libexec/kuberblue/setup/first_boot.sh
    
elif [[ "$(is_option_in_build_options worker)" == "${TRUE}" ]]; then
    echo "Configuring for worker role..."
    cp /usr/libexec/kuberblue/setup/first_boot_worker.sh /usr/libexec/kuberblue/setup/first_boot.sh
    
else
    echo "Default kuberblue build - no role-specific changes to first_boot.sh"
fi

# Make scripts executable
chmod +x /usr/libexec/kuberblue/worker_boot.sh
chmod +x /usr/libexec/kuberblue/discovery.sh
chmod +x /usr/libexec/kuberblue/create_control_plane_service.sh
chmod +x /usr/libexec/kuberblue/setup/first_boot_control_plane.sh
chmod +x /usr/libexec/kuberblue/setup/first_boot_worker.sh

# Make autocluster management scripts executable
chmod +x /usr/libexec/kuberblue/autocluster_*.sh

# Enable required services
systemctl enable kuberblue-onboot.service
systemctl enable avahi-daemon.service

echo "Kuberblue autocluster setup complete"