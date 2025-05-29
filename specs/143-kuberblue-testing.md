# Issue #143: feat(kuberblue-testing): implement automated testing for kuberblue

## Issue Summary
**Title**: feat(kuberblue-testing): implement automated testing for kuberblue  
**State**: Open  
**Author**: Creplav  
**Assignee**: Creplav  
**Labels**: feature  

**Description**: Add automated tests for Kuberblue and its deployed applications

## Implementation Plan

### Overview
This implementation will create a comprehensive automated testing framework for Kuberblue deployments, ensuring reliable Kubernetes cluster functionality and application deployment validation.

### Phase 1: Test Infrastructure Setup

#### 1.1 Create Test Directory Structure
```bash
mkdir -p tests/kuberblue/{helpers,fixtures/{manifests,configs,scripts}}
```

**Files to create**:
- `tests/kuberblue/test_kuberblue_container.sh` - Container image validation
- `tests/kuberblue/test_kuberblue_cluster.sh` - Cluster functionality tests  
- `tests/kuberblue/test_kuberblue_components.sh` - Component testing
- `tests/kuberblue/test_kuberblue_integration.sh` - End-to-end tests
- `tests/kuberblue/test_kuberblue_security.sh` - Security validation
- `tests/kuberblue/helpers/cluster_utils.sh` - Cluster management utilities
- `tests/kuberblue/helpers/manifest_utils.sh` - Manifest validation utilities
- `tests/kuberblue/helpers/network_utils.sh` - Network testing utilities

#### 1.2 Update Main Test Runner
**File**: `tests/run_tests.sh`
- **Integration**: Extends existing test runner without breaking current functionality
- Add Kuberblue test detection logic (follows existing pattern for variant detection)
- Integrate Kuberblue tests into main test flow using same error handling
- Add conditional execution based on image type (similar to existing QEMU conditional logic)
- Reuse existing `EXIT_CODE` tracking and final reporting

#### 1.3 Update Makefile
**File**: `Makefile`
- Add `test_kuberblue_container` target
- Add `test_kuberblue_cluster` target  
- Add `test_kuberblue` composite target
- Update main `test` target to include Kuberblue tests

### Phase 2: Container Image Tests

#### 2.1 Implement `test_kuberblue_container.sh`
**Purpose**: Validate Kuberblue container image contains all required components

**Integration**: Extends existing `test_container.sh` patterns using same structure and error handling

**Test Functions**:
```bash
test_kuberblue_binaries() {
    # Test presence of kubeadm, kubelet, kubectl, crio
    # Uses same podman run pattern as existing container tests
}

test_kuberblue_files() {
    # Verify Kuberblue-specific files exist
    # /usr/libexec/kuberblue/ structure
    # /etc/kuberblue/ configuration
    # Just command files
    # Follows same file validation pattern as test_artifacts.sh
}

test_kuberblue_systemd() {
    # Verify systemd services and timers
    # kuberblue-onboot.service
    # User systemd configurations
}

test_kuberblue_user() {
    # Verify kuberblue user (UID 970) exists
    # Check proper permissions
    # Validate sudoers configuration
}

test_kuberblue_configs() {
    # Validate system configurations
    # Kernel modules (50-kuberblue.conf)
    # Sysctl settings
    # SELinux configuration
    # SSH configuration
}
```

#### 2.2 Create Test Fixtures
**Directory**: `tests/kuberblue/fixtures/`
- Sample kubeadm.yaml configurations
- Test manifest files (Helm, Kustomize, YAML)
- Network configuration test files

### Phase 3: Cluster Functionality Tests

#### 3.1 Implement `test_kuberblue_cluster.sh`
**Purpose**: Validate cluster initialization and basic functionality

**Test Functions**:
```bash
test_cluster_init() {
    # Test kubeadm init with Kuberblue configuration
    # Verify control plane startup
    # Check node registration
}

test_network_setup() {
    # Deploy CNI plugin (Cilium/Flannel)
    # Test pod-to-pod communication works correctly
    # Verify service discovery functions as expected
    # Validate network policies are enforced
    # Test external connectivity and ingress functionality
}

test_storage_setup() {
    # Deploy OpenEBS (if configured)
    # Test StorageClass creation and functionality
    # Validate PVC creation, binding, and actual data persistence
    # Test volume expansion and snapshotting
    # Verify data survives pod restarts and rescheduling
}

test_cluster_health() {
    # Check all system pods are running
    # Verify cluster networking
    # Test DNS resolution
}
```

