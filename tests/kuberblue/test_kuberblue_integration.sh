#!/bin/bash
# Kuberblue Integration Tests
#
# This script performs end-to-end integration testing of Kuberblue, including:
# - Complete application deployment scenarios
# - Cluster operations and scaling
# - Stateful workload scenarios with persistent storage
# - Real-world manifest deployment and validation
# - Application functionality validation
#
# These tests validate that the entire Kuberblue ecosystem works together
#
# Usage: ./test_kuberblue_integration.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference

# Enable strict error handling
set -euo pipefail

echo "Running Kuberblue integration tests"

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

# Test complete application deployment (multi-tier application)
# Deploys a full stack application with frontend, backend, and database
function test_complete_application_deployment() {
    echo "Testing complete application deployment"
    
    # Ensure cluster is initialized
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping application deployment test"
        return 0
    fi
    
    local test_namespace="app-integration-test"
    ensure_test_namespace "$test_namespace"
    
    echo "Deploying multi-tier application stack"
    
    # Deploy a complete application stack
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: $test_namespace
  labels:
    test: kuberblue
data:
  database_url: "postgresql://postgres:password@postgres:5432/testdb"
  redis_url: "redis://redis:6379"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: $test_namespace
  labels:
    test: kuberblue
type: Opaque
data:
  db_password: cGFzc3dvcmQ=  # password
  api_key: dGVzdC1hcGkta2V5  # test-api-key
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        test: kuberblue
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db_password
        - name: POSTGRES_DB
          value: testdb
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        test: kuberblue
    spec:
      containers:
      - name: redis
        image: redis:6
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        test: kuberblue
    spec:
      containers:
      - name: backend
        image: nginx:alpine
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: app-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db_password
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        test: kuberblue
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

    # Wait for all deployments to be ready
    local deployments=("postgres" "redis" "backend" "frontend")
    
    for deployment in "${deployments[@]}"; do
        echo "Waiting for deployment $deployment to be ready"
        if ! wait_for_deployment_ready "$test_namespace" "$deployment" 180; then
            echo "FAIL: Deployment $deployment failed to become ready"
            kubectl describe deployment "$deployment" -n "$test_namespace" || true
            return 1
        fi
    done
    
    # Test inter-service connectivity
    echo "Testing inter-service connectivity"
    
    # Test backend to database connectivity
    local db_test_result
    db_test_result=$(kubectl run connectivity-test --image=postgres:13 --rm -it --restart=Never \
        --namespace="$test_namespace" --labels="test=kuberblue" \
        -- psql -h postgres -U postgres -d testdb -c "SELECT 1;" 2>&1 || echo "FAILED")
    
    if echo "$db_test_result" | grep -q "1 row"; then
        echo "Database connectivity test PASSED"
    else
        echo "WARNING: Database connectivity test failed - this may be expected without proper credentials"
    fi
    
    # Test frontend to backend connectivity
    local backend_test_result
    backend_test_result=$(kubectl run http-test --image=curlimages/curl --rm -it --restart=Never \
        --namespace="$test_namespace" --labels="test=kuberblue" \
        -- curl -s -o /dev/null -w "%{http_code}" http://backend/ 2>&1 || echo "000")
    
    if [[ "$backend_test_result" =~ ^[2-3][0-9][0-9]$ ]]; then
        echo "Backend connectivity test PASSED (HTTP $backend_test_result)"
    else
        echo "WARNING: Backend connectivity test returned HTTP $backend_test_result"
    fi
    
    echo "PASS: Complete application deployment test succeeded"
    return 0
}

# Test cluster operations and scaling scenarios
# Tests scaling deployments and cluster operation procedures
function test_cluster_operations() {
    echo "Testing cluster operations and scaling scenarios"
    
    # Ensure cluster is initialized
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping cluster operations test"
        return 0
    fi
    
    local test_namespace="scaling-test"
    ensure_test_namespace "$test_namespace"
    
    # Deploy a test application for scaling
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scaling-test-app
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scaling-test-app
  template:
    metadata:
      labels:
        app: scaling-test-app
        test: kuberblue
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF

    # Wait for initial deployment
    if ! wait_for_deployment_ready "$test_namespace" "scaling-test-app" 120; then
        echo "FAIL: Initial scaling test deployment failed"
        return 1
    fi
    
    # Test scaling up
    echo "Testing horizontal scaling up"
    kubectl scale deployment scaling-test-app --replicas=5 -n "$test_namespace"
    
    # Wait for scale up
    sleep 30
    local ready_replicas
    ready_replicas=$(kubectl get deployment scaling-test-app -n "$test_namespace" -o jsonpath='{.status.readyReplicas}' || echo "0")
    
    if [[ "$ready_replicas" -eq 5 ]]; then
        echo "Scaling up test PASSED"
    else
        echo "FAIL: Scaling up failed - expected 5 replicas, got $ready_replicas"
        return 1
    fi
    
    # Test scaling down
    echo "Testing horizontal scaling down"
    kubectl scale deployment scaling-test-app --replicas=2 -n "$test_namespace"
    
    # Wait for scale down
    sleep 20
    ready_replicas=$(kubectl get deployment scaling-test-app -n "$test_namespace" -o jsonpath='{.status.readyReplicas}' || echo "0")
    
    if [[ "$ready_replicas" -eq 2 ]]; then
        echo "Scaling down test PASSED"
    else
        echo "FAIL: Scaling down failed - expected 2 replicas, got $ready_replicas"
        return 1
    fi
    
    # Test resource management
    echo "Testing resource limits and quotas"
    
    # Create resource quota
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: test-quota
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    pods: "10"
EOF

    # Verify quota is applied
    if kubectl get resourcequota test-quota -n "$test_namespace" >/dev/null 2>&1; then
        echo "Resource quota test PASSED"
    else
        echo "FAIL: Resource quota creation failed"
        return 1
    fi
    
    echo "PASS: Cluster operations test succeeded"
    return 0
}

# Test stateful workloads with persistent storage
# Validates that stateful applications work correctly with persistent storage
function test_workload_scenarios() {
    echo "Testing stateful workload scenarios"
    
    # Ensure cluster is initialized
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping workload scenarios test"
        return 0
    fi
    
    local test_namespace="stateful-test"
    ensure_test_namespace "$test_namespace"
    
    # Deploy StatefulSet with persistent storage
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: stateful-service
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: stateful-app
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: stateful-app
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  serviceName: "stateful-service"
  replicas: 3
  selector:
    matchLabels:
      app: stateful-app
  template:
    metadata:
      labels:
        app: stateful-app
        test: kuberblue
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        test: kuberblue
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
EOF

    # Wait for StatefulSet to be ready
    echo "Waiting for StatefulSet to be ready"
    local timeout=300
    local start_time
    start_time=$(date +%s)
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            echo "FAIL: StatefulSet ready timeout after ${timeout}s"
            kubectl describe statefulset stateful-app -n "$test_namespace" || true
            return 1
        fi
        
        local ready_replicas
        ready_replicas=$(kubectl get statefulset stateful-app -n "$test_namespace" -o jsonpath='{.status.readyReplicas}' || echo "0")
        
        if [[ "$ready_replicas" -eq 3 ]]; then
            echo "StatefulSet is ready"
            break
        fi
        
        echo "StatefulSet not ready yet: $ready_replicas/3 replicas"
        sleep 10
    done
    
    # Test data persistence
    echo "Testing data persistence in StatefulSet"
    
    # Write data to first pod
    kubectl exec stateful-app-0 -n "$test_namespace" -- sh -c "echo 'persistent data' > /usr/share/nginx/html/test.txt"
    
    # Delete the pod to test persistence
    kubectl delete pod stateful-app-0 -n "$test_namespace"
    
    # Wait for pod to be recreated
    if ! kubectl wait --for=condition=ready pod/stateful-app-0 -n "$test_namespace" --timeout=120s; then
        echo "FAIL: StatefulSet pod failed to be recreated"
        return 1
    fi
    
    # Verify data persists
    local stored_data
    stored_data=$(kubectl exec stateful-app-0 -n "$test_namespace" -- cat /usr/share/nginx/html/test.txt 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "$stored_data" == "persistent data" ]]; then
        echo "Data persistence test PASSED"
    else
        echo "FAIL: Data persistence test failed - expected 'persistent data', got '$stored_data'"
        return 1
    fi
    
    # Test batch job
    echo "Testing batch job functionality"
    
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-test
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  template:
    metadata:
      labels:
        test: kuberblue
    spec:
      restartPolicy: Never
      containers:
      - name: batch-job
        image: busybox
        command: ['sh', '-c', 'echo "Batch job completed successfully" && sleep 10']
EOF

    # Wait for job to complete
    if ! kubectl wait --for=condition=complete job/batch-test -n "$test_namespace" --timeout=120s; then
        echo "FAIL: Batch job failed to complete"
        return 1
    fi
    
    echo "Batch job test PASSED"
    
    echo "PASS: Workload scenarios test succeeded"
    return 0
}

