#!/bin/bash
# kube_sops.sh — encrypt or decrypt files using SOPS with the cluster Age key
#
# Usage:
#   kube_sops.sh encrypt <file> [<file>...]
#   kube_sops.sh decrypt <file> [<file>...]
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh

if [[ $# -lt 2 ]]; then
    echo "Usage:"
    echo "  kuberblue encrypt <file> [<file>...]"
    echo "  kuberblue decrypt <file> [<file>...]"
    exit 1
fi

ACTION="$1"
shift

if [[ "${ACTION}" != "encrypt" && "${ACTION}" != "decrypt" ]]; then
    echo "ERROR: Unknown action '${ACTION}'. Use 'encrypt' or 'decrypt'."
    exit 1
fi

# Validate sops is installed
if ! command -v sops &>/dev/null; then
    echo "ERROR: sops not found. Install it first."
    exit 1
fi

# Read Age key path from config
AGE_KEY_FILE="$(kuberblue_config_get security.yaml .security.sops.age_key_path "/var/lib/kuberblue/secrets/age.key")"

if [[ ! -f "${AGE_KEY_FILE}" ]]; then
    echo "ERROR: Age key not found at ${AGE_KEY_FILE}"
    echo "Run 'kuberblue init' first, or set security.sops.age_key_path in security.yaml"
    exit 1
fi

export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"

# For encryption, we also need the public key (recipient)
if [[ "${ACTION}" == "encrypt" ]]; then
    AGE_PUB_FILE="${AGE_KEY_FILE%.key}.pub"
    if [[ -f "${AGE_PUB_FILE}" ]]; then
        AGE_RECIPIENT="$(<"${AGE_PUB_FILE}")"
    else
        # Extract from key file
        AGE_RECIPIENT="$(grep '^# public key:' "${AGE_KEY_FILE}" | sed 's/^# public key: //')"
    fi

    if [[ -z "${AGE_RECIPIENT}" ]]; then
        echo "ERROR: Could not determine Age public key for encryption."
        exit 1
    fi
fi

for file in "$@"; do
    if [[ ! -f "${file}" ]]; then
        echo "ERROR: File not found: ${file}"
        continue
    fi

    echo "${ACTION^}ing ${file}..."
    if [[ "${ACTION}" == "encrypt" ]]; then
        sops --encrypt --age "${AGE_RECIPIENT}" --in-place "${file}"
    else
        sops --decrypt --in-place "${file}"
    fi
    echo "  Done: ${file}"
done
