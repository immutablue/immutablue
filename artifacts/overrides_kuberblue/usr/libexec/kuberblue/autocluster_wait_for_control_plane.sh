#!/bin/bash
# Wait for control plane to be discovered via mDNS

set -euo pipefail
source /usr/libexec/kuberblue/discovery.sh

timeout="${1:-300}"

echo "[INFO] Waiting for control plane (timeout: ${timeout}s)..."

if control_plane_ip=$(wait_for_control_plane "$timeout"); then
    echo "[SUCCESS] Control plane found at: $control_plane_ip"
    echo "$control_plane_ip"
else
    echo "[ERROR] No control plane found within timeout"
    echo "Try running 'immutablue kube_autocluster_discover control-planes' to see current status"
    exit 1
fi