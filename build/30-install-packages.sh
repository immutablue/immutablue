#!/bin/bash 
# 30-install-packages.sh
#
# This script is part of the Immutablue build process and is responsible for
# installing packages into the image. It runs after the repositories have been
# added in the 20-add-repos.sh script and before packages are removed in the
# 40-uninstall-packages.sh script.
#
# The script performs the following tasks:
# 1. Install udev rules
# 2. Install akmods (if enabled)
# 3. Install NVIDIA drivers (if cyan variant)
# 4. Install packages from packages.yaml
# 5. Install the LTS kernel (if enabled)
# 6. Install ZFS (if enabled or LTS kernel)
# 7. Install pip packages
# 8. Install additional tools (hugo, fzf-git, starship)
# 9. Special handling for the build-a-blue-workshop variant

set -euxo pipefail

# Source the common functions and variables
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# Get the lists of packages to install from packages.yaml
# These functions are defined in 99-common.sh
pkgs=$(get_immutablue_packages)
pkg_urls=$(get_immutablue_package_urls)
pkg_post_urls=$(get_immutablue_package_post_urls)
pip_pkgs=$(get_immutablue_pip_packages)

# Install the uBlue udev rules for hardware support
# These provide better support for various devices
dnf5 -y install /mnt-ublue-config/ublue-os-udev-rules*.rpm 

# Install akmods support if enabled
# This is needed for certain kernel modules like NVIDIA
if [[ "$DO_INSTALL_AKMODS" == "true" ]]
then 
    # Install the akmods system for building kernel modules
    dnf5 -y install /mnt-ublue-akmods/ublue-os/ublue-os-akmods-addons*.rpm
    # Install specific kernel modules for hardware support
    dnf5 -y install /mnt-ublue-akmods/kmods/kmod-{framework,openrazer,xone}-*.rpm
fi

# Install the LTS kernel if enabled
# The LTS kernel provides better stability for systems that need it
if [[ "$DO_INSTALL_LTS" == "true" ]]
then 
    # Download the LTS kernel repository configuration
    curl -Lo "/etc/yum.repos.d/kwizart-kernel-longterm-${LTS_VERSION}-fedora-${FEDORA_VERSION}.repo" "${LTS_REPO_URL}"
    
    # Remove the standard kernel packages
    # The protect_running_kernel=false option allows removing the currently running kernel
    dnf5 -y remove --setopt protect_running_kernel=false kernel{,-core,-modules,-modules-extra}
    
    # Install the LTS kernel packages
    dnf5 -y install kernel-longterm{,-core,-modules,-modules-extra,-devel}
fi

# ZFS filesystem support
# ZFS is installed by default with the LTS kernel, or if explicitly enabled
if [[ "$DO_INSTALL_ZFS" == "true" ]] || [[ "$DO_INSTALL_LTS" == "true" ]]
then 
    # Install the ZFS repository
    dnf5 -y install "${ZFS_RPM_URL}"
    
    # Remove the FUSE-based ZFS implementation (if present)
    # This is replaced by the kernel module version
    dnf5 -y remove zfs-fuse
    
    # Install the ZFS packages
    # The zfs-dracut package ensures that ZFS support is included in the initramfs
    dnf5 -y install zfs{,-dracut}

    # Determine the ZFS version
    ZFS_VERSION=$(dkms status | grep -i zfs | awk '{ printf "%s\n", $1 }' | awk -F/ '{ printf "%s\n", $2 }')
    
    # Determine if we should look for the LTS kernel
    KERNEL_SUFFIX=""
    if [[ "$DO_INSTALL_LTS" == "true" ]]; then KERNEL_SUFFIX="longterm"; fi
    
    # Find the installed kernel version
    KERNEL_VERSION=$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//')

    # Rebuild and install the ZFS kernel module for the current kernel
    # This is necessary because we may have changed the kernel
    dkms build -m zfs -v ${ZFS_VERSION:0:-1} -k ${KERNEL_VERSION} --force
    dkms install -m zfs -v ${ZFS_VERSION:0:-1} -k ${KERNEL_VERSION} --force
    
    # Add ZFS to the list of modules to load at boot
    echo 'zfs' >> "${MODULES_CONF}"
