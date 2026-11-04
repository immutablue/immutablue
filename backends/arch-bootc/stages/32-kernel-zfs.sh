#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 32-kernel-zfs.sh (arch-bootc)
#
# The image's kernel, and the Arch side of LTS=1, ZFS=1 and TRUEBLUE=1
# (both). Runs after the neutral 30-install-packages.sh and before
# 80-initramfs.sh. The kernel is chosen here rather than listed in
# packages.yaml, as fedora-bootc's stage 29 does: linux, or linux-lts for LTS,
# each with its headers (which zfs-dkms needs, and which ship with the image
# for DKMS modules a user's derived image adds).
#
# ZFS is not in Arch's official repositories (CDDL), so it comes from the
# ArchZFS project's repository, published as the 'experimental' GitHub
# release. Two package shapes exist:
#
#   zfs-<kernel>   prebuilt for one exact kernel version (zfs-linux,
#                  zfs-linux-lts); signed, no compiler, preferred
#   zfs-dkms       built here against the installed kernel's headers
#
# The prebuilt package depends on '<kernel>=<exact version>', so it cannot be
# installed while ArchZFS has not yet rebuilt for the kernel Arch just
# shipped. zfs-dkms is the fallback for that window; a kernel newer than the
# OpenZFS release supports fails that build too, which stops the image build
# rather than shipping an image without ZFS.

ARCHZFS_SERVER="https://github.com/archzfs/archzfs/releases/download/experimental"
ARCHZFS_KEY_FPR="3A9917BF0DED5C13F69AC68FABEC0A1208037BE9"
ARCHZFS_KEY_FILE="${INSTALL_DIR}/backends/arch-bootc/keys/archzfs.asc"


# -----------------------------------
# The kernel: linux, or linux-lts for LTS.
#
# Nothing in packages.yaml names a kernel, but a package could still pull
# 'linux' in as a dependency; on an LTS image it is removed (-Rdd, since
# that dependent stays) so dracut in 80-initramfs.sh sees one kernel only.
# -----------------------------------
kernel_pkg="linux"
if [[ "${DO_INSTALL_LTS}" == "true" ]]
then
    kernel_pkg="linux-lts"
fi
backend_pkg_install "${kernel_pkg}" "${kernel_pkg}-headers"
if [[ "${kernel_pkg}" != "linux" ]] && pacman -Q linux > /dev/null 2>&1
then
    echo "WARNING: 'linux' was pulled in by $(pacman -Qi linux | awk -F': ' '/^Required By/ { print $2 }'); removing it for ${kernel_pkg}" >&2
    pacman -Rdd --noconfirm linux
    if pacman -Q linux-headers > /dev/null 2>&1
    then
        pacman -Rdd --noconfirm linux-headers
    fi
fi


if [[ "${DO_INSTALL_ZFS}" != "true" ]] && [[ "${DO_INSTALL_LTS}" != "true" ]]
then
    exit 0
fi

# ArchZFS publishes x86_64 packages only.
if [[ "$(uname -m)" != "x86_64" ]]
then
    echo "ERROR: ZFS on arch-bootc needs ArchZFS, which only builds x86_64 (this is $(uname -m))" >&2
    exit 1
fi


# -----------------------------------
# The ArchZFS repository.
#
# The release key is vendored in backends/arch-bootc/keys/archzfs.asc (taken
# from the archzfs-keyring repository's packager entry, fingerprint checked)
# rather than fetched from a keyserver at build time. The Arch base image's
# keyring has no local master key to lsign with, so the section uses
# 'TrustAll': a signature is still Required and must come from a key in the
# keyring, and the only key added here is ArchZFS's.
# -----------------------------------
pacman-key --add "${ARCHZFS_KEY_FILE}"
if ! pacman-key --finger "${ARCHZFS_KEY_FPR}" > /dev/null
then
    echo "ERROR: ${ARCHZFS_KEY_FILE} is not the ArchZFS release key ${ARCHZFS_KEY_FPR}" >&2
    exit 1
fi

if ! grep -q '^\[archzfs\]' /etc/pacman.conf
then
    printf '\n[archzfs]\nSigLevel = Required TrustAll\nServer = %s\n' "${ARCHZFS_SERVER}" >> /etc/pacman.conf
fi
pacman -Sy --noconfirm


# -----------------------------------
# Install: prebuilt for this kernel, else DKMS.
# -----------------------------------
if backend_pkg_install zfs-utils "zfs-${kernel_pkg}"
then
    echo "ZFS: prebuilt zfs-${kernel_pkg}"
else
    echo "WARNING: no zfs-${kernel_pkg} for $(pacman -Q "${kernel_pkg}"); ArchZFS has not caught up, building zfs-dkms" >&2
    # dkms's pacman hook builds the module for every kernel with headers.
    backend_pkg_install zfs-utils zfs-dkms
fi


# -----------------------------------
# Verify the module exists for the kernel the image boots.
#
# Each Arch kernel's module directory names its package in 'pkgbase'.
# -----------------------------------
kernel_version=""
for pkgbase in /usr/lib/modules/*/pkgbase
do
    if [[ "$(< "${pkgbase}")" == "${kernel_pkg}" ]]
    then
        kernel_version="$(basename "$(dirname "${pkgbase}")")"
    fi
done
if [[ -z "${kernel_version}" ]]
then
    echo "ERROR: no module directory for ${kernel_pkg} under /usr/lib/modules" >&2
    exit 1
fi
if ! find "/usr/lib/modules/${kernel_version}" -name 'zfs.ko*' | grep -q .
then
    echo "ERROR: zfs.ko was not built for ${kernel_version}" >&2
    exit 1
fi
depmod -a "${kernel_version}"


# -----------------------------------
# Boot-time import and mount.
#
# Fedora's zfs package enables these through its systemd preset; Arch
# applies no presets, so the units are enabled here.
# -----------------------------------
backend_svc enable zfs-import-cache.service zfs-import-scan.service \
    zfs-mount.service zfs-zed.service zfs-import.target zfs.target

echo 'zfs' >> "${MODULES_CONF}"
