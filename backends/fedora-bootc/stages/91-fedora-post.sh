#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 91-fedora-post.sh (fedora-bootc)
#
# Fedora/RPM clean-up that runs after the neutral build/90-post.sh. Formerly
# the RPM-specific parts of 90-post.sh.

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
