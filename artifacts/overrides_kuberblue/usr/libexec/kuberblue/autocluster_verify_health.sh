#!/bin/bash
# Verify cluster connectivity and health

set -euo pipefail

echo "[INFO] Verifying cluster health..."

if [[ -f /etc/kubernetes/admin.conf ]]; then
    # Control plane health check
    echo "[INFO] Checking control plane health..."
    
    # Check if kubelet is running (required on control plane too)
    if ! systemctl is-active --quiet kubelet; then
        echo "[WARNING] Kubelet service is not running on control plane"
        echo "Starting kubelet service..."
        systemctl start kubelet 2>/dev/null || echo "Failed to start kubelet - check permissions"
        sleep 3
    fi
    
    if kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes >/dev/null 2>&1; then
        echo "[SUCCESS] Control plane is healthy"
        
        # Show detailed cluster info
        echo
        echo "Cluster Information:"
        kubectl --kubeconfig=/etc/kubernetes/admin.conf cluster-info 2>/dev/null || echo "Could not get cluster info"
        
        echo
        echo "Node Status:"
        kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide 2>/dev/null || echo "Could not get node status"
        
        # Check if core pods are running
        echo
        echo "Core System Pods:"
        kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -n kube-system --field-selector=status.phase=Running 2>/dev/null | grep -E "(kube-apiserver|kube-controller|kube-scheduler|etcd)" || echo "Could not check system pods"
        
    else
        echo "[ERROR] Control plane health check failed"
        echo "Try checking:"
        echo "  - Is the kubelet service running? systemctl status kubelet"
        echo "  - Are there any errors in kubelet logs? journalctl -u kubelet"
        echo "  - Is the API server accessible? kubectl cluster-info"
        exit 1
    fi
    
elif [[ -f /etc/kubernetes/kubelet.conf ]]; then
    # Worker health check
    echo "[INFO] Checking worker health..."
    
    # Check if kubelet is running (required on workers)
    if ! systemctl is-active --quiet kubelet; then
        echo "[WARNING] Kubelet service is not running on worker"
        echo "Starting kubelet service..."
        systemctl start kubelet 2>/dev/null || echo "Failed to start kubelet - check permissions"
        sleep 3
    fi
    
    if kubectl --kubeconfig=/etc/kubernetes/kubelet.conf get nodes >/dev/null 2>&1; then
        echo "[SUCCESS] Worker is healthy and connected to cluster"
        
        # Show node status
        echo
        echo "This Node Status:"
        kubectl --kubeconfig=/etc/kubernetes/kubelet.conf get node "$(hostname)" -o wide 2>/dev/null || echo "Could not get node status"
        
    else
        echo "[ERROR] Worker health check failed"
        echo "Try checking:"
        echo "  - Is the kubelet service running? systemctl status kubelet"  
        echo "  - Can the worker reach the control plane?"
        echo "  - Are there any errors in kubelet logs? journalctl -u kubelet"
        exit 1
    fi
    
else
    echo "[ERROR] Node is not initialized as control plane or worker"
    echo "Configuration files not found:"
    echo "  - Control plane: /etc/kubernetes/admin.conf"
    echo "  - Worker: /etc/kubernetes/kubelet.conf"
    echo
    echo "Has the node completed first boot? Check: ls -la /etc/kuberblue/did_first_boot"
    exit 1
fi