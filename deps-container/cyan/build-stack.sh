#!/bin/bash
# Build one NVIDIA branch in isolation; never resolve open and 580 together.
set -euo pipefail
branch="$1"
case "$branch" in
    open) suffix='' ;;
    580) suffix=-580xx ;;
    *) echo "Unknown NVIDIA branch: $branch" >&2; exit 1 ;;
esac
mkdir -p /rpms/stacks/"$branch"
if [[ "$branch" == 580 && "${FEDORA_VERSION}" -lt 44 ]]; then
    exit 0
fi

packages=("akmod-nvidia${suffix}" "xorg-x11-drv-nvidia${suffix}"
    "xorg-x11-drv-nvidia${suffix}-cuda" "xorg-x11-drv-nvidia${suffix}-cuda-libs"
    "xorg-x11-drv-nvidia${suffix}-libs")
if [[ "$FEDORA_VERSION" -ge 44 ]]; then
    packages+=("xorg-x11-drv-nvidia${suffix}-xorg-libs")
fi
if [[ "$(uname -m)" == x86_64 && "$FEDORA_VERSION" -ge 44 ]]; then
    packages+=("xorg-x11-drv-nvidia${suffix}-libs.i686"
        "xorg-x11-drv-nvidia${suffix}-cuda-libs.i686")
fi
# Container hardware must never decide which flavor gets built.
mkdir -p /etc/rpm
if [[ "$branch" == 580 ]]; then
    printf '%%_without_kmod_nvidia_detect 1\n' > /etc/rpm/macros.immutablue-nvidia
elif [[ "$FEDORA_VERSION" -ge 44 ]]; then
    printf '%%_with_kmod_nvidia_open 1\n' > /etc/rpm/macros.immutablue-nvidia
fi
dnf install -y "${packages[@]}"
kver="$(rpm -q "${KERNEL_PACKAGE:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n')"
[[ "$kver" != *$'\n'* ]]
akmods --kernels "$kver" --force
module_list=$(find /var/cache/akmods -name "kmod-nvidia${suffix}-${kver}-*.rpm")
[[ -n "$module_list" ]]
mapfile -t modules <<< "$module_list"
dnf install -y "${modules[@]}"
if [[ "$branch" == open ]]; then
    mkdir -p /rpms/nvidia
    cp "${modules[@]}" /rpms/nvidia/
fi
