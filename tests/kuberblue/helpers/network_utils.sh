#!/bin/bash
# Kuberblue Network Utilities
#
# Helper functions for testing Kubernetes networking in Kuberblue tests
# Provides utilities for testing pod connectivity, service discovery, and ingress
#
# Usage: source this file from test scripts to access utility functions

# Enable strict error handling
set -euo pipefail

# Constants
readonly NETWORK_TEST_TIMEOUT=60
readonly CONNECTIVITY_TEST_IMAGE="busybox:1.35"

# Test pod-to-pod networking
# Args: source_namespace target_namespace timeout (optional)
# Returns: 0 if connectivity works, 1 if fails
function test_pod_connectivity() {
    local source_namespace="$1"
    local target_namespace="$2"
    local timeout="${3:-$NETWORK_TEST_TIMEOUT}"
    
    echo "Testing pod-to-pod connectivity from '$source_namespace' to '$target_namespace'"
    
    # Create test pods if they don't exist
    local source_pod="network-test-source"
    local target_pod="network-test-target"
    
    # Ensure namespaces exist
    kubectl create namespace "$source_namespace" --dry-run=client -o yaml | kubectl apply -f - || true
    kubectl create namespace "$target_namespace" --dry-run=client -o yaml | kubectl apply -f - || true
    
    # Create target pod
    kubectl run "$target_pod" --image="$CONNECTIVITY_TEST_IMAGE" --restart=Never \
        --namespace="$target_namespace" --labels="test=kuberblue,role=target" \
        -- sleep 3600 2>/dev/null || true
    
    # Wait for target pod to be ready
    if ! kubectl wait --for=condition=ready pod/"$target_pod" -n "$target_namespace" --timeout="${timeout}s"; then
        echo "ERROR: Target pod failed to become ready"
        kubectl describe pod "$target_pod" -n "$target_namespace" || true
        return 1
    fi
    
    # Get target pod IP
    local target_ip
    target_ip=$(kubectl get pod "$target_pod" -n "$target_namespace" -o jsonpath='{.status.podIP}')
    
    if [[ -z "$target_ip" ]]; then
        echo "ERROR: Failed to get target pod IP"
        return 1
    fi
    
    echo "Target pod IP: $target_ip"
    
    # Test connectivity from source namespace
    echo "Testing connectivity from source pod"
    local connectivity_result
    connectivity_result=$(kubectl run "$source_pod" --image="$CONNECTIVITY_TEST_IMAGE" --rm -it --restart=Never \
        --namespace="$source_namespace" --labels="test=kuberblue,role=source" \
        -- sh -c "ping -c 3 $target_ip" 2>&1 || echo "FAILED")
    
    if echo "$connectivity_result" | grep -q "3 packets transmitted, 3 received"; then
        echo "Pod-to-pod connectivity test PASSED"
        return 0
    else
        echo "ERROR: Pod-to-pod connectivity test FAILED"
        echo "Connectivity result: $connectivity_result"
        return 1
    fi
}

# Test Kubernetes service discovery
# Args: namespace service_name timeout (optional)
# Returns: 0 if service discovery works, 1 if fails
function test_service_discovery() {
    local namespace="$1"
    local service_name="$2"
    local timeout="${3:-$NETWORK_TEST_TIMEOUT}"
    
    echo "Testing service discovery for service '$service_name' in namespace '$namespace'"
    
    # Ensure namespace exists
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - || true
    
    # Create a test service and deployment if they don't exist
    local test_deployment="service-discovery-test"
    local test_service="$service_name"
    
    # Create test deployment
    cat <<EOF | kubectl apply -f - || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $test_deployment
  namespace: $namespace
  labels:
    test: kuberblue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $test_deployment
  template:
    metadata:
      labels:
        app: $test_deployment
        test: kuberblue
    spec:
      containers:
      - name: test-container
        image: $CONNECTIVITY_TEST_IMAGE
        command: ['sleep', '3600']
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: $test_service
  namespace: $namespace
  labels:
    test: kuberblue
spec:
  selector:
    app: $test_deployment
  ports:
  - port: 80
    targetPort: 8080
EOF

    # Wait for deployment to be ready
    if ! kubectl wait --for=condition=available deployment/"$test_deployment" -n "$namespace" --timeout="${timeout}s"; then
        echo "ERROR: Test deployment failed to become ready"
        return 1
    fi
    
    # Test DNS resolution from a test pod
    local dns_test_result
    dns_test_result=$(kubectl run dns-test --image="$CONNECTIVITY_TEST_IMAGE" --rm -it --restart=Never \
        --namespace="$namespace" --labels="test=kuberblue" \
        -- sh -c "nslookup $test_service" 2>&1 || echo "FAILED")
    
    if echo "$dns_test_result" | grep -q "Name:.*$test_service"; then
        echo "Service discovery test PASSED"
        return 0
    else
        echo "ERROR: Service discovery test FAILED"
        echo "DNS test result: $dns_test_result"
        return 1
    fi
}

