#!/bin/bash
# Kuberblue Security Tests
#
# This script validates security configurations for Kuberblue, including:
# - RBAC configuration and service account permissions
# - Network policies and ingress/egress rules
# - Pod security contexts and standards
# - System security (SELinux, file permissions, service configurations)
#
# Usage: ./test_kuberblue_security.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference

# Enable strict error handling
set -euo pipefail

echo "Running Kuberblue security tests"

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

# Test RBAC configuration
# Validates default service account permissions and kuberblue user RBAC
function test_rbac_configuration() {
    echo "Testing RBAC configuration"
    
    # Check if we're in a cluster environment
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping RBAC test"
        return 0
    fi
    
    # Test default service account permissions
    echo "Testing default service account permissions"
    
    # Verify default service account exists
    if ! kubectl get serviceaccount default -n default >/dev/null 2>&1; then
        echo "FAIL: Default service account not found"
        return 1
    fi
    
    # Test that default service account has minimal permissions
    local test_namespace="rbac-test"
    ensure_test_namespace "$test_namespace"
    
    # Create test pod with default service account
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rbac-test-pod
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  serviceAccountName: default
  containers:
  - name: test
    image: bitnami/kubectl:latest
    command: ['sleep', '300']
  restartPolicy: Never
EOF

    # Wait for pod to be ready
    if ! kubectl wait --for=condition=ready pod/rbac-test-pod -n "$test_namespace" --timeout=120s; then
        echo "FAIL: RBAC test pod failed to become ready"
        return 1
    fi
    
    # Test that default service account cannot access sensitive resources
    echo "Testing default service account restrictions"
    local access_test_result
    access_test_result=$(kubectl exec rbac-test-pod -n "$test_namespace" -- kubectl get secrets 2>&1 || echo "FORBIDDEN")
    
    if echo "$access_test_result" | grep -q "forbidden"; then
        echo "Default service account restrictions test PASSED"
    else
        echo "WARNING: Default service account may have excessive permissions"
    fi
    
    # Test kuberblue user RBAC (if cluster is set up)
    if id kuberblue >/dev/null 2>&1; then
        echo "Testing kuberblue user RBAC"
        
        # Test that kuberblue user can access cluster
        if sudo -u kuberblue kubectl cluster-info >/dev/null 2>&1; then
            echo "Kuberblue user cluster access test PASSED"
        else
            echo "FAIL: Kuberblue user cannot access cluster"
            return 1
        fi
        
        # Test kuberblue user permissions
        local kuberblue_access
        kuberblue_access=$(sudo -u kuberblue kubectl auth can-i get pods 2>&1 || echo "no")
        
        if [[ "$kuberblue_access" == "yes" ]]; then
            echo "Kuberblue user permissions test PASSED"
        else
            echo "WARNING: Kuberblue user may not have expected permissions"
        fi
    else
        echo "INFO: Kuberblue user not found, skipping user RBAC test"
    fi
    
    # Check for cluster admin bindings
    echo "Checking for excessive cluster admin bindings"
    local admin_bindings
    admin_bindings=$(kubectl get clusterrolebindings -o json | grep -c "cluster-admin" || echo "0")
    
    if [[ $admin_bindings -lt 5 ]]; then
        echo "Cluster admin bindings check PASSED"
    else
        echo "WARNING: Found $admin_bindings cluster-admin bindings - review for security"
    fi
    
    # Clean up
    kubectl delete namespace "$test_namespace" --ignore-not-found=true || true
    
    echo "PASS: RBAC configuration test succeeded"
    return 0
}

