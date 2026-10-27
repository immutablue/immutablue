#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 91-fedora-post.sh (fedora-bootc)
#
# Fedora/RPM clean-up that runs after the neutral build/90-post.sh. Formerly
# the RPM-specific parts of 90-post.sh.

if [[ "$(is_option_in_build_options kuberblue)" == "${TRUE}" ]]
then
    # BIB (bootc-image-builder) reads /usr/lib/os-release and detects distro as
    # kuberblue-42 (the base Silverblue layer). It then resolves $releasever=42 for
    # repo GPG key lookups. The rpmfusion package was installed in the Fedora 43
    # context so only RPM-GPG-KEY-rpmfusion-free-fedora-43 exists. Symlink the 2020
    # key (used for F33-F42) as the fedora-42 entry so BIB can depsolve the installer.
    #
    # Scope: kuberblue-only is correct. Other variants use ID=fedora (not ID=kuberblue)
    # in os-release, so BIB uses its built-in fedora-42 distro def which already has
    # correct GPG key paths. Only kuberblue overrides ID to trigger the custom def.
    if [[ -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-2020 ]] && \
       [[ ! -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-42 ]]; then
        ln -s RPM-GPG-KEY-rpmfusion-free-fedora-2020 \
              /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-42
    fi
    if [[ -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-2020 ]] && \
       [[ ! -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-42 ]]; then
        ln -s RPM-GPG-KEY-rpmfusion-nonfree-fedora-2020 \
              /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-42
    fi
fi


# Release the build-time kernel versionlock set in stages/29-kernel-zfs-nvidia.sh.
#
# The lock exists only to stop a later dnf5 transaction from pulling a kernel
# newer than the one the ZFS DKMS and NVIDIA kmod builds compiled against. It
# must not ship: on the installed system it would silently constrain
# rpm-ostree layering. 'clear' leaves an empty stanza behind, so the file
# itself is removed.
if command -v dnf5 >/dev/null 2>&1
then
    dnf5 -y versionlock clear || true
    rm -f /etc/dnf/versionlock.toml
fi
