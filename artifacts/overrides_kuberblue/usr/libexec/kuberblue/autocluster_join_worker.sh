#!/bin/bash
# Join this node to cluster as a worker (calls existing worker boot script)

set -euo pipefail
source /usr/libexec/kuberblue/99-common.sh

timeout="${1:-300}"
shift || true

# Pass any remaining arguments (like -x for debug) to worker_boot.sh
debug_args="$*"

echo "[INFO] Starting worker node join process..."

# Check if already joined and properly configured
if [[ -f /etc/kubernetes/kubelet.conf ]]; then
    echo "[INFO] Kubelet config exists, checking cluster connection..."
    
    # Ensure kubelet service is running
    if ! systemctl is-active --quiet kubelet; then
        echo "[INFO] Starting kubelet service..."
        systemctl start kubelet
        sleep 5
    fi
    
    if kubectl --kubeconfig=/etc/kubernetes/kubelet.conf get nodes >/dev/null 2>&1; then
        echo "[SUCCESS] Worker is connected to cluster"
        # Ensure advertisement is active
        /usr/libexec/kuberblue/autocluster_advertise.sh worker
        exit 0
    else
        echo "[WARNING] Worker config exists but cannot connect to cluster"
        echo "This might indicate:"
        echo "  - Kubelet service issues: systemctl status kubelet"
        echo "  - Control plane is unreachable"
        echo "  - Certificate/token issues"
        echo "Run 'immutablue kube_autocluster_verify_health' for detailed diagnostics"
        echo
        echo "Proceeding with fresh join attempt..."
    fi
fi

echo "[INFO] Discovering control plane (timeout: ${timeout}s)..."

# Use existing discovery mechanism with timeout
source /usr/libexec/kuberblue/discovery.sh
if ! control_plane_ip=$(wait_for_control_plane "$timeout"); then
    echo "[ERROR] No control plane found within timeout"
    echo "Available control planes can be checked with: immutablue kube_autocluster_discover control-planes"
    exit 1
fi

echo "[INFO] Found control plane at: $control_plane_ip"
echo "[INFO] Joining cluster using existing worker boot process..."

# Use the existing worker boot script which handles all the joining logic
/usr/libexec/kuberblue/worker_boot.sh $debug_args

echo "[SUCCESS] Worker join process complete"
echo "Run 'immutablue kube_autocluster_status' to check status"