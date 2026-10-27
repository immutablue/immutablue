#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi
# 29-kernel-zfs-nvidia.sh (fedora-bootc)
#
# Everything that settles the kernel and its out-of-tree modules before the
# neutral 30-install-packages.sh installs packages.yaml: the ublue udev rules,
# akmods, the kwizart LTS kernel, the kernel versionlock, ZFS via DKMS, the
# rpm_url release packages (RPM Fusion) and the cyan NVIDIA drivers.
#
# This used to be the first half of build/30-install-packages.sh. It is all
# Fedora/RPM-specific, so it moved into the fedora-bootc backend unchanged and
# runs immediately before stage 30.

# Distroless (GNOME OS) builds still pass through this backend until they get
# their own; none of this applies to them.
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    exit 0
fi

pkg_urls=$(get_immutablue_package_urls)

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
    immutablue_curl -fLo "/etc/yum.repos.d/kwizart-kernel-longterm-${LTS_VERSION}-fedora-${FEDORA_VERSION}.repo" "${LTS_REPO_URL}"
    
    # Remove the standard kernel packages
    # The protect_running_kernel=false option allows removing the currently running kernel
    dnf5 -y remove --setopt protect_running_kernel=false kernel{,-core,-modules,-modules-extra}
    
    # Install the LTS kernel packages
    dnf5 -y install kernel-longterm{,-core,-modules,-modules-extra,-devel}
fi

# -----------------------------------
# Pin the kernel for the rest of the build.
#
# The kernel's final state is settled at this point, and everything after it
# that builds out-of-tree modules -- the ZFS DKMS build below, and the NVIDIA
# kmods on cyan -- compiles against whatever `rpm -qa` reports right now. The
# bulk package install further down is free to pull a newer kernel in as a
# transitive dependency, which would leave those modules built for a kernel
# the image no longer ships: a system that boots without ZFS (so, for a ZFS
# root, does not boot) or without its GPU driver.
#
# Locking here makes that failure a visible dependency conflict at build time
# instead of a broken image. The lock is build-time only; it is removed in
# 90-post.sh so it cannot interfere with rpm-ostree layering on the installed
# system.
# -----------------------------------
kernel_pkg="kernel"
if [[ "$DO_INSTALL_LTS" == "true" ]]; then kernel_pkg="kernel-longterm"; fi

# versionlock refuses a package it cannot find, and the distroless path has
# already exited above, but a variant could still legitimately lack a kernel
# (a container-only image), so an absent kernel is reported rather than fatal.
if rpm --quiet -q "${kernel_pkg}"
then
    dnf5 -y versionlock add "${kernel_pkg}" "${kernel_pkg}-core" \
        "${kernel_pkg}-modules" "${kernel_pkg}-modules-extra"
    dnf5 versionlock list
else
    echo "WARNING: '${kernel_pkg}' is not installed; skipping kernel versionlock"
fi

# kernel override to fix issue introduced in:
# - 6.12.60
# - 6.17.10
# https://github.com/torvalds/linux/commit/cfa0904a35fd0231f4d05da0190f0a22ed881cce
# if [[ "${MARCH}" == "x86_64" ]]
# then
#     KERNEL_VERSION=""
#
#     # we need koji 
#     dnf5 install -y koji
#
#     if [[ ${FEDORA_VERSION} -eq 42 ]]
#     then 
#         KERNEL_VERSION="kernel-6.17.9-200.fc42"
#     elif [[ ${FEDORA_VERSION} -eq 43 ]]
#     then
#         KERNEL_VERSION="kernel-6.17.9-300.fc43"
#     fi
#     
#     mkdir /tmp/kernel
#     bash -c "cd /tmp/kernel; koji download-build --arch=x86_64 ${KERNEL_VERSION}"
#     rpm-ostree override replace /tmp/kernel/*.rpm
# fi

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
    
    # Fedora 44+ carries both branches in isolated, boot-selectable extensions.
    if [[ "$FEDORA_VERSION" -ge 44 ]]; then
        bash "${INSTALL_DIR}/backends/fedora-bootc/stages/75-nvidia.sh" install
    elif [[ -d "/mnt-cyan-deps/nvidia" ]] && ls /mnt-cyan-deps/nvidia/kmod-nvidia-*.rpm &>/dev/null 2>&1; then
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
    if [[ "$FEDORA_VERSION" -lt 44 ]]; then
        echo 'nvidia' >> "${MODULES_CONF}"
        echo 'nvidia_drm' >> "${MODULES_CONF}"
        echo 'nvidia_modeset' >> "${MODULES_CONF}"
        echo 'nvidia_uvm' >> "${MODULES_CONF}"
    fi
fi


# Verify NVIDIA kernel modules are built if cyan variant
if [[ "$(is_option_in_build_options cyan)" == "${TRUE}" && "$FEDORA_VERSION" -lt 44 ]]
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