#### 3.2 QEMU Integration
**Purpose**: Extend existing QEMU testing for full cluster validation

**Integration**: Leverages existing `test_container_qemu.sh` infrastructure

**Implementation**:
- Extend `tests/test_container_qemu.sh` to detect Kuberblue variant
- Reuse existing VM boot and SSH connection logic
- Add Kuberblue-specific test execution after basic QEMU tests pass
- Use same cleanup and error handling patterns
- Follow existing timeout and retry mechanisms

### Phase 4: Component Testing

#### 4.1 Implement `test_kuberblue_components.sh`
**Purpose**: Test individual Kuberblue components

**Test Functions**:
```bash
test_just_commands() {
    # Test all kuberblue just commands
    # Validate command execution and error handling
}

test_manifest_deployment() {
    # Test Helm chart deployment via values files
    # Test Kustomize deployment
    # Test raw YAML manifest deployment
    # Test patch application
}

test_user_management() {
    # Test kuberblue user creation
    # Validate kubectl configuration
    # Check RBAC permissions
}

test_script_functionality() {
    # Test all scripts in /usr/libexec/kuberblue/
    # Validate setup scripts
    # Test kube_setup scripts
}
```

#### 4.2 Create Helper Utilities

**File**: `tests/kuberblue/helpers/cluster_utils.sh`
```bash
wait_for_cluster_ready() {
    # Wait for cluster components to be ready
}

cleanup_test_resources() {
    # Clean up test pods, services, etc.
}

validate_cluster_state() {
    # Check cluster is in expected state
}
```

**File**: `tests/kuberblue/helpers/manifest_utils.sh`
```bash
validate_helm_deployment() {
    # Validate Helm chart deployment
}

validate_kustomize_deployment() {
    # Validate Kustomize deployment
}

test_manifest_syntax() {
    # Validate YAML syntax and Kubernetes schema
}
```

**File**: `tests/kuberblue/helpers/network_utils.sh`
```bash
test_pod_connectivity() {
    # Test pod-to-pod networking
}

test_service_discovery() {
    # Test Kubernetes service discovery
}

test_ingress_functionality() {
    # Test ingress controller (if configured)
}
```

### Phase 5: Integration Testing

#### 5.1 Implement `test_kuberblue_integration.sh`
**Purpose**: End-to-end testing with real workloads

**Test Scenarios**:
```bash
test_complete_application_deployment() {
    # Deploy multi-tier application
    # Test with database backend
    # Validate service mesh integration
}

test_cluster_operations() {
    # Test cluster scaling scenarios
    # Validate backup and restore procedures
    # Test upgrade processes
}

test_workload_scenarios() {
    # Test stateful workloads with persistent storage
    # Validate batch jobs and cron jobs
    # Test resource limits and quotas
}

test_real_world_manifests() {
    # Deploy actual applications from /etc/kuberblue/manifests/
    # Test Cilium deployment and network functionality
    # Test OpenEBS deployment and storage functionality
    # Validate all default manifests work as intended
}

test_deployment_functionality() {
    # Validate deployed applications actually function correctly
    # Test application endpoints and health checks
    # Verify data persistence and state management
    # Test application scaling and recovery
}
```

### Phase 6: Deployment Functionality Validation

#### 6.1 Implement `test_kuberblue_deployment_validation.sh`
**Purpose**: Ensure deployed applications work as intended, not just that they deploy

**Test Functions**:
```bash
test_cilium_functionality() {
    # Deploy Cilium CNI
    # Test network policies actually block/allow traffic as configured
    # Validate service mesh features (if enabled)
    # Test load balancing and service discovery
    # Verify encryption in transit (if configured)
    # Test cluster mesh connectivity (multi-cluster scenarios)
}

test_openebs_functionality() {
    # Deploy OpenEBS storage
    # Create test application with persistent storage
    # Write data, restart pod, verify data persistence
    # Test volume expansion while application is running
    # Validate backup and restore functionality
    # Test performance characteristics match expectations
}

test_application_workloads() {
    # Deploy sample applications from manifests directory
    # Test web applications respond correctly to HTTP requests
    # Validate database applications can store/retrieve data
    # Test message queues can process messages
    # Verify monitoring stack collects metrics correctly
}

test_helm_chart_functionality() {
    # Deploy Helm charts and validate they work end-to-end
    # Test chart upgrades and rollbacks
    # Validate chart customization via values files
    # Test chart dependencies are resolved correctly
}

test_workload_resilience() {
    # Test pod recovery after node failure simulation
    # Validate automatic scaling works under load
    # Test rolling updates don't cause downtime
    # Verify backup and disaster recovery procedures
}

test_performance_benchmarks() {
    # Run performance tests on deployed applications
    # Validate network throughput meets expectations
    # Test storage I/O performance
    # Measure application response times under load
}
```

