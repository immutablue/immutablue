#!/bin/bash
# 05-immunablue.sh
#
# Immunablue pre-flight verification.
# Runs before other build scripts to validate the hardened build environment.
# If immunablue is not in BUILD_OPTIONS, this script exits cleanly.

set -euxo pipefail

# Check if immunablue is enabled (can't source 99-common.sh yet — 10-copy.sh hasn't run)
if [[ ! ",${IMMUTABLUE_BUILD_OPTIONS:-}," == *",immunablue,"* ]]; then
    echo "=== Immunablue not enabled, skipping pre-flight ==="
    exit 0
fi

echo "=== IMMUNABLUE: Running pre-flight checks ==="

CHECKSUMS_FILE="/mnt-ctx/immunablue/checksums.yaml"
DIGESTS_FILE="/mnt-ctx/immunablue/pinned-digests.yaml"

# 1. Verify checksums.yaml exists
if [[ ! -f "$CHECKSUMS_FILE" ]]; then
    echo "IMMUNABLUE FATAL: immunablue/checksums.yaml not found"
    echo "This file is required for verified binary downloads."
    exit 1
fi
echo "IMMUNABLUE: checksums.yaml found"

# 2. Verify pinned-digests.yaml exists
if [[ ! -f "$DIGESTS_FILE" ]]; then
    echo "IMMUNABLUE FATAL: immunablue/pinned-digests.yaml not found"
    echo "This file is required for base image digest verification."
    exit 1
fi
echo "IMMUNABLUE: pinned-digests.yaml found"

# 3. Verify yq is available (needed for checksum lookups)
if [[ -x /mnt-yq/yq ]]; then
    echo "IMMUNABLUE: yq available at /mnt-yq/yq"
elif command -v yq &>/dev/null; then
    echo "IMMUNABLUE: yq available in PATH"
else
    echo "IMMUNABLUE FATAL: yq not found — required for checksum verification"
    exit 1
fi

echo "IMMUNABLUE: Pre-flight checks passed"
