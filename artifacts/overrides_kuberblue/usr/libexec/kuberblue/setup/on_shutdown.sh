#!/bin/bash
# on_shutdown.sh — graceful Kubernetes node shutdown
#
# Cordons and drains the node so pods can migrate before the machine stops.
# Called by the kuberblue-shutdown systemd unit (ExecStop / Before=shutdown.target).
set -euo pipefail

source /usr/libexec/kuberblue/variables.sh

export KUBECONFIG="/etc/kubernetes/admin.conf"
DRAIN_TIMEOUT="${KUBERBLUE_DRAIN_TIMEOUT:-60s}"

echo "=== Kuberblue shutdown: draining node ==="

NODE_NAME="$(hostname)"

# Verify kubectl is available and the cluster is reachable
if ! command -v kubectl &>/dev/null; then
    echo "kubectl not found — skipping drain."
    exit 0
fi

if ! kubectl get nodes "${NODE_NAME}" --no-headers &>/dev/null 2>&1; then
    echo "Cannot reach API server or node ${NODE_NAME} not found — skipping drain."
    exit 0
fi

# Step 1: Cordon the node (mark unschedulable)
echo "Cordoning node ${NODE_NAME}..."
if ! kubectl cordon "${NODE_NAME}"; then
    echo "WARNING: Failed to cordon node ${NODE_NAME}. Continuing with drain attempt."
fi

# Step 2: Drain the node
#   --ignore-daemonsets: DaemonSet pods run on every node; don't block on them
#   --delete-emptydir-data: allow eviction of pods using emptyDir volumes
#   --timeout: don't block shutdown indefinitely
echo "Draining node ${NODE_NAME} (timeout=${DRAIN_TIMEOUT})..."
if kubectl drain "${NODE_NAME}" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout="${DRAIN_TIMEOUT}" 2>&1; then
    echo "Node ${NODE_NAME} drained successfully."
else
    echo "WARNING: Drain did not complete cleanly (timeout or errors). Proceeding with shutdown."
fi

echo "=== Kuberblue shutdown complete ==="
