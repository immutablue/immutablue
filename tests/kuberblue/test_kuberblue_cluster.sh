#!/bin/bash
# Kuberblue Cluster Tests
#
# This script tests Kuberblue cluster functionality, including:
# - Cluster initialization with kubeadm
# - Network setup (CNI plugin deployment and testing)
# - Storage setup (OpenEBS deployment and testing)
# - Overall cluster health validation
#
# This test is designed to run in a VM environment (typically QEMU)
# and validates that a complete Kubernetes cluster can be initialized
#
# Usage: ./test_kuberblue_cluster.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference

# Enable strict error handling
set -euo pipefail

echo "Running Kuberblue cluster tests"

# Test variables
IMAGE="${1:-quay.io/immutablue/immutablue:42}"
TEST_DIR="$(dirname "$(realpath "$0")")" 
ROOT_DIR="$(dirname "$(dirname "$TEST_DIR")")"

# Source helper utilities
# shellcheck source=helpers/cluster_utils.sh
source "$TEST_DIR/helpers/cluster_utils.sh"
# shellcheck source=helpers/manifest_utils.sh
source "$TEST_DIR/helpers/manifest_utils.sh"
# shellcheck source=helpers/network_utils.sh
source "$TEST_DIR/helpers/network_utils.sh"

# Test cluster initialization with kubeadm
# Validates that kubeadm can initialize a cluster with Kuberblue configuration
function test_cluster_init() {
    echo "Testing cluster initialization with kubeadm"
    
    # Check if this is running in a suitable environment
    if ! command -v kubeadm >/dev/null 2>&1; then
        echo "SKIP: kubeadm not available, skipping cluster init test"
        return 0
    fi
    
    # Check if cluster is already initialized
    if is_cluster_initialized; then
        echo "INFO: Cluster already initialized, validating existing cluster"
        if validate_cluster_state; then
            echo "PASS: Existing cluster state is valid"
            return 0
        else
            echo "FAIL: Existing cluster state is invalid"
            return 1
        fi
    fi
    
    # Check if kubeadm config exists
    if [[ ! -f "/etc/kuberblue/kubeadm.yaml" ]]; then
        echo "FAIL: Kuberblue kubeadm configuration not found at /etc/kuberblue/kubeadm.yaml"
        return 1
    fi
    
    echo "Initializing Kubernetes cluster with Kuberblue configuration"
    
    # Initialize cluster (this would typically be done by Kuberblue setup scripts)
    # In a real scenario, this would be handled by the on_boot scripts
    if ! sudo kubeadm init --config=/etc/kuberblue/kubeadm.yaml; then
        echo "FAIL: kubeadm init failed"
        return 1
    fi
    
    # Setup kubectl for current user
    mkdir -p "$HOME/.kube"
    sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
    sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
    
    # Wait for cluster to be ready
    if ! wait_for_cluster_ready 300; then
        echo "FAIL: Cluster failed to become ready"
        get_cluster_debug_info
        return 1
    fi
    
    echo "PASS: Cluster initialization succeeded"
    return 0
}

