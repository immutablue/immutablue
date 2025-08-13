#!/bin/bash
# Show current autocluster status and role

set -euo pipefail

echo "Kuberblue Autocluster Status"
echo "============================"

# Determine role
role="unknown"
status="unknown"
cluster_connected="false"

if [[ -f /etc/kubernetes/admin.conf ]]; then
    role="control-plane"
    if kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes >/dev/null 2>&1; then
        cluster_connected="true"
    fi
elif [[ -f /etc/kubernetes/kubelet.conf ]]; then
    role="worker"
    if kubectl --kubeconfig=/etc/kubernetes/kubelet.conf get nodes >/dev/null 2>&1; then
        cluster_connected="true"
    fi
fi

# Determine status
if [[ -f /etc/kuberblue/did_first_boot ]]; then
    if [[ "$cluster_connected" == "true" ]]; then
        status="ready"
    else
        status="initialized-disconnected"
    fi
else
    status="not-initialized"
fi

# Check mDNS services
advertised_services=""
if [[ -f /etc/avahi/services/kuberblue-control-plane.service ]]; then
    advertised_services="control-plane"
fi
if [[ -f /etc/avahi/services/kuberblue-worker.service ]]; then
    if [[ -n "$advertised_services" ]]; then
        advertised_services="$advertised_services,worker"
    else
        advertised_services="worker"
    fi
fi

echo "Node Role: $role"
echo "Status: $status"
echo "Cluster Connected: $cluster_connected"
echo "Advertised Services: ${advertised_services:-none}"
echo "Hostname: $(hostname)"
echo "First Boot Complete: $(if [[ -f /etc/kuberblue/did_first_boot ]]; then echo "yes"; else echo "no"; fi)"

# Show cluster nodes if control plane and connected
if [[ "$role" == "control-plane" && "$cluster_connected" == "true" ]]; then
    echo
    echo "Cluster Nodes:"
    kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes 2>/dev/null || echo "Failed to get nodes"
fi