#!/bin/bash
# kube_reset.sh — full cluster reset for kuberblue
#
# Drains node (if multi-node), runs kubeadm reset, clears all state,
# removes kubeconfig, cleans CNI state, and flushes iptables.
#
# Usage: kube_reset.sh [--force] [--purge-secrets]
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh
source /usr/libexec/kuberblue/kube_setup/kube_state.sh

FORCE=false
PURGE_SECRETS=false

for arg in "$@"; do
    case "${arg}" in
        --force) FORCE=true ;;
        --purge-secrets) PURGE_SECRETS=true ;;
        *) echo "Unknown flag: ${arg}"; exit 1 ;;
    esac
done

kuberblue_load_all

FIRST_BOOT_MARKER="/etc/kuberblue/did_first_boot"
ADMIN_USER="${KUBERBLUE_ADMIN_USER}"

# Confirmation prompt unless --force
if [[ "${FORCE}" != "true" ]]; then
    echo "WARNING: This will completely reset the Kubernetes cluster on this node."
    echo "All workloads, state markers, and local kubeconfig will be removed."
    if [[ "${PURGE_SECRETS}" == "true" ]]; then
        echo "SOPS secrets will also be purged."
    fi
    echo ""
    read -r -p "Type 'yes' to confirm: " confirm
    if [[ "${confirm}" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "=== Kuberblue Reset ==="

# Step 1: Drain node if multi-node topology
node_role="$(kuberblue_state_get node-role "")"
topology="${KUBERBLUE_TOPOLOGY}"

if [[ "${topology}" == "multi" || "${topology}" == "ha" ]]; then
    node_name="$(hostname)"
    if command -v kubectl &>/dev/null && kubectl get nodes &>/dev/null 2>&1; then
        echo "Draining node ${node_name}..."
        kubectl drain "${node_name}" \
            --ignore-daemonsets \
            --delete-emptydir-data \
            --force \
            --timeout=120s 2>/dev/null || echo "WARNING: Node drain failed or timed out (continuing)"
    fi
fi

# Step 2: kubeadm reset
echo "Running kubeadm reset..."
kubeadm reset --force 2>/dev/null || echo "WARNING: kubeadm reset returned non-zero (may already be reset)"

# Step 3: Remove first-boot marker
echo "Removing first-boot marker..."
rm -f "${FIRST_BOOT_MARKER}"

# Step 4: Clear ALL state markers
echo "Clearing state markers..."
if [[ -d "${KUBERBLUE_STATE_DIR}" ]]; then
    rm -rf "${KUBERBLUE_STATE_DIR}"
fi

# Step 5: Remove kuberblue user kubeconfig
echo "Removing kubeconfig..."
if id "${ADMIN_USER}" &>/dev/null; then
    admin_home="$(getent passwd "${ADMIN_USER}" | cut -d: -f6)"
    rm -rf "${admin_home}/.kube/config"
fi
rm -rf /root/.kube/config

# Step 6: Clean CNI state (Flannel + Cilium)
echo "Cleaning CNI state..."
rm -rf /etc/cni/net.d/*
rm -rf /run/flannel/
rm -rf /var/lib/cni/
rm -rf /var/run/cilium/
rm -rf /sys/fs/bpf/tc/
rm -rf /var/lib/cilium/

# Step 7: Flush iptables rules
echo "Flushing iptables rules..."
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -X 2>/dev/null || true
ip6tables -F 2>/dev/null || true
ip6tables -t nat -F 2>/dev/null || true
ip6tables -t mangle -F 2>/dev/null || true
ip6tables -X 2>/dev/null || true

# Step 8: Optionally purge secrets
if [[ "${PURGE_SECRETS}" == "true" ]]; then
    echo "Purging SOPS secrets..."
    rm -rf "${STATE_DIR}/secrets/"
fi

# Step 9: Clean generated configs
echo "Cleaning generated configs..."
rm -rf "${STATE_DIR}/generated/"

echo ""
echo "=== Reset complete ==="
echo "Reboot to reinitialize the cluster, or run 'kuberblue init' manually."
