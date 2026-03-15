#!/bin/bash
# kube_override.sh — create a user override for a kuberblue config file
#
# Usage: kube_override.sh <filename>
#   Copies /usr/kuberblue/<filename> to /etc/kuberblue/<filename>
#   Opens in $EDITOR if set, otherwise prints the path.
#   Validates the result is parseable YAML.
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh

if [[ $# -lt 1 ]]; then
    echo "Usage: kuberblue override <filename>"
    echo ""
    echo "Available config files:"
    for f in "${VENDOR_CONFIG_DIR}"/*.yaml; do
        [[ -f "${f}" ]] || continue
        base="$(basename "${f}")"
        if [[ -f "${SYSTEM_CONFIG_DIR}/${base}" ]]; then
            echo "  ${base}  (override exists)"
        else
            echo "  ${base}"
        fi
    done
    exit 1
fi

FILE="$1"
VENDOR_FILE="${VENDOR_CONFIG_DIR}/${FILE}"
OVERRIDE_FILE="${SYSTEM_CONFIG_DIR}/${FILE}"

# Validate source exists
if [[ ! -f "${VENDOR_FILE}" ]]; then
    echo "ERROR: ${VENDOR_FILE} does not exist."
    echo ""
    echo "Available config files:"
    for f in "${VENDOR_CONFIG_DIR}"/*.yaml; do [[ -f "${f}" ]] && basename "${f}"; done
    exit 1
fi

# Create override directory if needed
mkdir -p "${SYSTEM_CONFIG_DIR}"

# Copy if override doesn't exist yet
if [[ ! -f "${OVERRIDE_FILE}" ]]; then
    cp "${VENDOR_FILE}" "${OVERRIDE_FILE}"
    echo "Created override: ${OVERRIDE_FILE}"
else
    echo "Override already exists: ${OVERRIDE_FILE}"
fi

# Open in editor if available
if [[ -n "${EDITOR:-}" ]]; then
    "${EDITOR}" "${OVERRIDE_FILE}"
else
    echo "No \$EDITOR set. Edit the file manually:"
    echo "  ${OVERRIDE_FILE}"
fi

# Validate YAML after editing
if ! yq '.' "${OVERRIDE_FILE}" > /dev/null 2>&1; then
    echo "WARNING: ${OVERRIDE_FILE} is not valid YAML!"
    echo "Fix the syntax before using this config."
    exit 1
fi

echo "Override validated: ${OVERRIDE_FILE}"