# Test network setup (CNI plugin deployment and functionality)
# Deploys and validates CNI plugin (Cilium or Flannel)
function test_network_setup() {
    echo "Testing network setup and CNI plugin deployment"
    
    # Ensure cluster is initialized
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping network setup test"
        return 0
    fi
    
    # Test CNI plugin functionality
    if ! test_cni_functionality; then
        echo "FAIL: CNI functionality test failed"
        return 1
    fi
    
    # Deploy network manifests from Kuberblue configuration
    local manifests_dir="/etc/kuberblue/manifests"
    
    # Check if Cilium configuration exists and deploy it
    if [[ -d "$manifests_dir/cilium" ]]; then
        echo "Deploying Cilium CNI"
        
        # Validate Cilium manifests
        if ! validate_manifest_directory "$manifests_dir/cilium"; then
            echo "FAIL: Cilium manifest validation failed"
            return 1
        fi
        
        # Deploy Cilium using Helm (if metadata indicates Helm chart)
        if [[ -f "$manifests_dir/cilium/00-metadata.yaml" ]]; then
            if ! validate_helm_deployment "$manifests_dir/cilium" "kube-system" "cilium" "$manifests_dir/cilium/10-values.yaml"; then
                echo "FAIL: Cilium Helm deployment validation failed"
                return 1
            fi
        fi
    elif [[ -f "$manifests_dir/kube-flannel.yaml" ]]; then
        echo "Deploying Flannel CNI"
        
        # Deploy Flannel
        if ! deploy_and_validate_manifest "$manifests_dir/kube-flannel.yaml" "kube-system"; then
            echo "FAIL: Flannel deployment failed"
            return 1
        fi
    else
        echo "WARNING: No CNI configuration found in $manifests_dir"
    fi
    
    # Wait for CNI pods to be ready
    if ! wait_for_pods_ready "kube-system" "k8s-app=cilium" 120; then
        if ! wait_for_pods_ready "kube-system" "app=flannel" 120; then
            echo "WARNING: CNI pods may not be ready"
        fi
    fi
    
    # Test pod-to-pod connectivity
    if ! test_pod_connectivity "default" "kube-system"; then
        echo "FAIL: Pod-to-pod connectivity test failed"
        return 1
    fi
    
    # Test service discovery
    if ! test_service_discovery "default" "kubernetes"; then
        echo "FAIL: Service discovery test failed"
        return 1
    fi
    
    # Test cluster DNS
    if ! test_cluster_dns; then
        echo "FAIL: Cluster DNS test failed"
        return 1
    fi
    
    echo "PASS: Network setup and testing succeeded"
    return 0
}

# Test storage setup (OpenEBS deployment and functionality)
# Deploys OpenEBS and validates storage functionality
function test_storage_setup() {
    echo "Testing storage setup and OpenEBS deployment"
    
    # Ensure cluster is initialized
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping storage setup test"
        return 0
    fi
    
    local manifests_dir="/etc/kuberblue/manifests"
    
    # Check if OpenEBS configuration exists
    if [[ ! -d "$manifests_dir/openebs" ]]; then
        echo "SKIP: OpenEBS configuration not found, skipping storage test"
        return 0
    fi
    
    echo "Deploying OpenEBS storage"
    
    # Validate OpenEBS manifests
    if ! validate_manifest_directory "$manifests_dir/openebs"; then
        echo "FAIL: OpenEBS manifest validation failed"
        return 1
    fi
    
    # Deploy OpenEBS using Helm (if metadata indicates Helm chart)
    if [[ -f "$manifests_dir/openebs/00-metadata.yaml" ]]; then
        if ! deploy_and_validate_helm_chart "$manifests_dir/openebs" "openebs" "openebs" "$manifests_dir/openebs/10-values.yaml" 300; then
            echo "FAIL: OpenEBS Helm deployment failed"
            return 1
        fi
    fi
    
    # Wait for OpenEBS pods to be ready
    if ! wait_for_pods_ready "openebs" "app.kubernetes.io/name=openebs" 180; then
        echo "FAIL: OpenEBS pods failed to become ready"
        return 1
    fi
    
    # Test storage functionality
    echo "Testing storage functionality"
    
    # Create test namespace for storage testing
    ensure_test_namespace "storage-test"
    
    # Create a test PVC and pod to validate storage
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-storage-pvc
  namespace: storage-test
  labels:
    test: kuberblue
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-test
  namespace: storage-test
  labels:
    test: kuberblue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-test
  template:
    metadata:
      labels:
        app: storage-test
        test: kuberblue
    spec:
      containers:
      - name: test
        image: busybox
        command: ['sleep', '3600']
        volumeMounts:
        - name: storage
          mountPath: /data
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: test-storage-pvc
EOF

    # Wait for deployment to be ready
    if ! wait_for_deployment_ready "storage-test" "storage-test" 120; then
        echo "FAIL: Storage test deployment failed to become ready"
        return 1
    fi
    
    # Test data persistence
    echo "Testing data persistence"
    kubectl exec deployment/storage-test -n storage-test -- sh -c "echo 'test data' > /data/test.txt"
    
    # Restart pod and verify data persists
    kubectl delete pod -n storage-test -l app=storage-test
    if ! wait_for_deployment_ready "storage-test" "storage-test" 120; then
        echo "FAIL: Storage test pod failed to restart"
        return 1
    fi
    
    # Verify data persistence
    local stored_data
    stored_data=$(kubectl exec deployment/storage-test -n storage-test -- cat /data/test.txt 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "$stored_data" == "test data" ]]; then
        echo "PASS: Data persistence test succeeded"
    else
        echo "FAIL: Data persistence test failed - data not found after pod restart"
        return 1
    fi
    
    # Clean up storage test resources
    kubectl delete namespace storage-test --ignore-not-found=true || true
    
    echo "PASS: Storage setup and testing succeeded"
    return 0
}