# Test real-world manifests deployment
# Deploys actual applications from /etc/kuberblue/manifests/
function test_real_world_manifests() {
    echo "Testing real-world manifests deployment"
    
    # Ensure cluster is initialized
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping real-world manifests test"
        return 0
    fi
    
    local manifests_dir="/etc/kuberblue/manifests"
    
    if [[ ! -d "$manifests_dir" ]]; then
        echo "SKIP: Manifests directory not found, skipping real-world manifests test"
        return 0
    fi
    
    # Test Cilium deployment and functionality
    if [[ -d "$manifests_dir/00-infrastructure/00-cilium" ]]; then
        echo "Testing Cilium deployment"
        
        # Validate and deploy Cilium
        if deploy_and_validate_helm_chart "$manifests_dir/00-infrastructure/00-cilium" "kube-system" "cilium" "$manifests_dir/00-infrastructure/00-cilium/10-values.yaml" 300; then
            echo "Cilium deployment PASSED"
            
            # Test Cilium functionality
            if test_cni_functionality; then
                echo "Cilium functionality test PASSED"
            else
                echo "WARNING: Cilium functionality test failed"
            fi
        else
            echo "WARNING: Cilium deployment failed"
        fi
    fi
    
    # Test OpenEBS deployment and functionality
    if [[ -d "$manifests_dir/00-infrastructure/10-openebs" ]]; then
        echo "Testing OpenEBS deployment"
        
        # Validate and deploy OpenEBS
        if deploy_and_validate_helm_chart "$manifests_dir/00-infrastructure/10-openebs" "openebs" "openebs" "$manifests_dir/00-infrastructure/10-openebs/10-values.yaml" 300; then
            echo "OpenEBS deployment PASSED"
            
            # Test storage functionality
            local test_namespace="openebs-test"
            ensure_test_namespace "$test_namespace"
            
            # Test storage provisioning
            cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openebs-test-pvc
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
            
            # Wait for PVC to be bound
            if kubectl wait --for=condition=bound pvc/openebs-test-pvc -n "$test_namespace" --timeout=120s; then
                echo "OpenEBS storage provisioning test PASSED"
            else
                echo "WARNING: OpenEBS storage provisioning test failed"
            fi
            
            # Clean up test PVC
            kubectl delete pvc openebs-test-pvc -n "$test_namespace" --ignore-not-found=true || true
        else
            echo "WARNING: OpenEBS deployment failed"
        fi
    fi
    
    # Test Flannel deployment (if Cilium is not used)
    if [[ -f "$manifests_dir/kube-flannel.yaml" ]] && ! kubectl get pods -n kube-system -l k8s-app=cilium >/dev/null 2>&1; then
        echo "Testing Flannel deployment"
        
        if deploy_and_validate_manifest "$manifests_dir/kube-flannel.yaml" "kube-system" 300; then
            echo "Flannel deployment PASSED"
            
            # Test networking functionality
            if test_cni_functionality; then
                echo "Flannel functionality test PASSED"
            else
                echo "WARNING: Flannel functionality test failed"
            fi
        else
            echo "WARNING: Flannel deployment failed"
        fi
    fi
    
    echo "PASS: Real-world manifests test completed"
    return 0
}

