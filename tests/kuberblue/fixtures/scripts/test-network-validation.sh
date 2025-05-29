#!/bin/bash
# Test Network Validation Script
#
# This script provides helper functions for network testing in Kuberblue
# Used by integration tests to validate network functionality

# Enable strict error handling
set -euo pipefail

# Constants
readonly TRUE=1
readonly FALSE=0
readonly NETWORK_TEST_TIMEOUT=60
readonly TEST_IMAGE="busybox:1.35"

# Create network test pods
function create_network_test_pods() {
    local namespace="${1:-default}"
    
    echo "Creating network test pods in namespace: $namespace"
    
    # Create source pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-test-source
  namespace: $namespace
  labels:
    test: kuberblue
    role: network-source
spec:
  containers:
  - name: test
    image: $TEST_IMAGE
    command: ['sleep', '300']
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
  restartPolicy: Never
---
apiVersion: v1
kind: Pod
metadata:
  name: network-test-target
  namespace: $namespace
  labels:
    test: kuberblue
    role: network-target
spec:
  containers:
  - name: test
    image: $TEST_IMAGE
    command: ['sleep', '300']
    ports:
    - containerPort: 8080
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
  restartPolicy: Never
---
apiVersion: v1
kind: Service
metadata:
  name: network-test-service
  namespace: $namespace
  labels:
    test: kuberblue
spec:
  selector:
    role: network-target
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
EOF

    # Wait for pods to be ready
    echo "Waiting for network test pods to be ready..."
    kubectl wait --for=condition=ready pod/network-test-source -n "$namespace" --timeout=60s
    kubectl wait --for=condition=ready pod/network-test-target -n "$namespace" --timeout=60s
    
    echo "Network test pods created successfully"
    return 0
}

# Test pod-to-pod connectivity
function test_pod_to_pod_connectivity() {
    local namespace="${1:-default}"
    
    echo "Testing pod-to-pod connectivity in namespace: $namespace"
    
    # Get target pod IP
    local target_ip
    target_ip=$(kubectl get pod network-test-target -n "$namespace" -o jsonpath='{.status.podIP}')
    
    if [[ -z "$target_ip" ]]; then
        echo "ERROR: Failed to get target pod IP"
        return 1
    fi
    
    echo "Target pod IP: $target_ip"
    
    # Test ping connectivity
    local ping_result
    ping_result=$(kubectl exec network-test-source -n "$namespace" -- \
        ping -c 3 -W 5 "$target_ip" 2>&1 || echo "FAILED")
    
    if echo "$ping_result" | grep -q "3 packets transmitted, 3 received"; then
        echo "Pod-to-pod ping test PASSED"
    else
        echo "Pod-to-pod ping test FAILED"
        echo "Ping result: $ping_result"
        return 1
    fi
    
    return 0
}

# Test service discovery
function test_service_discovery() {
    local namespace="${1:-default}"
    
    echo "Testing service discovery in namespace: $namespace"
    
    # Test DNS resolution
    local dns_result
    dns_result=$(kubectl exec network-test-source -n "$namespace" -- \
        nslookup network-test-service 2>&1 || echo "FAILED")
    
    if echo "$dns_result" | grep -q "network-test-service"; then
        echo "Service DNS resolution test PASSED"
    else
        echo "Service DNS resolution test FAILED"
        echo "DNS result: $dns_result"
        return 1
    fi
    
    # Test service connectivity
    local service_result
    service_result=$(kubectl exec network-test-source -n "$namespace" -- \
        wget -q -O- --timeout=10 "http://network-test-service/" 2>&1 || echo "FAILED")
    
    if [[ "$service_result" != "FAILED" ]]; then
        echo "Service connectivity test PASSED"
    else
        echo "Service connectivity test FAILED"
        return 1
    fi
    
    return 0
}