#### 6.2 Application-Specific Validation

**Web Application Testing**:
```bash
validate_web_application() {
    local app_name="$1"
    local expected_response="$2"
    
    # Deploy application
    kubectl apply -f "/etc/kuberblue/manifests/${app_name}/"
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available deployment/"$app_name" --timeout=300s
    
    # Test HTTP endpoints
    local service_ip=$(kubectl get service "$app_name" -o jsonpath='{.spec.clusterIP}')
    local response=$(curl -s "http://${service_ip}/health")
    
    if [[ "$response" != "$expected_response" ]]; then
        echo "ERROR: Application $app_name not responding correctly"
        return 1
    fi
    
    # Test under load
    kubectl run load-test --image=busybox --rm -it --restart=Never -- \
        sh -c "for i in \$(seq 1 100); do wget -q -O- http://${service_ip}/; done"
}
```

**Database Testing**:
```bash
validate_database_functionality() {
    local db_name="$1"
    
    # Deploy database
    kubectl apply -f "/etc/kuberblue/manifests/${db_name}/"
    kubectl wait --for=condition=ready pod -l app="$db_name" --timeout=300s
    
    # Test data persistence
    kubectl exec deployment/"$db_name" -- \
        sh -c "echo 'CREATE TABLE test (id INT);' | psql"
    
    # Restart pod and verify data persists
    kubectl delete pod -l app="$db_name"
    kubectl wait --for=condition=ready pod -l app="$db_name" --timeout=300s
    
    # Verify table still exists
    kubectl exec deployment/"$db_name" -- \
        sh -c "echo '\\dt' | psql" | grep -q "test" || return 1
}
```

**Storage Validation**:
```bash
validate_storage_functionality() {
    # Create PVC and test application
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-storage-pvc
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
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-test
  template:
    metadata:
      labels:
        app: storage-test
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

    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod -l app=storage-test --timeout=300s
    
    # Write test data
    kubectl exec deployment/storage-test -- sh -c "echo 'test data' > /data/test.txt"
    
    # Delete and recreate pod
    kubectl delete pod -l app=storage-test
    kubectl wait --for=condition=ready pod -l app=storage-test --timeout=300s
    
    # Verify data persists
    local data=$(kubectl exec deployment/storage-test -- cat /data/test.txt)
    if [[ "$data" != "test data" ]]; then
        echo "ERROR: Data not persisted across pod restart"
        return 1
    fi
    
    # Test volume expansion
    kubectl patch pvc test-storage-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
    
    # Verify expansion worked
    sleep 30
    local size=$(kubectl exec deployment/storage-test -- df -h /data | tail -1 | awk '{print $2}')
    if [[ ! "$size" =~ "2.0G" ]]; then
        echo "WARNING: Volume expansion may not have worked, size: $size"
    fi
}
```

#### 6.3 End-to-End Scenario Testing

**Multi-Component Application Testing**:
```bash
test_full_application_stack() {
    # Deploy complete application stack (frontend, backend, database)
    # Test user workflow end-to-end
    # Validate data flows correctly through all components
    # Test authentication and authorization
    # Verify monitoring and logging integration
}

test_microservices_communication() {
    # Deploy microservices architecture
    # Test service-to-service communication
    # Validate service mesh features (if enabled)
    # Test distributed tracing
    # Verify load balancing across service instances
}
```

### Phase 7: Security Testing

#### 6.1 Implement `test_kuberblue_security.sh`
**Purpose**: Validate security configurations

**Test Functions**:
```bash
test_rbac_configuration() {
    # Test default service account permissions
    # Validate kuberblue user RBAC
    # Check namespace isolation
}

test_network_policies() {
    # Test default network policies
    # Validate ingress/egress rules
}

test_pod_security() {
    # Check security contexts
    # Validate pod security standards
}

test_system_security() {
    # Verify SELinux enforcement
    # Check file permissions
    # Validate service configurations
}
```

### Phase 7: CI/CD Integration

