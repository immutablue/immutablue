#!/bin/bash
# Initialize this node as a control plane (calls existing initialization scripts)

set -euo pipefail
source /usr/libexec/kuberblue/99-common.sh

echo "[INFO] Initializing control plane..."

# Check if already initialized
if [[ -f /etc/kubernetes/admin.conf ]]; then
    echo "[INFO] Control plane already initialized, verifying health..."
    if kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes >/dev/null 2>&1; then
        echo "[SUCCESS] Control plane is healthy"
    else
        echo "[WARNING] Control plane appears unhealthy - consider running 'immutablue autocluster_verify_health'"
    fi
    
    # Ensure advertisement is active
    /usr/libexec/kuberblue/autocluster_advertise.sh control-plane
    exit 0
fi

# Run the standard control plane initialization (same as first_boot_control_plane.sh)
echo "[INFO] Running cluster initialization..."
/usr/libexec/kuberblue/kube_setup/kube_init.sh

echo "[INFO] Waiting for cluster to be ready..."
export KUBECONFIG=/etc/kubernetes/admin.conf
sleep 5
wait_for_node_ready_state

echo "[INFO] Running post-installation setup..."
/usr/libexec/kuberblue/kube_setup/kube_post_install.sh

echo "[INFO] Creating control plane mDNS advertisement..."
/usr/libexec/kuberblue/create_control_plane_service.sh

echo "[SUCCESS] Control plane initialization complete"
echo "Run 'immutablue kube_autocluster_status' to check status"