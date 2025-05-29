#!/bin/bash
# Kuberblue Cluster Utilities
#
# Helper functions for managing Kubernetes clusters in Kuberblue tests
# Provides utilities for cluster initialization, cleanup, and state validation
#
# Usage: source this file from test scripts to access utility functions

# Enable strict error handling
set -euo pipefail

# Constants
readonly TRUE=1
readonly FALSE=0
readonly CLUSTER_READY_TIMEOUT=300
readonly POD_READY_TIMEOUT=120

# Wait for cluster components to be ready
# Args: timeout_seconds (optional, defaults to CLUSTER_READY_TIMEOUT)
# Returns: 0 if cluster is ready, 1 if timeout or error
function wait_for_cluster_ready() {
    local timeout="${1:-$CLUSTER_READY_TIMEOUT}"
    local start_time
    start_time=$(date +%s)
    
    echo "Waiting for cluster to be ready (timeout: ${timeout}s)"
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            echo "ERROR: Cluster ready timeout after ${timeout}s"
            return 1
        fi
        
        # Check if kubectl is responding
        if kubectl cluster-info >/dev/null 2>&1; then
            # Check if all nodes are ready
            local not_ready_nodes
            not_ready_nodes=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l || echo "0")
            
            if [[ $not_ready_nodes -eq 0 ]]; then
                # Check if system pods are running
                local system_pods_ready
                system_pods_ready=$(kubectl get pods -n kube-system --no-headers | grep -E "(Running|Completed)" | wc -l || echo "0")
                local total_system_pods
                total_system_pods=$(kubectl get pods -n kube-system --no-headers | wc -l || echo "1")
                
                if [[ $system_pods_ready -eq $total_system_pods && $total_system_pods -gt 0 ]]; then
                    echo "Cluster is ready (elapsed: ${elapsed}s)"
                    return 0
                fi
            fi
        fi
        
        echo "Cluster not ready yet (elapsed: ${elapsed}s)..."
        sleep 10
    done
}

# Wait for specific pods to be ready
# Args: namespace pod_selector timeout_seconds
# Returns: 0 if pods are ready, 1 if timeout or error
function wait_for_pods_ready() {
    local namespace="$1"
    local pod_selector="$2"
    local timeout="${3:-$POD_READY_TIMEOUT}"
    local start_time
    start_time=$(date +%s)
    
    echo "Waiting for pods in namespace '$namespace' with selector '$pod_selector' to be ready"
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            echo "ERROR: Pod ready timeout after ${timeout}s"
            kubectl get pods -n "$namespace" -l "$pod_selector" || true
            return 1
        fi
        
        # Check if pods exist and are ready
        local ready_pods
        ready_pods=$(kubectl get pods -n "$namespace" -l "$pod_selector" --no-headers 2>/dev/null | grep " Running " | wc -l || echo "0")
        local total_pods
        total_pods=$(kubectl get pods -n "$namespace" -l "$pod_selector" --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [[ $total_pods -gt 0 && $ready_pods -eq $total_pods ]]; then
            echo "Pods are ready (elapsed: ${elapsed}s)"
            return 0
        fi
        
        echo "Pods not ready yet: $ready_pods/$total_pods (elapsed: ${elapsed}s)..."
        sleep 5
    done
}

# Clean up test resources from cluster
# Args: namespace (optional, defaults to default)
# Returns: 0 on success, 1 on error
function cleanup_test_resources() {
    local namespace="${1:-default}"
    
    echo "Cleaning up test resources in namespace '$namespace'"
    
    # Clean up test deployments
    kubectl delete deployments -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
    
    # Clean up test services
    kubectl delete services -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
    
    # Clean up test pods
    kubectl delete pods -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
    
    # Clean up test PVCs
    kubectl delete pvc -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
    
    # Clean up test configmaps
    kubectl delete configmaps -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
    
    # Clean up test secrets
    kubectl delete secrets -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
    
    # Wait for resources to be actually deleted
    local cleanup_timeout=60
    local start_time
    start_time=$(date +%s)
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $cleanup_timeout ]]; then
            echo "WARNING: Cleanup timeout after ${cleanup_timeout}s"
            break
        fi
        
        local remaining_resources
        remaining_resources=$(kubectl get all -n "$namespace" -l "test=kuberblue" --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [[ $remaining_resources -eq 0 ]]; then
            echo "Test resources cleaned up successfully"
            return 0
        fi
        
        echo "Waiting for ${remaining_resources} test resources to be deleted..."
        sleep 5
    done
    
    return 0
}

