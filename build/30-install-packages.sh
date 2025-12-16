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

# kernel override to fix issue introduced in:
# - 6.12.60
# - 6.17.10
# https://github.com/torvalds/linux/commit/cfa0904a35fd0231f4d05da0190f0a22ed881cce
if [[ "${MARCH}" == "x86_64" ]]
then
    KERNEL_VERSION=""

    # we need koji 
    dnf5 install -y koji

    if [[ ${FEDORA_VERSION} -eq 42 ]]
    then 
        KERNEL_VERSION="kernel-6.17.9-200.fc42"
    elif [[ ${FEDORA_VERSION} -eq 43 ]]
    then
        KERNEL_VERSION="kernel-6.17.9-300.fc43"
    fi
    
    mkdir /tmp/kernel
    bash -c "cd /tmp/kernel; koji download-build --arch=x86_64 ${KERNEL_VERSION}"
    rpm-ostree override replace /tmp/kernel/*.rpm
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
    echo "Installing NVIDIA drivers for cyan variant..."
    
    # Check if pre-built cyan deps are available
    if [[ -d "/mnt-cyan-deps/nvidia" ]] && ls /mnt-cyan-deps/nvidia/kmod-nvidia-*.rpm &>/dev/null 2>&1; then
        echo "Using pre-built NVIDIA kernel modules from cyan-deps..."
        
        # Install pre-built kernel modules
        dnf5 -y install /mnt-cyan-deps/nvidia/kmod-nvidia-*.rpm
        
        # Install NVIDIA userspace components from RPM Fusion
        dnf5 -y install xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs
        
        # Get kernel version for depmod
        if [[ "$DO_INSTALL_LTS" == "true" ]]; then
            KERNEL_VERSION=$(rpm -q kernel-longterm --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n1)
        else
            KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n1)
        fi
        
        # Update module dependencies
        depmod -a ${KERNEL_VERSION}
    else
        echo "ERROR: Building NVIDIA modules from source in OSTree is not supported."
        echo "Please build cyan-deps first: make build-cyan-deps push-cyan-deps"
        exit 1
    fi
    
    # Add NVIDIA modules to load at boot
    echo 'nvidia' >> "${MODULES_CONF}"
    echo 'nvidia_drm' >> "${MODULES_CONF}"
    echo 'nvidia_modeset' >> "${MODULES_CONF}"
    echo 'nvidia_uvm' >> "${MODULES_CONF}"
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

# Install just command runner
# We install this manually as it somehow breaks the iso installer 
# if its installed as a system level package
mkdir -p /tmp/just
curl -L "${JUST_RELEASE_URL}" | tar xz -C /tmp/just
mv /tmp/just/just /usr/bin/just
chmod +x /usr/bin/just
rm -rf /tmp/just

# Verify NVIDIA kernel modules are built if cyan variant
if [[ "$(is_option_in_build_options cyan)" == "${TRUE}" ]]
then
    # Check if NVIDIA kernel modules exist for the installed kernel
    KERNEL_VERSION=$(rpm -qa | grep -P 'kernel-(|longterm-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|longterm-)//')
    NVIDIA_MODULES_FOUND=0
    
    # Look for NVIDIA kernel modules in the expected locations
    if find "/lib/modules/${KERNEL_VERSION}" -name "nvidia*.ko*" 2>/dev/null | grep -q nvidia; then
        NVIDIA_MODULES_FOUND=1
        echo "SUCCESS: NVIDIA kernel modules found for kernel ${KERNEL_VERSION}"
    fi
    
    # If modules not found, this is a critical error
    if [[ $NVIDIA_MODULES_FOUND -eq 0 ]]; then
        echo "ERROR: NVIDIA kernel modules not found for kernel ${KERNEL_VERSION}"
        echo "This will cause the system to fall back to nouveau driver"
        exit 1
    fi
fi


# Special packages for trueblue builds
if [[ "$(is_option_in_build_options trueblue)" == "${TRUE}" ]]
then 
    curl -Lo /tmp/zerofs.tar.gz "${ZEROFS_RELEASE_URL}"
    zerofs_file="zerofs-amd64"

    if [[ "${MARCH}" == "aarch64" ]]
    then 
        zerofs_file="zerofs-arm64"
    fi

    tar -xzf /tmp/zerofs.tar.gz -C /usr/bin/ "${zerofs_file}"
    mv "/usr/bin/${zerofs_file}" /usr/bin/zerofs
    chmod a+x /usr/bin/zerofs
fi


# Special packages for kuberblue builds
if [[ "$(is_option_in_build_options kuberblue)" == "${TRUE}" ]]
then 
    curl -Lo /tmp/chainsaw.tar.gz "${CHAINSAW_RELEASE_URL}"
    tar -xzf /tmp/chainsaw.tar.gz -C /usr/bin/ chainsaw
    chmod a+x /usr/bin/chainsaw
    rm /tmp/chainsaw.tar.gz
fi

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


if [[ "$(is_option_in_build_options nix)" == "${TRUE}" ]]
then 
    # Remove the symlink
    unlink /root
    # Create a real directory
    mkdir -p /root

    # TODO: get this into its own file. however, it was 
    # causing gid mis-users if it put it under artifcats_nix/
    # and would create the gid as 968.
    # Create systemd-sysusers configuration for Nix users
    cat > /usr/lib/sysusers.d/nix.conf <<'EOF'
# Nix build group
g nixbld 30000

# Nix build users
u nixbld1  30001 "Nix build user 1"  /var/empty /sbin/nologin
u nixbld2  30002 "Nix build user 2"  /var/empty /sbin/nologin
u nixbld3  30003 "Nix build user 3"  /var/empty /sbin/nologin
u nixbld4  30004 "Nix build user 4"  /var/empty /sbin/nologin
u nixbld5  30005 "Nix build user 5"  /var/empty /sbin/nologin
u nixbld6  30006 "Nix build user 6"  /var/empty /sbin/nologin
u nixbld7  30007 "Nix build user 7"  /var/empty /sbin/nologin
u nixbld8  30008 "Nix build user 8"  /var/empty /sbin/nologin
u nixbld9  30009 "Nix build user 9"  /var/empty /sbin/nologin
u nixbld10 30010 "Nix build user 10" /var/empty /sbin/nologin
u nixbld11 30011 "Nix build user 11" /var/empty /sbin/nologin
u nixbld12 30012 "Nix build user 12" /var/empty /sbin/nologin
u nixbld13 30013 "Nix build user 13" /var/empty /sbin/nologin
u nixbld14 30014 "Nix build user 14" /var/empty /sbin/nologin
u nixbld15 30015 "Nix build user 15" /var/empty /sbin/nologin
u nixbld16 30016 "Nix build user 16" /var/empty /sbin/nologin
u nixbld17 30017 "Nix build user 17" /var/empty /sbin/nologin
u nixbld18 30018 "Nix build user 18" /var/empty /sbin/nologin
u nixbld19 30019 "Nix build user 19" /var/empty /sbin/nologin
u nixbld20 30020 "Nix build user 20" /var/empty /sbin/nologin
u nixbld21 30021 "Nix build user 21" /var/empty /sbin/nologin
u nixbld22 30022 "Nix build user 22" /var/empty /sbin/nologin
u nixbld23 30023 "Nix build user 23" /var/empty /sbin/nologin
u nixbld24 30024 "Nix build user 24" /var/empty /sbin/nologin
u nixbld25 30025 "Nix build user 25" /var/empty /sbin/nologin
u nixbld26 30026 "Nix build user 26" /var/empty /sbin/nologin
u nixbld27 30027 "Nix build user 27" /var/empty /sbin/nologin
u nixbld28 30028 "Nix build user 28" /var/empty /sbin/nologin
u nixbld29 30029 "Nix build user 29" /var/empty /sbin/nologin
u nixbld30 30030 "Nix build user 30" /var/empty /sbin/nologin
u nixbld31 30031 "Nix build user 31" /var/empty /sbin/nologin
u nixbld32 30032 "Nix build user 32" /var/empty /sbin/nologin

# Add build users to nixbld group
m nixbld1 nixbld
m nixbld2 nixbld
m nixbld3 nixbld
m nixbld4 nixbld
m nixbld5 nixbld
m nixbld6 nixbld
m nixbld7 nixbld
m nixbld8 nixbld
m nixbld9 nixbld
m nixbld10 nixbld
m nixbld11 nixbld
m nixbld12 nixbld
m nixbld13 nixbld
m nixbld14 nixbld
m nixbld15 nixbld
m nixbld16 nixbld
m nixbld17 nixbld
m nixbld18 nixbld
m nixbld19 nixbld
m nixbld20 nixbld
m nixbld21 nixbld
m nixbld22 nixbld
m nixbld23 nixbld
m nixbld24 nixbld
m nixbld25 nixbld
m nixbld26 nixbld
m nixbld27 nixbld
m nixbld28 nixbld
m nixbld29 nixbld
m nixbld30 nixbld
m nixbld31 nixbld
m nixbld32 nixbld
EOF

    # Install nix
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
        sh -s -- install linux \
        --extra-conf "sandbox = false" \
        --init none \
        --no-confirm
    
    # Create systemd service for nix-daemon
    cp /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.service /etc/systemd/system/
    
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
    nix-channel --update
    
    # Optional: Pre-install some Nix packages
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    nix_pkgs=$(get_nix_install_packages)
    nix-env -iA $(for pkg in ${nix_pkgs}; do printf '%s ' "${pkg}"; done)
 

    # Put the /nix under /etc/immutablue 
    # this is bind-mounted to /nix at runtime
    mkdir -p /etc/immutablue/nix
    mv /nix /etc/immutablue/nix/install
    mkdir -p /nix

    # Clean up: remove the temporary directory
    rm -rf /root 
    # Restore the original symlink
    ln -s var/roothome /root
fi