fi

# Install RPMs from URLs
# This is for packages that need to be downloaded directly from URLs
# rather than from repositories, such as RPMFusion
if [[ "$pkg_urls" != "" ]]
then
    # Convert the list of URLs into a space-separated string for dnf
    dnf5 -y install $(for pkg in $pkg_urls; do printf '%s ' "$pkg"; done)
fi

# Install NVIDIA Drivers if this is a cyan variant
# This must be done after installing RPM URLs because it relies on RPMFusion
if [[ "$(is_option_in_build_options cyan)" == "${TRUE}" ]]
then 
    # Install NVIDIA drivers from the pre-built ublue packages
    # This includes both the ublue-os-nvidia package and the kmod-nvidia kernel module
    dnf5 -y install /mnt-ublue-akmods-nvidia/ublue-os/ublue-os-nvidia*.rpm /mnt-ublue-akmods-nvidia/kmods/kmod-nvidia-*.rpm 
fi

# Install the main packages defined in packages.yaml
if [[ "$pkgs" != "" ]]
then 
    # Convert the list of packages into a space-separated string for dnf
    dnf5 -y install $(for pkg in $pkgs; do printf '%s ' "$pkg"; done)
fi


# Install RPMs from URLs post pkgs
# This is for packages that need to be downloaded directly from URLs
# rather than from repositories, that need to be installed after the 
# regular pkags above
if [[ "$pkg_post_urls" != "" ]]
then
    # Convert the list of URLs into a space-separated string for dnf
    dnf5 -y install $(for pkg in $pkg_post_urls; do printf '%s ' "$pkg"; done)
fi


# Install Python packages via pip
# This is skipped for nucleus (headless) and build-a-blue-workshop variants
if [[ "$pip_pkgs" != "" ]] && [[ "$(is_option_in_build_options nucleus)" == "${FALSE}" ]] && [[ "$(is_option_in_build_options build_a_blue_workshop)" == "${FALSE}" ]]
then 
    # Install pip packages to the system-wide Python installation
    pip3 install --prefix=/usr "$(for pkg in $pip_pkgs; do printf '%s ' "$pkg"; done)"
fi


# Install a modern build of Hugo for the documentation site
# Fedora repositories have an older version, so we download a newer release directly
curl -Lo /tmp/hugo.tar.gz "${HUGO_RELEASE_URL}"
tar -xzf /tmp/hugo.tar.gz -C /usr/bin/ hugo
rm /tmp/hugo.tar.gz
# Verify the Hugo installation
hugo version

# Install fzf-git for improved git command-line experience
# This provides fuzzy finding for git commands
# https://github.com/junegunn/fzf-git.sh
curl -Lo /usr/bin/fzf-git "${FZF_GIT_URL}"
chmod a+x /usr/bin/fzf-git

# Install Starship prompt for a better terminal experience
# https://starship.rs/
curl -Lo "/tmp/install_starship.sh" "${STARSHIP_URL}"
sh "/tmp/install_starship.sh" -y -b "/usr/bin/"
rm "/tmp/install_starship.sh"

# Special installation for the build-a-blue-workshop variant
# This installs n8n, a workflow automation tool
if [[ "$(is_option_in_build_options build_a_blue_workshop)" == "${TRUE}" ]]
then
    # The /root directory is a symlink in the container, but npm needs it to be a real directory
    # So we need to temporarily replace the symlink with a real directory
    
    # Remove the symlink
    unlink /root
    # Create a real directory
    mkdir -p /root
    # Create the directory for n8n installation
    mkdir -p /usr/libexec/immutablue/node
    # Install n8n
    npm install --global --prefix /usr/libexec/immutablue/node n8n
    # Create a symlink to make n8n accessible in the PATH
    ln -s /usr/libexec/immutablue/node/bin/n8n /usr/bin/n8n
    # Clean up: remove the temporary directory
    rm -rf /root 
    # Restore the original symlink
    ln -s var/roothome /root
fi


