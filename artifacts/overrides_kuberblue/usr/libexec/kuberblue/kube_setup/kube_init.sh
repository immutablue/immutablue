#!/bin/bash
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh

STATE_DIR="${STATE_DIR:-/var/lib/kuberblue}"
mkdir -p "${STATE_DIR}"

# Step 1: Generate the runtime kubeadm config from /usr/kuberblue/ + /etc/ overrides
/usr/libexec/kuberblue/kube_setup/kube_generate_kubeadm_config.sh

GENERATED_KUBEADM="${STATE_DIR}/kubeadm-generated.yaml"
INIT_LOG="${STATE_DIR}/kubeadm-init.log"

if [[ ! -f "${GENERATED_KUBEADM}" ]]; then
    echo "ERROR: ${GENERATED_KUBEADM} not found. kube_generate_kubeadm_config.sh failed?"
    exit 1
fi

# Validate the generated config is parseable YAML
if ! yq '.' "${GENERATED_KUBEADM}" > /dev/null 2>&1; then
    echo "ERROR: Generated kubeadm config is not valid YAML"
    exit 1
fi

# Step 2: Run kubeadm init
# --skip-phases=addon/kube-proxy: Cilium replaces kube-proxy entirely.
# This is correct and intentional — Cilium handles proxy functionality.
if ! kubeadm init \
    --skip-phases=addon/kube-proxy \
    --config "${GENERATED_KUBEADM}" \
    | tee "${INIT_LOG}"; then
    echo "ERROR: kubeadm init failed (see ${INIT_LOG})"
    exit 1
fi

echo "kubeadm init complete. Log: ${INIT_LOG}"