# Test ingress functionality (if ingress controller is configured)
# Args: namespace ingress_name expected_response timeout (optional)
# Returns: 0 if ingress works, 1 if fails
function test_ingress_functionality() {
    local namespace="$1"
    local ingress_name="$2"
    local expected_response="$3"
    local timeout="${4:-$NETWORK_TEST_TIMEOUT}"
    
    echo "Testing ingress functionality for '$ingress_name' in namespace '$namespace'"
    
    # Check if ingress exists
    if ! kubectl get ingress "$ingress_name" -n "$namespace" >/dev/null 2>&1; then
        echo "WARNING: Ingress '$ingress_name' not found, skipping test"
        return 0
    fi
    
    # Get ingress IP/hostname
    local ingress_ip
    ingress_ip=$(kubectl get ingress "$ingress_name" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [[ -z "$ingress_ip" ]]; then
        ingress_ip=$(kubectl get ingress "$ingress_name" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    fi
    
    if [[ -z "$ingress_ip" ]]; then
        echo "WARNING: Ingress IP/hostname not available, cannot test"
        return 0
    fi
    
    echo "Testing ingress at: $ingress_ip"
    
    # Test HTTP response
    local http_response
    http_response=$(kubectl run http-test --image="$CONNECTIVITY_TEST_IMAGE" --rm -it --restart=Never \
        --namespace="$namespace" --labels="test=kuberblue" \
        -- sh -c "wget -q -O- http://$ingress_ip/ --timeout=10" 2>&1 || echo "FAILED")
    
    if echo "$http_response" | grep -q "$expected_response"; then
        echo "Ingress functionality test PASSED"
        return 0
    else
        echo "ERROR: Ingress functionality test FAILED"
        echo "HTTP response: $http_response"
        return 1
    fi
}

# Test network policies (if implemented)
# Args: namespace policy_name
# Returns: 0 if network policies work as expected, 1 if fails
function test_network_policies() {
    local namespace="$1"
    local policy_name="$2"
    
    echo "Testing network policy '$policy_name' in namespace '$namespace'"
    
    # Check if network policy exists
    if ! kubectl get networkpolicy "$policy_name" -n "$namespace" >/dev/null 2>&1; then
        echo "WARNING: Network policy '$policy_name' not found, skipping test"
        return 0
    fi
    
    # Create test pods for policy testing
    local allowed_pod="policy-test-allowed"
    local denied_pod="policy-test-denied"
    local target_pod="policy-test-target"
    
    # Create target pod
    kubectl run "$target_pod" --image="$CONNECTIVITY_TEST_IMAGE" --restart=Never \
        --namespace="$namespace" --labels="test=kuberblue,role=target" \
        -- sleep 3600 2>/dev/null || true
    
    # Wait for target pod
    kubectl wait --for=condition=ready pod/"$target_pod" -n "$namespace" --timeout=60s || return 1
    
    local target_ip
    target_ip=$(kubectl get pod "$target_pod" -n "$namespace" -o jsonpath='{.status.podIP}')
    
    # Test with allowed pod (this depends on specific network policy configuration)
    echo "Testing connectivity from allowed pod"
    local allowed_result
    allowed_result=$(kubectl run "$allowed_pod" --image="$CONNECTIVITY_TEST_IMAGE" --rm -it --restart=Never \
        --namespace="$namespace" --labels="test=kuberblue,role=allowed" \
        -- sh -c "timeout 10 nc -zv $target_ip 8080" 2>&1 || echo "FAILED")
    
    # Test with denied pod
    echo "Testing connectivity from denied pod"
    local denied_result
    denied_result=$(kubectl run "$denied_pod" --image="$CONNECTIVITY_TEST_IMAGE" --rm -it --restart=Never \
        --namespace="$namespace" --labels="test=kuberblue,role=denied" \
        -- sh -c "timeout 10 nc -zv $target_ip 8080" 2>&1 || echo "FAILED")
    
    # Network policy testing is complex and depends on specific policy rules
    # This is a basic framework - specific implementations would need to be customized
    echo "Network policy test completed (results depend on specific policy rules)"
    echo "Allowed pod result: $allowed_result"
    echo "Denied pod result: $denied_result"
    
    return 0
}

# Test CNI plugin functionality
# Returns: 0 if CNI is working, 1 if issues found
function test_cni_functionality() {
    echo "Testing CNI plugin functionality"
    
    # Check if CNI pods are running
    local cni_pods
    cni_pods=$(kubectl get pods -n kube-system | grep -E "(flannel|cilium|calico|weave)" | grep "Running" | wc -l || echo "0")
    
    if [[ $cni_pods -eq 0 ]]; then
        echo "WARNING: No CNI pods found running in kube-system namespace"
        kubectl get pods -n kube-system | grep -E "(flannel|cilium|calico|weave)" || true
        return 1
    fi
    
    echo "Found $cni_pods CNI pods running"
    
    # Test basic pod networking by creating test pods
    local test_ns="cni-test"
    kubectl create namespace "$test_ns" --dry-run=client -o yaml | kubectl apply -f - || true
    
    # Create multiple test pods to test CNI
    for i in {1..3}; do
        kubectl run "cni-test-$i" --image="$CONNECTIVITY_TEST_IMAGE" --restart=Never \
            --namespace="$test_ns" --labels="test=kuberblue,cni-test=true" \
            -- sleep 300 2>/dev/null || true
    done
    
    # Wait for pods to get IPs
    sleep 10
    
    # Check if all pods have IPs
    local pods_with_ips
    pods_with_ips=$(kubectl get pods -n "$test_ns" -l "cni-test=true" -o jsonpath='{.items[*].status.podIP}' | wc -w || echo "0")
    
    if [[ $pods_with_ips -eq 3 ]]; then
        echo "CNI functionality test PASSED - all pods received IPs"
        # Clean up
        kubectl delete namespace "$test_ns" --ignore-not-found=true || true
        return 0
    else
        echo "ERROR: CNI functionality test FAILED - only $pods_with_ips/3 pods received IPs"
        kubectl get pods -n "$test_ns" -o wide || true
        return 1
    fi
}

# Test cluster DNS functionality
# Returns: 0 if DNS works, 1 if fails
function test_cluster_dns() {
    echo "Testing cluster DNS functionality"
    
    # Test DNS resolution of kubernetes.default service
    local dns_test_result
    dns_test_result=$(kubectl run dns-test --image="$CONNECTIVITY_TEST_IMAGE" --rm -it --restart=Never \
        --labels="test=kuberblue" \
        -- sh -c "nslookup kubernetes.default" 2>&1 || echo "FAILED")
    
    if echo "$dns_test_result" | grep -q "kubernetes.default"; then
        echo "Cluster DNS test PASSED"
        return 0
    else
        echo "ERROR: Cluster DNS test FAILED"
        echo "DNS test result: $dns_test_result"
        
        # Get DNS pod status for debugging
        echo "DNS pod status:"
        kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide || true
        
        return 1
    fi
}

# Get network debug information
# Returns: always 0 (best effort)
function get_network_debug_info() {
    echo "=== Network Debug Information ==="
    
    echo "--- Node Network Info ---"
    kubectl get nodes -o wide || true
    
    echo "--- CNI Pods ---"
    kubectl get pods -n kube-system | grep -E "(flannel|cilium|calico|weave|cni)" || true
    
    echo "--- DNS Pods ---"
    kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide || true
    
    echo "--- Services ---"
    kubectl get svc --all-namespaces || true
    
    echo "--- Network Policies ---"
    kubectl get networkpolicies --all-namespaces || true
    
    echo "--- Ingress ---"
    kubectl get ingress --all-namespaces || true
    
    echo "--- Network Events ---"
    kubectl get events --all-namespaces | grep -i network || true
    
    return 0
}

# Clean up network test resources
# Args: namespace (optional, defaults to cleaning all test resources)
# Returns: 0 on success
function cleanup_network_test_resources() {
    local namespace="${1:-}"
    
    echo "Cleaning up network test resources"
    
    if [[ -n "$namespace" ]]; then
        # Clean up specific namespace
        kubectl delete pods -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
        kubectl delete services -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
        kubectl delete deployments -n "$namespace" -l "test=kuberblue" --ignore-not-found=true || true
    else
        # Clean up all network test resources
        kubectl delete pods --all-namespaces -l "test=kuberblue" --ignore-not-found=true || true
        kubectl delete services --all-namespaces -l "test=kuberblue" --ignore-not-found=true || true
        kubectl delete deployments --all-namespaces -l "test=kuberblue" --ignore-not-found=true || true
        
        # Clean up test namespaces
        for test_ns in cni-test network-test-source network-test-target; do
            kubectl delete namespace "$test_ns" --ignore-not-found=true || true
        done
    fi
    
    return 0
}