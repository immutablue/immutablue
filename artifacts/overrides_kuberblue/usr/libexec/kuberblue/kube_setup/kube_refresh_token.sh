#!/bin/bash
# kube_refresh_token.sh — generate a new join token and print the join command
#
# Usage: kube_refresh_token.sh [--ttl <duration>]
# Control-plane only.
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh
source /usr/libexec/kuberblue/kube_setup/kube_state.sh

# Parse arguments
TTL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ttl)
            TTL="$2"
            shift 2
            ;;
        *)
            echo "Unknown flag: $1"
            exit 1
            ;;
    esac
done

# Default TTL from config
if [[ -z "${TTL}" ]]; then
    TTL="$(kuberblue_config_get cluster.yaml .cluster.multi.token_ttl "24h")"
fi

# Verify this is a control-plane node
node_role="$(kuberblue_state_get node-role "${KUBERBLUE_NODE_ROLE}")"
if [[ "${node_role}" != "control-plane" ]]; then
    echo "ERROR: refresh-token can only be run on a control-plane node."
    echo "Current node role: ${node_role}"
    exit 1
fi

# Verify cluster is initialized
if ! kuberblue_state_check "cluster-initialized"; then
    echo "ERROR: Cluster is not initialized. Run 'kuberblue init' first."
    exit 1
fi

echo "Generating join token with TTL=${TTL}..."

JOIN_CMD="$(kubeadm token create --print-join-command --ttl "${TTL}")"

# Store join command
JOIN_CMD_FILE="${STATE_DIR}/state/worker-join-command"
mkdir -p "$(dirname "${JOIN_CMD_FILE}")"
printf '%s\n' "${JOIN_CMD}" > "${JOIN_CMD_FILE}"
chmod 0640 "${JOIN_CMD_FILE}"
chown root:kuberblue "${JOIN_CMD_FILE}" 2>/dev/null || true

echo ""
echo "=== Join Command ==="
echo "${JOIN_CMD}"
echo ""
echo "Stored at: ${JOIN_CMD_FILE}"
echo "Token expires in: ${TTL}"