# Test overall cluster health
# Validates that all system components are running and healthy
function test_cluster_health() {
    echo "Testing overall cluster health"
    
    # Ensure cluster is initialized
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping health test"
        return 0
    fi
    
    # Validate cluster state
    if ! validate_cluster_state; then
        echo "FAIL: Cluster state validation failed"
        return 1
    fi
    
    # Check system pods
    echo "Checking system pods health"
    local failed_system_pods
    failed_system_pods=$(kubectl get pods -n kube-system --no-headers | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" | wc -l || echo "0")
    
    if [[ $failed_system_pods -gt 0 ]]; then
        echo "FAIL: $failed_system_pods system pods are in failed state"
        kubectl get pods -n kube-system | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" || true
        return 1
    fi
    
    # Check node status
    echo "Checking node status"
    local not_ready_nodes
    not_ready_nodes=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l || echo "0")
    
    if [[ $not_ready_nodes -gt 0 ]]; then
        echo "FAIL: $not_ready_nodes nodes are not ready"
        kubectl get nodes
        return 1
    fi
    
    # Check API server responsiveness
    echo "Checking API server responsiveness"
    if ! kubectl get --raw /healthz >/dev/null 2>&1; then
        echo "FAIL: API server health check failed"
        return 1
    fi
    
    # Check if kuberblue user exists and has proper kubectl access
    if id kuberblue >/dev/null 2>&1; then
        echo "Checking kuberblue user kubectl access"
        if ! sudo -u kuberblue kubectl cluster-info >/dev/null 2>&1; then
            echo "FAIL: kuberblue user cannot access cluster"
            return 1
        fi
    else
        echo "INFO: kuberblue user not found (may be created on first login)"
    fi
    
    # Check if required services are running
    echo "Checking required services"
    local required_services=("kubelet" "crio")
    
    for service in "${required_services[@]}"; do
        if ! systemctl is-active "$service" >/dev/null 2>&1; then
            echo "FAIL: Service $service is not active"
            systemctl status "$service" || true
            return 1
        fi
    done
    
    echo "PASS: Cluster health check succeeded"
    return 0
}

# Main test execution
echo "=== Running Kuberblue Cluster Tests ==="
FAILED=0

# Check if we're in an environment suitable for cluster testing
if [[ "${KUBERBLUE_CLUSTER_TEST:-0}" != "1" ]]; then
    echo "INFO: Set KUBERBLUE_CLUSTER_TEST=1 to enable cluster testing"
    echo "SKIP: Cluster tests require VM environment"
    exit 0
fi

# Execute each test and track failures
if ! test_cluster_init; then
    ((FAILED++))
fi

if ! test_network_setup; then
    ((FAILED++))
fi

if ! test_storage_setup; then
    ((FAILED++))
fi

if ! test_cluster_health; then
    ((FAILED++))
fi

# Clean up any remaining test resources
cleanup_test_resources "default" || true
cleanup_network_test_resources || true

# Report test results
echo "=== Kuberblue Cluster Test Results ==="
if [[ $FAILED -eq 0 ]]; then
    echo "All Kuberblue cluster tests PASSED!"
    exit 0
else
    echo "$FAILED Kuberblue cluster tests FAILED!"
    
    # Get debug information on failure
    echo "=== Debug Information ==="
    get_cluster_debug_info
    get_network_debug_info
    
    exit 1
fi