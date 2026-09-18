#!/bin/bash
# Resolve the target image kernel before compiling either NVIDIA branch.
set -euo pipefail
base="${1:?Supply the target base image}"
platform="${2:?Supply the target platform}"
override="${3:-}"
if [[ -n "$override" ]]; then
    kernel="$override"
else
    kernel="$(podman run --rm --pull=missing --platform "$platform" --entrypoint rpm "$base" \
        -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n')"
fi
if [[ ! "$kernel" =~ ^[0-9][a-zA-Z0-9._+~-]*-[a-zA-Z0-9._+~]+\.(x86_64|aarch64)$ ]]; then
    echo "ERROR: expected exactly one target kernel, got: $kernel" >&2
    exit 1
fi
printf '%s\n' "$kernel"
