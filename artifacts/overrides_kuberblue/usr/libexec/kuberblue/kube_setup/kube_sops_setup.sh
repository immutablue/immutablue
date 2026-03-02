#!/bin/bash
# kube_sops_setup.sh
#
# Generates an Age key pair for SOPS-encrypted secret management.
# Run once per cluster, after kubeadm init.
#
# Produces:
#   /var/lib/kuberblue/secrets/age.key  (private, mode 0640 root:kuberblue)
#   /var/lib/kuberblue/secrets/age.pub  (public, mode 0644)
# Also creates a Kubernetes secret in flux-system for Flux to use.
#
# Must be run as root.
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh

if [[ "${KUBERBLUE_SECRETS_ENABLED}" != "true" ]]; then
    echo "SOPS secrets not enabled in secrets.yaml — skipping."
    exit 0
fi

if ! command -v age-keygen &>/dev/null; then
    echo "ERROR: age-keygen not found. Is 'age' package installed?"
    exit 1
fi

SECRETS_DIR="${STATE_DIR}/secrets"
KEY_FILE="${SECRETS_DIR}/age.key"
PUB_FILE="${SECRETS_DIR}/age.pub"

mkdir -p "${SECRETS_DIR}"
chmod 0750 "${SECRETS_DIR}"
chown root:kuberblue "${SECRETS_DIR}"

if [[ -f "${KEY_FILE}" ]]; then
    echo "Age key already exists at ${KEY_FILE} — skipping generation."
else
    echo "Generating new Age key pair..."
    # Restrictive umask so the key file is never world-readable, even briefly
    (
        umask 0077
        age-keygen -o "${KEY_FILE}" 2>&1
    )
fi

# Extract or regenerate public key file
if [[ ! -s "${PUB_FILE}" ]]; then
    grep '^# public key:' "${KEY_FILE}" | sed 's/^# public key: //' > "${PUB_FILE}"
fi

# Validate key was generated
if [[ ! -s "${KEY_FILE}" ]]; then
    echo "ERROR: Age key generation failed — ${KEY_FILE} is empty"
    exit 1
fi
if [[ ! -s "${PUB_FILE}" ]]; then
    echo "ERROR: Could not extract public key from ${KEY_FILE}"
    exit 1
fi

chmod 0640 "${KEY_FILE}"
chmod 0644 "${PUB_FILE}"
chown root:kuberblue "${KEY_FILE}" "${PUB_FILE}"

# Export public key as Kubernetes secret for Flux SOPS decryption
FLUX_NS="$(kuberblue_config_get gitops.yaml .gitops.namespace "flux-system")"

if kubectl get namespace "${FLUX_NS}" &>/dev/null; then
    kubectl create secret generic sops-age \
        --namespace="${FLUX_NS}" \
        --from-file=age.agekey="${KEY_FILE}" \
        --dry-run=client -o yaml | kubectl apply -f - || {
            echo "WARNING: Failed to create SOPS secret in ${FLUX_NS}"
            echo "Run 'kuberblue sops-setup' after Flux is installed to retry."
        }
    echo "SOPS Age secret created in namespace ${FLUX_NS}."
else
    echo "Namespace ${FLUX_NS} not found — SOPS Kubernetes secret deferred."
    echo "Run 'kuberblue sops-setup' after Flux is installed to create it."
fi

PUB_KEY="$(<"${PUB_FILE}")"
echo ""
echo "=== SOPS Setup Complete ==="
echo "Add this public key to .sops.yaml in your GitOps repo:"
echo ""
echo "creation_rules:"
echo "  - path_regex: .*.yaml"
echo "    encrypted_regex: ^(data|stringData)$"
echo "    age: ${PUB_KEY}"
echo ""