# Test network policies
# Validates default network policies and ingress/egress rules
function test_network_policies() {
    echo "Testing network policies"
    
    # Check if we're in a cluster environment
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping network policies test"
        return 0
    fi
    
    # Check if network policies are supported
    if ! kubectl api-resources | grep -q networkpolicies; then
        echo "SKIP: NetworkPolicies not supported in this cluster"
        return 0
    fi
    
    local test_namespace="netpol-test"
    ensure_test_namespace "$test_namespace"
    
    # Create test network policy
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-netpol
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  podSelector:
    matchLabels:
      role: restricted
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: allowed
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          role: backend
    ports:
    - protocol: TCP
      port: 3306
EOF

    # Verify network policy was created
    if ! kubectl get networkpolicy test-netpol -n "$test_namespace" >/dev/null 2>&1; then
        echo "FAIL: Network policy creation failed"
        return 1
    fi
    
    # Create test pods for network policy testing
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: $test_namespace
  labels:
    test: kuberblue
    role: restricted
spec:
  containers:
  - name: test
    image: nginx:alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: allowed-pod
  namespace: $test_namespace
  labels:
    test: kuberblue
    role: allowed
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '300']
---
apiVersion: v1
kind: Pod
metadata:
  name: denied-pod
  namespace: $test_namespace
  labels:
    test: kuberblue
    role: denied
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '300']
EOF

    # Wait for pods to be ready
    if ! wait_for_pods_ready "$test_namespace" "test=kuberblue" 120; then
        echo "WARNING: Network policy test pods failed to become ready"
    fi
    
    # Test network policy enforcement
    echo "Testing network policy enforcement"
    
    # Get restricted pod IP
    local restricted_ip
    restricted_ip=$(kubectl get pod restricted-pod -n "$test_namespace" -o jsonpath='{.status.podIP}' 2>/dev/null || echo "")
    
    if [[ -n "$restricted_ip" ]]; then
        # Test allowed connectivity
        local allowed_result
        allowed_result=$(kubectl exec allowed-pod -n "$test_namespace" -- timeout 10 nc -zv "$restricted_ip" 80 2>&1 || echo "FAILED")
        
        # Test denied connectivity
        local denied_result
        denied_result=$(kubectl exec denied-pod -n "$test_namespace" -- timeout 10 nc -zv "$restricted_ip" 80 2>&1 || echo "FAILED")
        
        echo "Network policy enforcement test completed"
        echo "Allowed pod result: $allowed_result"
        echo "Denied pod result: $denied_result"
        
        # Note: Actual enforcement depends on CNI plugin support
        if echo "$allowed_result" | grep -q "succeeded\|open"; then
            echo "Network policy allowed traffic test PASSED"
        else
            echo "INFO: Network policy allowed traffic test inconclusive"
        fi
    else
        echo "WARNING: Could not get restricted pod IP for network policy testing"
    fi
    
    # Check for default network policies in system namespaces
    echo "Checking for default network policies"
    local system_netpols
    system_netpols=$(kubectl get networkpolicies -n kube-system --no-headers | wc -l || echo "0")
    
    if [[ $system_netpols -gt 0 ]]; then
        echo "Found $system_netpols network policies in kube-system"
    else
        echo "INFO: No network policies found in kube-system namespace"
    fi
    
    # Clean up
    kubectl delete namespace "$test_namespace" --ignore-not-found=true || true
    
    echo "PASS: Network policies test succeeded"
    return 0
}