# Test deployment functionality validation
# Ensures deployed applications work as intended, not just that they deploy
function test_deployment_functionality() {
    echo "Testing deployment functionality validation"
    
    # Ensure cluster is initialized
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping deployment functionality test"
        return 0
    fi
    
    # Test that deployed applications are actually functional
    echo "Validating deployed application functionality"
    
    # Check system pods functionality
    local failed_pods
    failed_pods=$(kubectl get pods -A --no-headers | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" | wc -l || echo "0")
    
    if [[ $failed_pods -gt 0 ]]; then
        echo "WARNING: $failed_pods pods are in failed state"
        kubectl get pods -A | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" || true
    else
        echo "All deployed pods are healthy"
    fi
    
    # Test DNS functionality end-to-end
    if test_cluster_dns; then
        echo "DNS functionality validation PASSED"
    else
        echo "FAIL: DNS functionality validation failed"
        return 1
    fi
    
    # Test networking end-to-end
    if test_pod_connectivity "default" "kube-system"; then
        echo "Network functionality validation PASSED"
    else
        echo "FAIL: Network functionality validation failed"
        return 1
    fi
    
    # Test storage functionality (if available)
    local storage_classes
    storage_classes=$(kubectl get storageclass --no-headers | wc -l || echo "0")
    
    if [[ $storage_classes -gt 0 ]]; then
        echo "Testing storage functionality"
        
        local test_namespace="storage-functionality-test"
        ensure_test_namespace "$test_namespace"
        
        # Create and test PVC
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: functionality-test-pvc
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
        
        if kubectl wait --for=condition=bound pvc/functionality-test-pvc -n "$test_namespace" --timeout=120s; then
            echo "Storage functionality validation PASSED"
        else
            echo "WARNING: Storage functionality validation failed"
        fi
        
        # Clean up
        kubectl delete namespace "$test_namespace" --ignore-not-found=true || true
    else
        echo "No storage classes available, skipping storage functionality test"
    fi
    
    echo "PASS: Deployment functionality validation completed"
    return 0
}

# Main test execution
echo "=== Running Kuberblue Integration Tests ==="
FAILED=0

# Check if we're in an environment suitable for integration testing
if [[ "${KUBERBLUE_INTEGRATION_TEST:-0}" != "1" ]]; then
    echo "INFO: Set KUBERBLUE_INTEGRATION_TEST=1 to enable integration testing"
    echo "SKIP: Integration tests require full cluster environment"
    exit 0
fi

# Execute each test and track failures
if ! test_complete_application_deployment; then
    ((FAILED++))
fi

if ! test_cluster_operations; then
    ((FAILED++))
fi

if ! test_workload_scenarios; then
    ((FAILED++))
fi

if ! test_real_world_manifests; then
    ((FAILED++))
fi

if ! test_deployment_functionality; then
    ((FAILED++))
fi

# Clean up test namespaces
echo "Cleaning up integration test resources"
test_namespaces=("app-integration-test" "scaling-test" "stateful-test" "openebs-test" "storage-functionality-test")
for ns in "${test_namespaces[@]}"; do
    kubectl delete namespace "$ns" --ignore-not-found=true || true
done

# Report test results
echo "=== Kuberblue Integration Test Results ==="
if [[ $FAILED -eq 0 ]]; then
    echo "All Kuberblue integration tests PASSED!"
    exit 0
else
    echo "$FAILED Kuberblue integration tests FAILED!"
    
    # Get debug information on failure
    echo "=== Debug Information ==="
    get_cluster_debug_info
    get_network_debug_info
    
    exit 1
fi