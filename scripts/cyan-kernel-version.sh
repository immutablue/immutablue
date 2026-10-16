#!/bin/bash
# Resolve the target image kernel before compiling either NVIDIA branch.
set -euo pipefail
base="${1:?Supply the target base image}"
platform="${2:?Supply the target platform}"
override="${3:-}"
package="${4:-kernel}"
fedora="${5:-}"
lts="${6:-}"
if [[ -n "$override" ]]; then
    kernel="$override"
elif [[ "$package" == kernel-longterm ]]; then
    [[ -n "$fedora" && -n "$lts" ]] || {
        echo 'ERROR: kernel-longterm needs Fedora and LTS versions' >&2
        exit 1
    }
    kernel="$(podman run --rm --pull=missing --platform "$platform" --entrypoint bash \
        "registry.fedoraproject.org/fedora:${fedora}" -lc "
        set -euo pipefail
        dnf -y install dnf-plugins-core >/dev/null
        dnf -y copr enable kwizart/kernel-longterm-${lts} >/dev/null
        dnf -q repoquery --latest-limit=1 --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-longterm.\$(uname -m)
    ")"
else
    kernel="$(podman run --rm --pull=missing --platform "$platform" --entrypoint rpm "$base" \
        -q "$package" --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n')"
fi
if [[ ! "$kernel" =~ ^[0-9][a-zA-Z0-9._+~-]*-[a-zA-Z0-9._+~]+\.(x86_64|aarch64)$ ]]; then
    echo "ERROR: expected exactly one target kernel, got: $kernel" >&2
    exit 1
fi
printf '%s\n' "$kernel"
