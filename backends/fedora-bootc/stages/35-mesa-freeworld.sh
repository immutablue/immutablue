#!/bin/bash
# 35-mesa-freeworld.sh
#
# Swaps the patent-stripped Mesa VA-API/VDPAU drivers shipped by Fedora for
# the RPM Fusion "freeworld" builds, which add hardware H.264, HEVC, and VC-1
# decode/encode profiles. Without this, AMD/Intel users silently fall back to
# CPU video decode for any non-AV1/VP9 web video, which tanks battery life.

set -euxo pipefail

if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# Distroless builds use GNOME OS base and have no dnf5
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]; then
    echo "=== Distroless build: skipping mesa freeworld swap ==="
    exit 0
fi

# Only swap drivers that are actually present (aarch64 / minimal images may
# not ship them).
to_swap=()
if rpm -q mesa-va-drivers >/dev/null 2>&1; then
    to_swap+=(mesa-va-drivers)
fi
if rpm -q mesa-vdpau-drivers >/dev/null 2>&1; then
    to_swap+=(mesa-vdpau-drivers)
fi

if [[ ${#to_swap[@]} -eq 0 ]]; then
    echo "=== No stock mesa VA/VDPAU drivers installed; nothing to swap ==="
    exit 0
fi

freeworld=()
for pkg in "${to_swap[@]}"; do
    freeworld+=("${pkg}-freeworld")
done

dnf5 -y install --allowerasing "${freeworld[@]}"