# Validate cluster is in expected state
# Returns: 0 if cluster state is valid, 1 if issues found
function validate_cluster_state() {
    echo "Validating cluster state"
    local issues=0
    
    # Check if kubectl is accessible
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "ERROR: kubectl cannot access cluster"
        ((issues++))
    fi
    
    # Check node status
    local not_ready_nodes
    not_ready_nodes=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l || echo "0")
    if [[ $not_ready_nodes -gt 0 ]]; then
        echo "ERROR: $not_ready_nodes nodes are not ready"
        kubectl get nodes
        ((issues++))
    fi
    
    # Check system pods
    local failed_pods
    failed_pods=$(kubectl get pods -n kube-system --no-headers | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" | wc -l || echo "0")
    if [[ $failed_pods -gt 0 ]]; then
        echo "ERROR: $failed_pods system pods are in failed state"
        kubectl get pods -n kube-system | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" || true
        ((issues++))
    fi
    
    # Check DNS resolution
    if ! kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default >/dev/null 2>&1; then
        echo "ERROR: DNS resolution test failed"
        ((issues++))
    else
        echo "DNS resolution test passed"
    fi
    
    # Check if API server is responding
    if ! kubectl get --raw /healthz >/dev/null 2>&1; then
        echo "ERROR: API server health check failed"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "Cluster state validation passed"
        return 0
    else
        echo "Cluster state validation failed with $issues issues"
        return 1
    fi
}

# Get cluster information for debugging
# Returns: always 0 (best effort)
function get_cluster_debug_info() {
    echo "=== Cluster Debug Information ==="
    
    echo "--- Cluster Info ---"
    kubectl cluster-info || true
    
    echo "--- Node Status ---"
    kubectl get nodes -o wide || true
    
    echo "--- System Pods ---"
    kubectl get pods -n kube-system -o wide || true
    
    echo "--- System Services ---"
    kubectl get svc -n kube-system || true
    
    echo "--- Events ---"
    kubectl get events --sort-by='.lastTimestamp' | tail -20 || true
    
    echo "--- Component Status ---"
    kubectl get componentstatuses || true
    
    return 0
}

# Check if cluster is initialized
# Returns: 0 if initialized, 1 if not
function is_cluster_initialized() {
    if kubectl cluster-info >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wait for deployment to be ready
# Args: namespace deployment_name timeout_seconds
# Returns: 0 if deployment is ready, 1 if timeout or error
function wait_for_deployment_ready() {
    local namespace="$1"
    local deployment_name="$2"
    local timeout="${3:-$POD_READY_TIMEOUT}"
    
    echo "Waiting for deployment '$deployment_name' in namespace '$namespace' to be ready"
    
    if kubectl wait --for=condition=available deployment/"$deployment_name" -n "$namespace" --timeout="${timeout}s"; then
        echo "Deployment '$deployment_name' is ready"
        return 0
    else
        echo "ERROR: Deployment '$deployment_name' failed to become ready"
        kubectl describe deployment "$deployment_name" -n "$namespace" || true
        return 1
    fi
}

# Create test namespace if it doesn't exist
# Args: namespace_name
# Returns: 0 on success, 1 on error
function ensure_test_namespace() {
    local namespace_name="$1"
    
    if ! kubectl get namespace "$namespace_name" >/dev/null 2>&1; then
        echo "Creating namespace '$namespace_name'"
        kubectl create namespace "$namespace_name"
    else
        echo "Namespace '$namespace_name' already exists"
    fi
    
    return 0
}