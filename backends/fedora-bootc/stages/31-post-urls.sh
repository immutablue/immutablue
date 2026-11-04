#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi
# 31-post-urls.sh (fedora-bootc)
#
# rpm_post_url: package files installed after the main package set, such as
# trueblue's 45Drives cockpit plugins. Formerly part of
# build/30-install-packages.sh.

pkg_post_urls=$(get_immutablue_package_post_urls)

# Install RPMs from URLs post pkgs
# This is for packages that need to be downloaded directly from URLs
# rather than from repositories, that need to be installed after the 
# regular pkags above
if [[ "$pkg_post_urls" != "" ]]
then
    # Convert the list of URLs into a space-separated string for dnf
    dnf5 -y install $(for pkg in $pkg_post_urls; do printf '%s ' "$pkg"; done)
fi
