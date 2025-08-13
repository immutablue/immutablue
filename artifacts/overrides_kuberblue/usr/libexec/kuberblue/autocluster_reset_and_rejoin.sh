#!/bin/bash
# Reset kubelet config and attempt fresh join

set -euo pipefail
source /usr/libexec/kuberblue/99-common.sh

timeout="${1:-300}"
shift || true

# Pass any remaining arguments (like -x for debug) to worker_boot.sh
debug_args="$*"

echo "[INFO] Resetting worker node and attempting fresh join..."

# Use kubeadm reset for proper cleanup of all kubernetes files
echo "[INFO] Performing kubeadm reset to clean up all kubernetes configuration..."
if command -v kubeadm >/dev/null 2>&1; then
    kubeadm reset --force 2>/dev/null || true
    echo "[INFO] kubeadm reset completed"
else
    echo "[WARNING] kubeadm not found, falling back to manual cleanup..."
    systemctl stop kubelet 2>/dev/null || true
    rm -f /etc/kubernetes/kubelet.conf 2>/dev/null || true
    rm -f /etc/kubernetes/bootstrap-kubelet.conf 2>/dev/null || true
    rm -f /etc/kubernetes/pki/ca.crt 2>/dev/null || true
    rm -rf /var/lib/kubelet/* 2>/dev/null || true
fi

# Clean up discovery cache
rm -f /tmp/kuberblue_discovery_cache 2>/dev/null || true

# Remove existing advertisements
echo "[INFO] Removing existing mDNS advertisements..."
rm -f /etc/avahi/services/kuberblue-worker.service 2>/dev/null || true
systemctl reload avahi-daemon 2>/dev/null || true

# Discover control plane
echo "[INFO] Discovering control plane (timeout: ${timeout}s)..."
source /usr/libexec/kuberblue/discovery.sh
if ! control_plane_ip=$(wait_for_control_plane "$timeout"); then
    echo "[ERROR] No control plane found within timeout"
    echo "Available nodes:"
    /usr/libexec/kuberblue/autocluster_debug_discovery.sh
    exit 1
fi

echo "[INFO] Found control plane at: $control_plane_ip"

# Verify this is not our own IP
local_ips=$(ip -4 addr show | grep -E "inet.*scope global" | awk '{print $2}' | cut -d'/' -f1)
if echo "$local_ips" | grep -q "^$control_plane_ip$"; then
    echo "[ERROR] Control plane IP ($control_plane_ip) matches this node's IP!"
    echo "This indicates a discovery or configuration problem."
    echo "This node's IPs: $local_ips"
    exit 1
fi

echo "[INFO] Attempting fresh join to control plane at $control_plane_ip..."

# Use the existing worker boot script for joining
/usr/libexec/kuberblue/worker_boot.sh $debug_args

echo "[SUCCESS] Fresh join complete"
echo "Run 'immutablue kube_autocluster_status' to verify connection"