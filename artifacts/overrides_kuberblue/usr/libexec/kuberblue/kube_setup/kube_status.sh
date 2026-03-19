#!/bin/bash
# kube_status.sh — display kuberblue cluster status
#
# Shows topology, node role, node readiness, pod health,
# Flux status, and storage backend.
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh
source /usr/libexec/kuberblue/kube_setup/kube_state.sh

echo "=== Kuberblue Status ==="
echo ""

# Topology and node role
topology="$(kuberblue_topology)"
node_role="$(kuberblue_state_get node-role "$(kuberblue_node_role)")"
cluster_init="$(kuberblue_state_get cluster-initialized "false")"

echo "Topology:            ${topology}"
echo "Node Role:           ${node_role}"
echo "Cluster Initialized: ${cluster_init}"
echo ""

# Storage backend
storage_backend="$(kuberblue_config_get cluster.yaml .storage.backend "hostpath")"
echo "Storage Backend:     ${storage_backend}"
echo ""

# Node readiness
echo "--- Nodes ---"
if command -v kubectl &>/dev/null && kubectl get nodes --no-headers 2>/dev/null; then
    :
else
    echo "  (kubectl unavailable or cluster not reachable)"
fi
echo ""

# Pod health summary
echo "--- Pod Summary ---"
if command -v kubectl &>/dev/null; then
    total="$(kubectl get pods -A --no-headers 2>/dev/null | wc -l || echo 0)"
    running="$(kubectl get pods -A --no-headers --field-selector=status.phase=Running 2>/dev/null | wc -l || echo 0)"
    failed="$(kubectl get pods -A --no-headers --field-selector=status.phase=Failed 2>/dev/null | wc -l || echo 0)"
    pending="$(kubectl get pods -A --no-headers --field-selector=status.phase=Pending 2>/dev/null | wc -l || echo 0)"
    echo "  Total: ${total}  Running: ${running}  Pending: ${pending}  Failed: ${failed}"
else
    echo "  (kubectl unavailable)"
fi
echo ""

# Flux status
echo "--- Flux CD ---"
if kuberblue_state_check "flux-bootstrapped"; then
    echo "  Bootstrapped: true"
    if command -v flux &>/dev/null; then
        flux get all -A --no-header 2>/dev/null || echo "  (flux command failed)"
    else
        echo "  (flux CLI not found)"
    fi
else
    echo "  Bootstrapped: false"
fi
echo ""

# Tailscale status
echo "--- Tailscale ---"
if kuberblue_state_check "tailscale-configured"; then
    echo "  Configured: true"
    if command -v tailscale &>/dev/null; then
        tailscale status 2>/dev/null | head -5 || echo "  (tailscale status failed)"
    fi
else
    echo "  Configured: false"
fi