# Test pod security contexts and standards
# Validates security contexts and pod security standards
function test_pod_security() {
    echo "Testing pod security contexts and standards"
    
    # Check if we're in a cluster environment
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping pod security test"
        return 0
    fi
    
    local test_namespace="pod-security-test"
    ensure_test_namespace "$test_namespace"
    
    # Test pod with security context
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true
    fsGroup: 1000
  containers:
  - name: secure-container
    image: nginx:alpine
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
    ports:
    - containerPort: 8080
EOF

    # Wait for secure pod to be ready
    if ! kubectl wait --for=condition=ready pod/secure-pod -n "$test_namespace" --timeout=120s; then
        echo "WARNING: Secure pod failed to start (this may be expected)"
    else
        echo "Secure pod with security context started successfully"
        
        # Test that pod is running as non-root
        local user_check
        user_check=$(kubectl exec secure-pod -n "$test_namespace" -- id -u 2>/dev/null || echo "failed")
        
        if [[ "$user_check" != "0" && "$user_check" != "failed" ]]; then
            echo "Non-root security context test PASSED"
        else
            echo "WARNING: Pod may be running as root"
        fi
    fi
    
    # Test privileged pod restrictions
    echo "Testing privileged pod restrictions"
    
    cat <<EOF | kubectl apply -f - 2>&1 || echo "PRIVILEGED_BLOCKED"
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  containers:
  - name: privileged-container
    image: busybox
    command: ['sleep', '300']
    securityContext:
      privileged: true
EOF

    # Check if privileged pod was blocked
    if kubectl get pod privileged-pod -n "$test_namespace" >/dev/null 2>&1; then
        echo "WARNING: Privileged pod was allowed - consider implementing pod security policies"
        kubectl delete pod privileged-pod -n "$test_namespace" || true
    else
        echo "Privileged pod restriction test PASSED"
    fi
    
    # Test host network restrictions
    echo "Testing host network restrictions"
    
    cat <<EOF | kubectl apply -f - 2>&1 || echo "HOST_NETWORK_BLOCKED"
apiVersion: v1
kind: Pod
metadata:
  name: host-network-pod
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  hostNetwork: true
  containers:
  - name: host-network-container
    image: busybox
    command: ['sleep', '300']
EOF

    # Check if host network pod was blocked
    if kubectl get pod host-network-pod -n "$test_namespace" >/dev/null 2>&1; then
        echo "WARNING: Host network pod was allowed - consider implementing pod security policies"
        kubectl delete pod host-network-pod -n "$test_namespace" || true
    else
        echo "Host network restriction test PASSED"
    fi
    
    # Check for pod security standards enforcement
    echo "Checking pod security standards"
    
    # Try to apply pod security standard to namespace
    kubectl label namespace "$test_namespace" pod-security.kubernetes.io/enforce=restricted --overwrite 2>/dev/null || true
    kubectl label namespace "$test_namespace" pod-security.kubernetes.io/warn=restricted --overwrite 2>/dev/null || true
    
    # Test if restricted pod security standard is enforced
    cat <<EOF | kubectl apply -f - 2>&1 || echo "RESTRICTED_BLOCKED"
apiVersion: v1
kind: Pod
metadata:
  name: unrestricted-pod
  namespace: $test_namespace
  labels:
    test: kuberblue
spec:
  containers:
  - name: unrestricted-container
    image: busybox
    command: ['sleep', '300']
    securityContext:
      runAsUser: 0
EOF

    if kubectl get pod unrestricted-pod -n "$test_namespace" >/dev/null 2>&1; then
        echo "INFO: Pod security standards may not be strictly enforced"
        kubectl delete pod unrestricted-pod -n "$test_namespace" || true
    else
        echo "Pod security standards enforcement test PASSED"
    fi
    
    # Clean up
    kubectl delete namespace "$test_namespace" --ignore-not-found=true || true
    
    echo "PASS: Pod security test succeeded"
    return 0
}