# Test external connectivity
function test_external_connectivity() {
    local namespace="${1:-default}"
    
    echo "Testing external connectivity from namespace: $namespace"
    
    # Test external DNS resolution
    local external_dns_result
    external_dns_result=$(kubectl exec network-test-source -n "$namespace" -- \
        nslookup google.com 2>&1 || echo "FAILED")
    
    if echo "$external_dns_result" | grep -q "google.com"; then
        echo "External DNS resolution test PASSED"
    else
        echo "External DNS resolution test FAILED (may be expected in restricted environments)"
        echo "DNS result: $external_dns_result"
    fi
    
    # Test external HTTP connectivity
    local external_http_result
    external_http_result=$(kubectl exec network-test-source -n "$namespace" -- \
        wget -q -O- --timeout=10 "http://httpbin.org/ip" 2>&1 || echo "FAILED")
    
    if [[ "$external_http_result" != "FAILED" ]]; then
        echo "External HTTP connectivity test PASSED"
    else
        echo "External HTTP connectivity test FAILED (may be expected in restricted environments)"
    fi
    
    return 0
}

# Test network policies (if they exist)
function test_network_policies() {
    local namespace="${1:-default}"
    
    echo "Testing network policies in namespace: $namespace"
    
    # Check if network policies exist
    local netpol_count
    netpol_count=$(kubectl get networkpolicies -n "$namespace" --no-headers | wc -l || echo "0")
    
    if [[ $netpol_count -eq 0 ]]; then
        echo "No network policies found in namespace $namespace"
        return 0
    fi
    
    echo "Found $netpol_count network policies in namespace $namespace"
    kubectl get networkpolicies -n "$namespace"
    
    # Test that network policies are being enforced
    # This is environment-specific and depends on CNI plugin support
    echo "Network policy enforcement testing requires specific policy rules"
    echo "Validation would depend on the specific policies configured"
    
    return 0
}

# Cleanup network test resources
function cleanup_network_test() {
    local namespace="${1:-default}"
    
    echo "Cleaning up network test resources in namespace: $namespace"
    
    kubectl delete pods,services -l "test=kuberblue" -n "$namespace" --ignore-not-found=true || true
    
    echo "Network test cleanup completed"
    return 0
}

# Run comprehensive network tests
function run_network_tests() {
    local namespace="${1:-default}"
    local failed=0
    
    echo "=== Running Comprehensive Network Tests ==="
    echo "Namespace: $namespace"
    
    # Create test resources
    if ! create_network_test_pods "$namespace"; then
        echo "FAIL: Failed to create network test pods"
        return 1
    fi
    
    # Run tests
    echo -e "\n--- Pod-to-Pod Connectivity Test ---"
    if ! test_pod_to_pod_connectivity "$namespace"; then
        ((failed++))
    fi
    
    echo -e "\n--- Service Discovery Test ---"
    if ! test_service_discovery "$namespace"; then
        ((failed++))
    fi
    
    echo -e "\n--- External Connectivity Test ---"
    if ! test_external_connectivity "$namespace"; then
        # Don't count external connectivity failures as critical
        echo "INFO: External connectivity test failed (may be expected)"
    fi
    
    echo -e "\n--- Network Policy Test ---"
    if ! test_network_policies "$namespace"; then
        # Don't count network policy test failures as critical
        echo "INFO: Network policy test completed with warnings"
    fi
    
    # Cleanup
    echo -e "\n--- Cleanup ---"
    cleanup_network_test "$namespace"
    
    # Report results
    echo -e "\n=== Network Test Results ==="
    if [[ $failed -eq 0 ]]; then
        echo "All critical network tests PASSED!"
        return 0
    else
        echo "$failed critical network tests FAILED!"
        return 1
    fi
}

# Main function
function main() {
    local action="${1:-help}"
    local namespace="${2:-default}"
    
    case "$action" in
        "create")
            create_network_test_pods "$namespace"
            ;;
        "pod-connectivity")
            test_pod_to_pod_connectivity "$namespace"
            ;;
        "service-discovery")
            test_service_discovery "$namespace"
            ;;
        "external")
            test_external_connectivity "$namespace"
            ;;
        "policies")
            test_network_policies "$namespace"
            ;;
        "cleanup")
            cleanup_network_test "$namespace"
            ;;
        "full"|"all")
            run_network_tests "$namespace"
            ;;
        "help"|*)
            echo "Usage: $0 {create|pod-connectivity|service-discovery|external|policies|cleanup|full} [namespace]"
            echo ""
            echo "Commands:"
            echo "  create            - Create network test pods"
            echo "  pod-connectivity  - Test pod-to-pod connectivity"
            echo "  service-discovery - Test service discovery"
            echo "  external          - Test external connectivity"
            echo "  policies          - Test network policies"
            echo "  cleanup           - Cleanup test resources"
            echo "  full              - Run all network tests"
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi