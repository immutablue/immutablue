#!/bin/bash
# Immunablue: Standalone image verification script
# Verifies cosign signatures against all maintainer public keys.
#
# Usage: ./immunablue/verify.sh <image_reference>
# Example: ./immunablue/verify.sh quay.io/immutablue/immutablue:43
set -euo pipefail

IMAGE="${1:?Usage: verify.sh <image_reference>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBKEY_DIR="${SCRIPT_DIR}"

echo "=== Immunablue Image Verification ==="
echo "Image: ${IMAGE}"
echo ""

if ! command -v cosign &>/dev/null; then
    echo "ERROR: cosign is not installed."
    echo "Install: https://docs.sigstore.dev/cosign/system_config/installation/"
    exit 1
fi

# Collect all .pub files in the immunablue directory
PUBKEYS=("${PUBKEY_DIR}"/*.pub)
if [[ ${#PUBKEYS[@]} -eq 0 ]]; then
    echo "ERROR: No public key files (*.pub) found in ${PUBKEY_DIR}"
    exit 1
fi

VERIFIED=0

for key in "${PUBKEYS[@]}"; do
    keyname="$(basename "${key}")"
    echo -n "Checking signature with ${keyname}... "
    if cosign verify --key "${key}" "${IMAGE}" &>/dev/null; then
        echo "VERIFIED"
        VERIFIED=1
    else
        echo "no match"
    fi
done

echo ""
if [[ ${VERIFIED} -eq 1 ]]; then
    echo "Result: Image signature VERIFIED"
    exit 0
else
    echo "Result: FAILED — no valid signature found"
    echo "The image was not signed by any known maintainer key."
    exit 1
fi