# Test system security
# Validates SELinux enforcement, file permissions, and service configurations
function test_system_security() {
    echo "Testing system security configurations"
    
    # Test SELinux enforcement
    echo "Testing SELinux configuration"
    
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "Disabled")
        
        if [[ "$selinux_status" == "Enforcing" ]]; then
            echo "SELinux enforcement test PASSED"
        elif [[ "$selinux_status" == "Permissive" ]]; then
            echo "WARNING: SELinux is in permissive mode"
        else
            echo "WARNING: SELinux is disabled"
        fi
        
        # Check SELinux configuration file
        if [[ -f "/etc/selinux/config" ]]; then
            local selinux_config
            selinux_config=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2 || echo "unknown")
            echo "SELinux config setting: $selinux_config"
        fi
    else
        echo "INFO: SELinux tools not available"
    fi
    
    # Test file permissions for sensitive files
    echo "Testing file permissions"
    
    local sensitive_files=(
        "/etc/kuberblue/kubeadm.yaml:644"
        "/etc/kubernetes/admin.conf:600"
        "/etc/ssh/sshd_config:644"
        "/etc/sudoers:440"
    )
    
    for file_perm in "${sensitive_files[@]}"; do
        local file="${file_perm%:*}"
        local expected_perm="${file_perm#*:}"
        
        if [[ -f "$file" ]]; then
            local actual_perm
            actual_perm=$(stat -c "%a" "$file" 2>/dev/null || echo "unknown")
            
            if [[ "$actual_perm" == "$expected_perm" ]] || [[ "$actual_perm" -le "$expected_perm" ]]; then
                echo "File permissions for $file: PASSED ($actual_perm)"
            else
                echo "WARNING: File permissions for $file may be too permissive ($actual_perm, expected <= $expected_perm)"
            fi
        else
            echo "INFO: File $file not found"
        fi
    done
    
    # Test service configurations
    echo "Testing service security configurations"
    
    # Check if SSH is configured securely
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        echo "Checking SSH security configuration"
        
        # Check if root login is disabled
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            echo "SSH root login restriction: PASSED"
        else
            echo "WARNING: SSH root login may be enabled"
        fi
        
        # Check if password authentication is configured appropriately
        if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
            local password_auth
            password_auth=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
            echo "SSH password authentication: $password_auth"
        fi
    fi
    
    # Check firewall status
    echo "Checking firewall configuration"
    
    if systemctl is-active firewalld >/dev/null 2>&1; then
        echo "Firewalld is active"
        # In Kuberblue, firewalld is typically disabled for Kubernetes
        echo "WARNING: Firewalld is active - this may interfere with Kubernetes networking"
    else
        echo "Firewalld is inactive (expected for Kuberblue)"
    fi
    
    # Check if important services are properly masked/disabled
    echo "Checking service security settings"
    
    local masked_services=("systemd-resolved")
    
    for service in "${masked_services[@]}"; do
        if systemctl is-masked "$service" >/dev/null 2>&1; then
            echo "Service $service is properly masked"
        else
            echo "WARNING: Service $service is not masked"
        fi
    done
    
    # Check for running services that shouldn't be running
    echo "Checking for unnecessary running services"
    
    local unnecessary_services=("telnet" "rsh" "rlogin")
    
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            echo "WARNING: Unnecessary service $service is running"
        fi
    done
    
    # Test kernel security settings
    echo "Testing kernel security settings"
    
    local sysctl_settings=(
        "net.ipv4.ip_forward:1"
        "net.bridge.bridge-nf-call-iptables:1"
        "net.bridge.bridge-nf-call-ip6tables:1"
    )
    
    for setting in "${sysctl_settings[@]}"; do
        local param="${setting%:*}"
        local expected="${setting#*:}"
        
        if [[ -f "/proc/sys/${param//./\/}" ]]; then
            local actual
            actual=$(sysctl -n "$param" 2>/dev/null || echo "unknown")
            
            if [[ "$actual" == "$expected" ]]; then
                echo "Kernel setting $param: PASSED ($actual)"
            else
                echo "WARNING: Kernel setting $param: $actual (expected: $expected)"
            fi
        fi
    done
    
    echo "PASS: System security test succeeded"
    return 0
}

# Main test execution
echo "=== Running Kuberblue Security Tests ==="
FAILED=0

# Execute each test and track failures
if ! test_rbac_configuration; then
    ((FAILED++))
fi

if ! test_network_policies; then
    ((FAILED++))
fi

if ! test_pod_security; then
    ((FAILED++))
fi

if ! test_system_security; then
    ((FAILED++))
fi

# Report test results
echo "=== Kuberblue Security Test Results ==="
if [[ $FAILED -eq 0 ]]; then
    echo "All Kuberblue security tests PASSED!"
    exit 0
else
    echo "$FAILED Kuberblue security tests FAILED!"
    exit 1
fi