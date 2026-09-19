#!/bin/bash
# Copy one NVIDIA RPM payload into a sysext tree and record its external Requires.
set -euo pipefail
branch=$1 kernel=$2 output=$3
case "$branch" in open|580) ;; *) exit 1 ;; esac
extension="$output/extension"
mkdir -p "$extension"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
rpm -qa --qf '%{NAME}.%{ARCH}\n' > "$stage/installed"
grep -E '^(xorg-x11-drv-nvidia|nvidia-|kmod-nvidia-)' "$stage/installed" |
    grep -v -- '-kmodsrc\.' | sort -u > "$stage/packages"
mapfile -t packages < "$stage/packages"
(( ${#packages[@]} > 0 ))
declare -A owned=() requirements=()
for package in "${packages[@]}"; do owned["$package"]=1; done
for package in "${packages[@]}"; do
    rpm -q --requires "$package" > "$stage/requires"
    while IFS= read -r requirement; do
        case "$requirement" in
            rpmlib\(*) continue ;;
            \(xorg-x11-drv-nvidia*) continue ;;
            \(*) echo "Review new rich dependency: $requirement" >&2; exit 1 ;;
        esac
        rpm -q --whatprovides "${requirement%% *}" --qf '%{NAME}.%{ARCH}\n' > "$stage/providers"
        mapfile -t providers < "$stage/providers"
        internal=false
        for provider in "${providers[@]}"; do
            if [[ -v owned["$provider"] ]]; then internal=true; fi
        done
        if [[ "$internal" == false ]]; then
            requirements["$requirement"]=1
        fi
    done < "$stage/requires"
    rpm -q --qf '[%{FILENAMES}\t%{FILEFLAGS}\t%{FILEMODES}\n]' "$package" > "$stage/files"
    while IFS=$'\t' read -r filename flags mode; do
        (( (mode & 0170000) != 0040000 )) || continue
        (( (flags & 64) == 0 )) || continue
        if (( flags & 2 )) && [[ ! -e "$filename" ]]; then continue; fi
        if [[ -d "$filename" && ! -L "$filename" ]]; then continue; fi
        case "$filename" in
            /usr/*) relative=${filename#/} ;;
            /lib/modules/*) relative="usr$filename" ;;
            /etc/OpenCL/vendors/nvidia.icd) relative=usr/share/immutablue/nvidia/nvidia.icd ;;
            /etc/modprobe.d/*) relative="usr/lib/modprobe.d/${filename##*/}" ;;
            /etc/xdg/autostart/*) relative="usr/share/immutablue/nvidia/autostart/${filename##*/}" ;;
            /var/*) continue ;;
            *) echo "Unmapped NVIDIA payload: $filename" >&2; exit 1 ;;
        esac
        [[ "${filename##*/}" != nvidia-fallback.service ]] || continue
        target="$extension/$relative"
        mkdir -p "$(dirname "$target")"
        rm -f "$target"
        cp -a -- "$filename" "$target"
    done < "$stage/files"
done
shopt -s nullglob
module_kernels=("$extension/usr/lib/modules/"*)
[[ ${#module_kernels[@]} == 1 && "${module_kernels[0]##*/}" == "$kernel" ]] || {
    echo "Unexpected module kernels in $branch; expected $kernel" >&2; exit 1;
}
archives=(/usr/share/nvidia*-kmod-*/*.tar.xz)
[[ ${#archives[@]} == 1 ]] || { echo 'Expected exactly one driver source archive' >&2; exit 1; }
tar -xOf "${archives[0]}" supported-gpus/supported-gpus.json > "$stage/gpus"
jq -e --arg branch "$branch" -f "$(dirname "${BASH_SOURCE[0]}")/supported-gpus.jq" \
    "$stage/gpus" > "$output/supported-gpus.json"
suffix=''
[[ "$branch" != 580 ]] || suffix=-580xx
version=$(rpm -q --qf '%{VERSION}' "xorg-x11-drv-nvidia$suffix")
jq -n --arg branch "$branch" --arg version "$version" --arg kernel "$kernel" \
    '{branch:$branch,version:$version,kernel:$kernel}' > "$output/manifest.json"
printf '%s\n' "${!requirements[@]}" | sort -u > "$output/requirements.txt"
