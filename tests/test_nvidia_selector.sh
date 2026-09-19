#!/bin/bash
# Exercise production functions with private PCI/config trees and process stubs.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." > /dev/null && pwd)"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
source "$root/artifacts/overrides_cyan/usr/bin/immutablue-nvidia-setup"
STACKS="$fixture/stacks"
CONFIG="$fixture/etc/nvidia.json"
EXTENSIONS="$fixture/extensions"
PCI_DEVICES="$fixture/pci"
mkdir -p "$PCI_DEVICES" "$STACKS/open" "$STACKS/580"
cat > "$fixture/gpus.json" <<'JSON'
{"chips":[
 {"devid":"0x1111","features":[]},
 {"devid":"0x2222","features":["kernelopen","gsp_proprietary_supported"]},
 {"devid":"0x3333","features":["kernelopen"]},
 {"devid":"0x4444","legacybranch":"470.xx","features":[]}
]}
JSON
for branch in open 580; do
    jq -e --arg branch "$branch" -f "$root/deps-container/cyan/supported-gpus.jq" \
        "$fixture/gpus.json" > "$STACKS/$branch/supported-gpus.json"
done
[[ $(jq -c '[.chips[].devid]' "$STACKS/open/supported-gpus.json") == '["0x2222","0x3333"]' ]]
[[ $(jq -c '[.chips[].devid]' "$STACKS/580/supported-gpus.json") == '["0x1111","0x2222"]' ]]
touch "$STACKS/open/manifest.json" "$STACKS/open/immutablue-nvidia.raw" "$STACKS/580/immutablue-nvidia.raw"
gpu() {
    mkdir -p "$PCI_DEVICES/$1"
    printf '%s\n' "${3:-0x10de}" > "$PCI_DEVICES/$1/vendor"
    printf '%s\n' "${4:-0x030000}" > "$PCI_DEVICES/$1/class"
    printf '%s\n' "$2" > "$PCI_DEVICES/$1/device"
}
[[ $(pick) == none ]]
gpu audio 0x9999 0x10de 0x040300
gpu other 0x9999 0x8086
[[ $(pick) == none ]]
gpu modern 0x2222
[[ $(pick) == open ]]
gpu legacy 0x1111
[[ $(pick) == 580 ]]
gpu blackwell 0x3333
if (pick) > /dev/null 2>&1; then echo 'FAIL: mixed open-only and legacy GPUs accepted'; exit 1; fi
rm -r "$PCI_DEVICES/blackwell" "$PCI_DEVICES/modern"
[[ $(pick) == 580 ]]
gpu unknown 0xffff
if (pick) > /dev/null 2>&1; then echo 'FAIL: unknown GPU accepted'; exit 1; fi
rm -r "$PCI_DEVICES/unknown"
rm "$PCI_DEVICES/legacy/device"
if (pick) > /dev/null 2>&1; then echo 'FAIL: PCI read failure treated as no GPU'; exit 1; fi
printf '0x1111\n' > "$PCI_DEVICES/legacy/device"
save open
[[ $(jq -r .driver "$CONFIG") == open ]]
# An interrupted/failed JSON write must not truncate the previous choice.
jq() { if [[ "${FAIL_WRITE:-0}" == 1 ]]; then printf '{'; return 7; fi; command jq "$@"; }
if (FAIL_WRITE=1 save 580); then echo 'FAIL: failed write succeeded'; exit 1; fi
[[ $(jq -r .driver "$CONFIG") == open ]]
[[ $(find "${CONFIG%/*}" -type f | wc -l) == 1 ]]
[[ $(main --status) == "$(cat "$CONFIG")" ]]
for args in '--activate --driver open' '--status --driver none' '--status --garbage' '--driver' '--driver open --driver 580'; do
    read -r -a argv <<< "$args"
    if (main "${argv[@]}") > /dev/null 2>&1; then echo "FAIL: accepted $args"; exit 1; fi
done
trace="$fixture/trace"
systemd-sysext() { echo "sysext $*" >> "$trace"; return "${MERGE_STATUS:-0}"; }
ldconfig() { echo "ldconfig $*" >> "$trace"; }
modprobe() { echo "modprobe $*" >> "$trace"; }
# Launch each activation in a fresh shell so caller conditionals cannot disable
# the executable's errexit behavior. Only the fixture paths/functions are exported.
export STACKS CONFIG EXTENSIONS PCI_DEVICES trace
export -f activate pick gpu_ids ids_supported save fail systemd-sysext ldconfig modprobe jq
bash -euo pipefail -c activate
[[ $(readlink "$EXTENSIONS/immutablue-nvidia.raw") == "$STACKS/open/immutablue-nvidia.raw" ]]
printf 'sysext refresh\nldconfig -X\nmodprobe nvidia_drm\nmodprobe nvidia_uvm\n' > "$fixture/expected"
cmp "$trace" "$fixture/expected"
: > "$trace"
if MERGE_STATUS=9 bash -euo pipefail -c activate; then echo 'FAIL: merge failure ignored'; exit 1; fi
[[ $(cat "$trace") == 'sysext refresh' ]]
: > "$trace"
save none
bash -euo pipefail -c activate
[[ ! -s "$trace" ]]
printf '{broken' > "$CONFIG"
if bash -euo pipefail -c activate 2>/dev/null; then echo 'FAIL: corrupt config accepted'; exit 1; fi
[[ ! -s "$trace" ]]
rm "$CONFIG"
bash -euo pipefail -c activate
[[ $(jq -r .driver "$CONFIG") == 580 ]]
echo 'PASS: NVIDIA detection, atomic persistence, CLI validation and activation failures'
