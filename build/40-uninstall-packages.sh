#!/bin/bash 
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi


pkgs=$(get_immutablue_packages_to_remove)


if [[ "$pkgs" != "" ]]
then 
    dnf5 -y remove "$(for pkg in $pkgs; do printf '%s ' "$pkg"; done)"
fi