#### 7.1 Update Test Runner Integration
**File**: `tests/run_tests.sh`
```bash
# Add Kuberblue-specific test execution
if [[ "$IMAGE" == *"kuberblue"* ]]; then
    echo -e "\n>> Running Kuberblue Container Tests"
    bash "$TEST_DIR/kuberblue/test_kuberblue_container.sh" "$@"
    
    if [[ "$ENABLE_CLUSTER_TESTS" == "1" ]]; then
        echo -e "\n>> Running Kuberblue Cluster Tests"
        bash "$TEST_DIR/kuberblue/test_kuberblue_cluster.sh" "$@"
        bash "$TEST_DIR/kuberblue/test_kuberblue_components.sh" "$@"
        bash "$TEST_DIR/kuberblue/test_kuberblue_integration.sh" "$@"
        bash "$TEST_DIR/kuberblue/test_kuberblue_security.sh" "$@"
    fi
fi
```

#### 7.2 Makefile Updates
**File**: `Makefile`
```makefile
# Add Kuberblue test targets
test_kuberblue_container:
	./tests/kuberblue/test_kuberblue_container.sh $(IMAGE_NAME)

test_kuberblue_cluster:
	ENABLE_CLUSTER_TESTS=1 ./tests/kuberblue/test_kuberblue_cluster.sh $(IMAGE_NAME)

test_kuberblue_full:
	ENABLE_CLUSTER_TESTS=1 ./tests/run_tests.sh $(IMAGE_NAME)

# Update main test target for Kuberblue builds
ifeq ($(findstring kuberblue,$(IMAGE_NAME)),kuberblue)
test: test_container test_artifacts test_kuberblue_container
test_full: test_container test_artifacts test_kuberblue_full
else
test: test_container test_artifacts
test_full: test_container test_artifacts test_container_qemu
endif
```

### Phase 8: Documentation and Validation

#### 8.1 Update Documentation
**Files to update**:
- `tests/README.md` - Add Kuberblue testing section
- `CLAUDE.md` - Add Kuberblue test commands
- `docs/content/pages/testing.md` - Document Kuberblue testing

#### 8.2 Test Validation
- Validate all tests pass on clean Kuberblue build
- Test failure scenarios to ensure proper error reporting
- Performance testing and optimization

## Implementation Timeline

### Week 1: Infrastructure Setup
- [ ] Create test directory structure
- [ ] Implement basic container image tests
- [ ] Update main test runner
- [ ] Update Makefile targets

### Week 2: Core Functionality
- [ ] Implement cluster initialization tests
- [ ] Create component testing framework
- [ ] Develop helper utilities
- [ ] QEMU integration for cluster testing

### Week 3: Advanced Testing
- [ ] Implement integration tests
- [ ] Add deployment functionality validation tests
- [ ] Create comprehensive test fixtures and sample applications
- [ ] Implement performance benchmarking and load testing

### Week 4: Integration and Documentation
- [ ] Add security validation tests
- [ ] CI/CD integration
- [ ] Documentation updates
- [ ] End-to-end validation of all deployment scenarios
- [ ] Performance benchmarking and optimization

## Success Criteria

1. **Container Tests**: All Kuberblue-specific files and configurations validated
2. **Cluster Tests**: Successful cluster initialization and basic functionality
3. **Component Tests**: All Just commands and scripts function correctly
4. **Integration Tests**: Real workloads deploy and function properly
5. **Deployment Validation**: Applications work as intended after deployment
   - Web applications respond correctly to requests
   - Databases persist data across restarts
   - Storage volumes maintain data integrity
   - Network policies enforce security rules
   - Load balancing and scaling work under stress
6. **Performance Tests**: Applications meet performance benchmarks
7. **Security Tests**: All security configurations validated
8. **CI/CD Integration**: Tests run automatically on Kuberblue builds
9. **Documentation**: Complete testing documentation and examples

## Dependencies

- Existing test infrastructure (`tests/` directory)
- QEMU/KVM for cluster testing
- Container runtime (Podman)
- Kubernetes tools (kubectl, helm)
- GitLab CI/CD pipeline integration

## Risk Mitigation

1. **QEMU Dependencies**: Ensure fallback for environments without QEMU
2. **Network Requirements**: Handle testing in restricted network environments
3. **Resource Usage**: Optimize tests for CI/CD resource constraints
4. **Test Reliability**: Implement retry logic and proper cleanup

This comprehensive implementation plan will deliver robust automated testing for Kuberblue deployments, ensuring reliability and quality of the Kubernetes distribution.