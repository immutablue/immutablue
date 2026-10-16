#!/bin/bash
# Fedora 44+ Cyan: copy isolated open/580 stacks and finish them after the kernel settles.
set -euo pipefail

nvidia_install_stacks() (
    source_dir=/mnt-cyan-deps/stacks
    destination=/usr/lib/immutablue/nvidia
    for branch in open 580; do
        if [[ ! -f "$source_dir/$branch/manifest.json" || ! -s "$source_dir/$branch/requirements.txt" ]]; then
            echo "ERROR: rebuild cyan-deps: missing the $branch NVIDIA stack" >&2
            exit 1
        fi
    done

    dependency_list=$(sort -u "$source_dir/open/requirements.txt" "$source_dir/580/requirements.txt")
    mapfile -t dependencies <<< "$dependency_list"
    for dependency in "${dependencies[@]}"; do
        case "$dependency" in
            *nvidia*|akmod*) echo "ERROR: NVIDIA dependency leaked into base: $dependency" >&2; exit 1 ;;
        esac
    done
    dnf5 -y --refresh install fedora-repos-archive
    dnf5 config-manager setopt updates-archive.enabled=0
    dnf5 -y --refresh --enablerepo=updates-archive install systemd-udev jq squashfs-tools policycoreutils "${dependencies[@]}"
    command -v systemd-sysext
    if rpm -qa --qf '%{NAME}\n' | grep -E '^(xorg-x11-drv-nvidia|kmod-nvidia|akmod-nvidia)' > /dev/null; then
        echo 'ERROR: the base image already has an NVIDIA stack; refusing to overlay it' >&2
        exit 1
    fi
    mkdir -p "$destination"
    cp -a "$source_dir/open" "$source_dir/580" "$destination/"

    mkdir -p /etc/OpenCL/vendors /etc/xdg/autostart
    ln -sfn /usr/share/immutablue/nvidia/nvidia.icd /etc/OpenCL/vendors/nvidia.icd
    for desktop in "$destination"/*/extension/usr/share/immutablue/nvidia/autostart/*.desktop; do
        [[ -f "$desktop" ]] || continue
        ln -sfn "/usr/share/immutablue/nvidia/autostart/${desktop##*/}" "/etc/xdg/autostart/${desktop##*/}"
    done

    mkdir -p /usr/lib/modprobe.d /usr/lib/dracut/dracut.conf.d /usr/lib/sysusers.d
    cat > /usr/lib/modprobe.d/immutablue-nvidia.conf <<'EOF'
blacklist nouveau
blacklist nova_core
blacklist nova_drm
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
options nvidia_drm modeset=1
EOF
    cat > /usr/lib/dracut/dracut.conf.d/90-immutablue-nvidia.conf <<'EOF'
omit_drivers+=" nouveau nova_core nova_drm nvidia nvidia_drm nvidia_modeset nvidia_uvm nvidia_peermem "
install_items+=" /usr/lib/modprobe.d/immutablue-nvidia.conf "
EOF
    cat > /usr/lib/sysusers.d/immutablue-nvidia.conf <<'EOF'
u nvidia-persistenced - "NVIDIA Persistence Daemon" /run/nvidia-persistenced
EOF
    systemctl enable immutablue-nvidia.service
)

# Squashfs keeps labels at the merged /usr paths. OSTree would relabel a directory bundle.
nvidia_extension_labels() (
    root=$1
    paths=$(mktemp)
    trap 'rm -f "$paths"' EXIT
    find "$root" -mindepth 1 -print0 | sort -z > "$paths"
    while IFS= read -r -d '' path; do
        name=${path#"$root/"}
        if [[ -L "$path" ]]; then type=lnk_file
        elif [[ -d "$path" ]]; then type=dir
        elif [[ -f "$path" ]]; then type='file'
        else echo "Unsupported extension file type: $name" >&2; exit 1; fi
        context=$(matchpathcon -N -n -m "$type" "/$name")
        [[ -n "$context" && "$context" != '<<none>>' ]] || {
            echo "No SELinux context for /$name" >&2; exit 1
        }
        name=${name//\\/\\\\}
        name=${name// /\\ }
        printf '%s x security.selinux=%s\n' "$name" "$context"
    done < "$paths"
)

nvidia_finalize_stacks() (
    stacks=/usr/lib/immutablue/nvidia
    stage="$(mktemp -d)"
    trap 'rm -rf "$stage"' EXIT
    for branch in open 580; do
        extension="$stacks/$branch/extension"
        kernel=$(jq -er .kernel "$stacks/$branch/manifest.json")
        version=$(jq -er .version "$stacks/$branch/manifest.json")
        for directory in /usr/lib/modules/*; do
            [[ -f "$directory/vmlinuz" && "$directory" != *+debug ]] || continue
            if [[ "${directory##*/}" != "$kernel" ]]; then
                echo "ERROR: $branch NVIDIA is for $kernel, image kernel is ${directory##*/}" >&2
                echo 'Rebuild cyan-deps with CYAN_KERNEL_VERSION matching the image kernel.' >&2
                exit 1
            fi
        done
        module="$(find "$extension/usr/lib/modules/$kernel" -name 'nvidia.ko*' -print -quit)"
        [[ -n "$module" ]]
        [[ "$(modinfo -F version "$module")" == "$version" ]]
        [[ "$(modinfo -F vermagic "$module")" == "$kernel "* ]]

        mkdir -p "$stage/$branch/lib/modules"
        cp -a --reflink=auto "/usr/lib/modules/$kernel" "$stage/$branch/lib/modules/"
        cp -a "$extension/usr/lib/modules/$kernel/." "$stage/$branch/lib/modules/$kernel/"
        depmod -b "$stage/$branch" "$kernel"
        cp -a "$stage/$branch/lib/modules/$kernel"/modules.* "$extension/usr/lib/modules/$kernel/"

        rm -rf "${extension:?}/etc"
        mkdir -p "$extension/usr/lib/extension-release.d"
        { grep -E '^(ID|VERSION_ID)=' /etc/os-release
          printf 'EXTENSION_RELOAD_MANAGER=1\n'
        } > "$extension/usr/lib/extension-release.d/extension-release.immutablue-nvidia"
        nvidia_extension_labels "$extension" > "$stage/$branch.labels"
        mksquashfs "$extension" "$stacks/$branch/immutablue-nvidia.raw" \
            -noappend -all-root -no-progress -xattrs -comp zstd \
            -xattrs-exclude '^security.selinux$' -pf "$stage/$branch.labels"
        rm -rf "$extension"
    done
)

case "${1:-}" in
    install) nvidia_install_stacks; exit ;;
    finalize) nvidia_finalize_stacks; exit ;;
    '') ;;
    *) echo "Unknown NVIDIA build phase: $1" >&2; exit 2 ;;
esac

if [[ -f "${INSTALL_DIR:-}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f ./99-common.sh ]]; then source ./99-common.sh; fi
if [[ "$(is_option_in_build_options cyan)" != "${TRUE}" || "$FEDORA_VERSION" -lt 44 ]]; then
    exit 0
fi
if [[ "$(is_skipped initramfs)" == "${TRUE}" ]]; then
    echo 'ERROR: selectable NVIDIA drivers require initramfs regeneration; remove SKIP=initramfs' >&2
    exit 1
fi
nvidia_finalize_stacks
