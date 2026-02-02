#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# -----------------------------------
# Distroless builds don't use dnf for package removal
# -----------------------------------
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    echo "=== Distroless build: skipping dnf package removal ==="
    exit 0
fi

pkgs=$(get_immutablue_packages_to_remove)


if [[ "$pkgs" != "" ]]
then 
    dnf5 -y remove $(for pkg in $pkgs; do printf '%s ' "$pkg"; done)
fi

