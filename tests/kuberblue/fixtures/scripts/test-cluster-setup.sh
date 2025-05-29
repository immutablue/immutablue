#!/bin/bash
# Test Cluster Setup Script
#
# This script provides helper functions for setting up test clusters
# Used by Kuberblue integration tests for cluster initialization

# Enable strict error handling
set -euo pipefail

# Constants
readonly TRUE=1
readonly FALSE=0
readonly TEST_CLUSTER_NAME="kuberblue-test"
readonly TEST_NAMESPACE="kuberblue-test"

# Setup test cluster environment
function setup_test_cluster() {
    local cluster_name="${1:-$TEST_CLUSTER_NAME}"
    
    echo "Setting up test cluster: $cluster_name"
    
    # Check if cluster is already running
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "INFO: Cluster already running, using existing cluster"
        return 0
    fi
    
    echo "INFO: No cluster found, setup would initialize cluster here"
    echo "INFO: In actual deployment, this would run kubeadm init"
    
    return 0
}

# Create test namespace with proper labels
function create_test_namespace() {
    local namespace="${1:-$TEST_NAMESPACE}"
    
    echo "Creating test namespace: $namespace"
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace
  labels:
    test: kuberblue
    purpose: testing
    managed-by: kuberblue-test-suite
  annotations:
    test.kuberblue.io/created: "$(date -Iseconds)"
    test.kuberblue.io/purpose: "Kuberblue testing namespace"
EOF

    echo "Test namespace $namespace created successfully"
    return 0
}

# Deploy test workload for validation
function deploy_test_workload() {
    local namespace="${1:-$TEST_NAMESPACE}"
    
    echo "Deploying test workload in namespace: $namespace"
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-workload
  namespace: $namespace
  labels:
    test: kuberblue
    app: test-workload
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-workload
  template:
    metadata:
      labels:
        app: test-workload
        test: kuberblue
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: test-app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: test-workload-service
  namespace: $namespace
  labels:
    test: kuberblue
    app: test-workload
spec:
  selector:
    app: test-workload
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  type: ClusterIP
EOF

    echo "Test workload deployed successfully"
    return 0
}

# Validate test workload is running
function validate_test_workload() {
    local namespace="${1:-$TEST_NAMESPACE}"
    local timeout="${2:-120}"
    
    echo "Validating test workload in namespace: $namespace"
    
    # Wait for deployment to be ready
    if ! kubectl wait --for=condition=available deployment/test-workload -n "$namespace" --timeout="${timeout}s"; then
        echo "ERROR: Test workload failed to become ready"
        return 1
    fi
    
    # Test HTTP connectivity
    local service_ip
    service_ip=$(kubectl get service test-workload-service -n "$namespace" -o jsonpath='{.spec.clusterIP}')
    
    if [[ -n "$service_ip" ]]; then
        echo "Testing HTTP connectivity to service at $service_ip"
        
        local http_response
        http_response=$(kubectl run http-test --image=curlimages/curl --rm -it --restart=Never \
            --namespace="$namespace" --labels="test=kuberblue" \
            -- curl -s -o /dev/null -w "%{http_code}" "http://$service_ip/" 2>&1 || echo "000")
        
        if [[ "$http_response" =~ ^[2-3][0-9][0-9]$ ]]; then
            echo "HTTP connectivity test PASSED (HTTP $http_response)"
        else
            echo "WARNING: HTTP connectivity test failed (HTTP $http_response)"
        fi
    fi
    
    echo "Test workload validation completed"
    return 0
}

# Cleanup test resources
function cleanup_test_resources() {
    local namespace="${1:-$TEST_NAMESPACE}"
    
    echo "Cleaning up test resources in namespace: $namespace"
    
    # Delete all test resources
    kubectl delete all -l "test=kuberblue" -n "$namespace" --ignore-not-found=true || true
    
    # Delete the namespace if it's a test namespace
    if [[ "$namespace" =~ test ]]; then
        kubectl delete namespace "$namespace" --ignore-not-found=true || true
        echo "Test namespace $namespace deleted"
    fi
    
    return 0
}

# Main function for script execution
function main() {
    local action="${1:-help}"
    
    case "$action" in
        "setup")
            setup_test_cluster "${2:-}"
            ;;
        "namespace")
            create_test_namespace "${2:-}"
            ;;
        "deploy")
            deploy_test_workload "${2:-}"
            ;;
        "validate")
            validate_test_workload "${2:-}" "${3:-}"
            ;;
        "cleanup")
            cleanup_test_resources "${2:-}"
            ;;
        "full")
            setup_test_cluster
            create_test_namespace
            deploy_test_workload
            validate_test_workload
            ;;
        "help"|*)
            echo "Usage: $0 {setup|namespace|deploy|validate|cleanup|full} [namespace] [timeout]"
            echo ""
            echo "Commands:"
            echo "  setup     - Setup test cluster"
            echo "  namespace - Create test namespace"
            echo "  deploy    - Deploy test workload"
            echo "  validate  - Validate test workload"
            echo "  cleanup   - Cleanup test resources"
            echo "  full      - Run complete test setup"
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi