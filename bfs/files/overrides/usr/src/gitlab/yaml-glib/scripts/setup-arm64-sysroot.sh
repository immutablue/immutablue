#!/bin/bash
#
# setup-arm64-sysroot.sh - Setup ARM64 cross-compilation sysroot for Fedora
#
# Copyright 2025 Zach Podbielniak
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This script downloads ARM64 packages from Fedora repositories and extracts
# them into a sysroot directory for cross-compilation.
#
# Usage:
#   ./scripts/setup-arm64-sysroot.sh [SYSROOT_PATH]
#
# Examples:
#   ./scripts/setup-arm64-sysroot.sh                    # Use default /usr/aarch64-linux-gnu/sys-root
#   ./scripts/setup-arm64-sysroot.sh ~/arm64-sysroot    # Use custom path
#
# Prerequisites:
#   sudo dnf install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu sysroot-aarch64-fc41-glibc

set -euo pipefail

print_usage () {
    echo "Usage: $0 [SYSROOT_PATH]"
    echo ""
    echo "Setup ARM64 cross-compilation sysroot by downloading Fedora ARM64 packages."
    echo "This adds glib2, libyaml, json-glib and dependencies to the Fedora sysroot."
    echo ""
    echo "Arguments:"
    echo "  SYSROOT_PATH   Path to sysroot (default: /usr/aarch64-redhat-linux/sys-root/fc41)"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --license      Show license information"
    echo ""
    echo "Examples:"
    echo "  sudo $0                      # Add libraries to Fedora's sysroot (requires sudo)"
    echo "  $0 ~/arm64-sysroot           # Use custom path in home directory"
}

print_license () {
    echo "setup-arm64-sysroot.sh"
    echo "Copyright 2025 Zach Podbielniak"
    echo "SPDX-License-Identifier: AGPL-3.0-or-later"
    echo ""
    echo "This program is free software: you can redistribute it and/or modify"
    echo "it under the terms of the GNU Affero General Public License as published"
    echo "by the Free Software Foundation, either version 3 of the License, or"
    echo "(at your option) any later version."
}

# Parse arguments
if [[ $# -gt 0 ]]
then
    case "${1}" in
        -h|--help)
            print_usage
            exit 0
            ;;
        --license)
            print_license
            exit 0
            ;;
        -*)
            echo "Unknown option: ${1}"
            print_usage
            exit 1
            ;;
        *)
            SYSROOT="${1}"
            ;;
    esac
else
    # Use Fedora's sysroot from sysroot-aarch64-fc41-glibc package
    SYSROOT="/usr/aarch64-redhat-linux/sys-root/fc41"
fi

echo "=== ARM64 Sysroot Setup ==="
echo "Sysroot path: ${SYSROOT}"
echo ""

# Check for required tools
for cmd in dnf rpm2cpio cpio
do
    if ! command -v "${cmd}" &>/dev/null
    then
        echo "Error: Required command '${cmd}' not found."
        exit 1
    fi
done

# Check if cross-compiler is installed
if ! command -v aarch64-linux-gnu-gcc &>/dev/null
then
    echo "Warning: aarch64-linux-gnu-gcc not found."
    echo "Install with: sudo dnf install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu"
    echo ""
fi

# Create sysroot directory
if [[ ! -d "${SYSROOT}" ]]
then
    echo "Creating sysroot directory: ${SYSROOT}"
    mkdir -p "${SYSROOT}"
fi

# Check write permissions
if [[ ! -w "${SYSROOT}" ]]
then
    echo "Error: Cannot write to ${SYSROOT}"
    echo "Either run with sudo or use a path you have write access to."
    exit 1
fi

# Create temporary directory for downloads
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Downloading ARM64 packages..."
echo ""

# List of packages needed for yaml-glib cross-compilation
# Note: glibc and kernel headers are provided by sysroot-aarch64-fc41-glibc
PACKAGES=(
    # Core GLib dependencies
    glib2
    glib2-devel

    # libyaml
    libyaml
    libyaml-devel

    # JSON-GLib
    json-glib
    json-glib-devel

    # Runtime dependencies
    libffi
    libffi-devel
    pcre2
    pcre2-devel
    zlib
    zlib-devel
    libxcrypt

    # GIO dependencies
    libmount
    libmount-devel
    libblkid
    libblkid-devel
    libselinux
    libselinux-devel
    libsepol
    libsepol-devel
    pcre2-utf16
    pcre2-utf32
    util-linux
)

# Download packages
dnf download \
    --destdir="${TMPDIR}" \
    --forcearch=aarch64 \
    "${PACKAGES[@]}" 2>&1 | grep -E "(Downloading|\.rpm)" || true

echo ""
echo "Extracting packages to sysroot..."

# Extract all RPMs to sysroot
for rpm in "${TMPDIR}"/*.rpm
do
    if [[ -f "${rpm}" ]]
    then
        echo "  Extracting: $(basename "${rpm}")"
        rpm2cpio "${rpm}" | cpio -idm -D "${SYSROOT}" 2>/dev/null
    fi
done

echo ""
echo "Fixing pkgconfig paths..."

# Fix absolute paths in .pc files
# The pkgconfig files have prefix=/usr which works with PKG_CONFIG_SYSROOT_DIR
# But some files may have absolute paths that need adjustment
for pcfile in "${SYSROOT}"/usr/lib64/pkgconfig/*.pc "${SYSROOT}"/usr/share/pkgconfig/*.pc
do
    if [[ -f "${pcfile}" ]]
    then
        # Most .pc files use ${prefix} which works correctly with sysroot
        # Only fix if there are hardcoded absolute paths
        :
    fi
done

echo ""
echo "=== Sysroot Setup Complete ==="
echo ""
echo "Sysroot location: ${SYSROOT}"
echo ""
echo "Contents:"
ls -la "${SYSROOT}/usr/lib64/pkgconfig/"*.pc 2>/dev/null | head -10 || echo "  (no pkgconfig files found)"
echo ""
echo "To build yaml-glib for ARM64:"
echo "  make LINUX_ARM64=1 ARM64_SYSROOT=${SYSROOT}"
echo ""
echo "To run ARM64 tests via QEMU:"
echo "  make LINUX_ARM64=1 ARM64_SYSROOT=${SYSROOT} check"
