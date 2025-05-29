# Feature Specification: Declarative Chainsaw Testing for Kuberblue

**Feature ID:** 143-feat-chainsaw  
**Parent Issue:** [#143 feat(kuberblue-testing): implement automated testing for kuberblue](https://gitlab.com/immutablue/immutablue/-/issues/143)  
**Status:** Proposed  
**Author:** Ben Doty 
**Created:** 2025-05-28  

## Overview

This specification defines the implementation of a declarative testing framework using Chainsaw for Kuberblue manifest validation. Tests will be co-located with their respective manifests using a `*_test.yaml` naming convention, enabling self-documenting, maintainable, and automatically discoverable tests.

## Motivation

The current shell-based testing approach for Kuberblue has several limitations:
- **Complex maintenance**: Adding new tests requires shell scripting knowledge
- **Poor discoverability**: Tests are separated from the components they validate
- **Limited reusability**: Shell tests are hard to parameterize and extend
- **Inconsistent patterns**: Each test implements its own validation logic

A declarative Chainsaw-based approach addresses these issues by:
- **Simplifying test creation**: Pure YAML configuration for new tests
- **Co-locating tests with manifests**: Tests live alongside what they validate
- **Standardizing test patterns**: Consistent YAML-based test definitions
- **Enabling automatic discovery**: Tests are found and executed automatically

## Goals

### Primary Goals
1. **Declarative Test Definition**: Tests defined in YAML with minimal configuration
2. **Co-located Test Organization**: Tests stored alongside their corresponding manifests
3. **Automatic Test Discovery**: Dynamic discovery and execution of co-located tests
4. **Component-Specific Validation**: Each component owns and maintains its tests
5. **Integration with Existing Framework**: Seamless integration with current test infrastructure

### Secondary Goals
1. **Parallel Test Execution**: Tests run concurrently where possible
2. **Rich Assertion Capabilities**: Built-in Kubernetes resource validation
3. **Clear Test Reporting**: Structured output with detailed failure information
4. **Gradual Migration Path**: Existing shell tests remain functional during transition

## Non-Goals
1. **Complete shell test replacement**: Existing cluster and integration tests remain
2. **Performance testing**: Focused on functional validation, not performance metrics
3. **External service testing**: Limited to Kubernetes-native component validation

## Design

### Test Organization Structure

```
artifacts/overrides_kuberblue/etc/kuberblue/manifests/
├── cilium/
│   ├── 00-metadata.yaml
│   ├── 10-values.yaml
│   ├── 50-default-ip-pool.yaml
│   └── cilium_test.yaml              # Co-located test
├── openebs/
│   ├── 00-metadata.yaml
│   ├── 10-values.yaml
│   ├── 50-default-sc-patch.json
│   └── openebs_test.yaml             # Co-located test
├── kube-flannel.yaml
├── kube-flannel_test.yaml            # Co-located test
└── metadata.yaml.tpl
```

### Test Naming Convention

- **Pattern**: `{component}_test.yaml`
- **Examples**: 
  - `cilium_test.yaml`
  - `openebs_test.yaml`
  - `kube-flannel_test.yaml`
- **Discovery**: All files matching `*_test.yaml` in manifest directories

### Test Metadata Standard

All tests must include standardized metadata for categorization and discovery:

```yaml
apiVersion: chainsaw.kyverno.io/v1alpha1
kind: Test
metadata:
  name: {component}-{test-type}-test
  annotations:
    kuberblue.test/component: "{component-name}"
    kuberblue.test/category: "{networking|storage|compute|security}"
    kuberblue.test/priority: "{high|medium|low}"
    kuberblue.test/timeout: "{duration}"
spec:
  # Test definition
```

### Test Categories

Tests are organized into functional categories:

1. **Networking** (`networking`):
   - Network plugin functionality
   - Pod-to-pod connectivity
   - Service discovery and load balancing
   - Network policy enforcement

2. **Storage** (`storage`):
   - Storage class availability
   - PVC provisioning and binding
   - Volume attachment and mounting
   - Storage performance validation

3. **Compute** (`compute`):
   - Pod scheduling and execution
   - Resource allocation and limits
   - Node readiness and capacity
   - Workload deployment validation

4. **Security** (`security`):
   - RBAC configuration validation
   - Pod security policy enforcement
   - Secret and ConfigMap access
   - Admission controller functionality

## Implementation Plan

### Phase 1: Foundation Setup

#### 1.1 Install and Configure Chainsaw

**Chainsaw Installation Options:**

Since Kuberblue has homebrew (brew) support for x86_64 systems, we have several installation approaches to consider:

**Option A: Extend packages.yaml for variant-specific brew packages**
```yaml
# New section in packages.yaml
brew_kuberblue:
  install:
  - chainsaw
```

**Option B: Install via kuberblue setup scripts**
```bash
# Add to artifacts/overrides_kuberblue/usr/libexec/kuberblue/setup/first_boot.sh
if command -v brew >/dev/null 2>&1; then
    brew install chainsaw
else
    # Manual installation for ARM64 or systems without brew
    CHAINSAW_VERSION="v0.1.7"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
    esac
    curl -L "https://github.com/kyverno/chainsaw/releases/download/${CHAINSAW_VERSION}/chainsaw_linux_${ARCH}.tar.gz" \
        | tar xz -C /usr/local/bin/ chainsaw
    chmod +x /usr/local/bin/chainsaw
fi
```

**Option C: Add to rpm_kuberblue section (if RPM available)**
```yaml
# Check if Chainsaw has an RPM package available
rpm_kuberblue:
  # ... existing packages
  - chainsaw  # if available as RPM
```

**Recommendation:** Option A (extend packages.yaml) provides the cleanest integration with the existing package management system while supporting both x86_64 (via brew) and ARM64 (via manual installation fallback).

**File**: `artifacts/overrides_kuberblue/etc/kuberblue/chainsaw.yaml`
```yaml
apiVersion: chainsaw.kyverno.io/v1alpha1
kind: Configuration
metadata:
  name: kuberblue-test-config
spec:
  timeouts:
    apply: 30s
    assert: 300s
    cleanup: 60s
    delete: 30s
    error: 10s
    exec: 60s
  cleanup:
    skipDelete: false
  discovery:
    excludeTestRegex: "^(disabled|skip)-.*"
    includeTestRegex: ".*_test\\.yaml$"
  execution:
    parallel: 4
    repeatCount: 1
  reporting:
    format: "json"
```

#### 1.2 Create Test Discovery Framework

**File**: `tests/kuberblue/chainsaw_runner.sh`
```bash
#!/bin/bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly MANIFEST_BASE_DIR="/etc/kuberblue/manifests"

# Import common utilities
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

function discover_chainsaw_tests() {
    local manifest_dir="$1"
    local test_files=()
    
    info "Discovering Chainsaw tests in $manifest_dir"
    
    # Find all *_test.yaml files recursively
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$manifest_dir" -name "*_test.yaml" -type f -print0 2>/dev/null || true)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        warn "No Chainsaw tests found in $manifest_dir"
        return 1
    fi
    
    info "Found ${#test_files[@]} Chainsaw test files:"
    printf '  %s\n' "${test_files[@]}"
    
    printf '%s\n' "${test_files[@]}"
}

function validate_test_metadata() {
    local test_file="$1"
    
    # Check required metadata
    if ! grep -q "kuberblue.test/component" "$test_file"; then
        error "Test $test_file missing required annotation: kuberblue.test/component"
        return 1
    fi
    
    if ! grep -q "kuberblue.test/category" "$test_file"; then
        error "Test $test_file missing required annotation: kuberblue.test/category"
        return 1
    fi
    
    return 0
}

function run_chainsaw_tests() {
    local manifest_dir="$1"
    local test_files=()
    local failed_tests=0
    
    # Verify chainsaw is available
    if ! command -v chainsaw >/dev/null 2>&1; then
        error "chainsaw command not found. Please install Chainsaw."
        return 1
    fi
    
    # Discover tests
    if ! readarray -t test_files < <(discover_chainsaw_tests "$manifest_dir"); then
        warn "No tests to run"
        return 0
    fi
    
    # Validate test metadata
    for test_file in "${test_files[@]}"; do
        if ! validate_test_metadata "$test_file"; then
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -gt 0 ]]; then
        error "$failed_tests tests have invalid metadata"
        return 1
    fi
    
    # Execute tests with Chainsaw
    info "Running Chainsaw tests..."
    
    local chainsaw_config="/etc/kuberblue/chainsaw.yaml"
    local chainsaw_args=(
        "test"
        "--config=$chainsaw_config"
        "--test-dir=$manifest_dir"
    )
    
    # Add parallel execution if supported
    if [[ "${CHAINSAW_PARALLEL:-1}" == "1" ]]; then
        chainsaw_args+=("--parallel=4")
    fi
    
    # Execute tests
    if chainsaw "${chainsaw_args[@]}" "${test_files[@]}"; then
        success "All Chainsaw tests passed"
        return 0
    else
        error "Some Chainsaw tests failed"
        return 1
    fi
}

function main() {
    local manifest_dir="${1:-$MANIFEST_BASE_DIR}"
    
    info "Starting Chainsaw test execution"
    info "Manifest directory: $manifest_dir"
    
    if [[ ! -d "$manifest_dir" ]]; then
        error "Manifest directory does not exist: $manifest_dir"
        return 1
    fi
    
    run_chainsaw_tests "$manifest_dir"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Phase 2: Component Test Implementation

#### 2.1 Cilium Network Testing

**File**: `artifacts/overrides_kuberblue/etc/kuberblue/manifests/cilium/cilium_test.yaml`
```yaml
apiVersion: chainsaw.kyverno.io/v1alpha1
kind: Test
metadata:
  name: cilium-networking-test
  annotations:
    kuberblue.test/component: "cilium"
    kuberblue.test/category: "networking"
    kuberblue.test/priority: "high"
    kuberblue.test/timeout: "300s"
spec:
  timeouts:
    apply: 60s
    assert: 300s
    cleanup: 60s
  steps:
  
  # Step 1: Verify Cilium pods are running
  - name: verify-cilium-deployment
    try:
    - assert:
        resource:
          apiVersion: apps/v1
          kind: DaemonSet
          metadata:
            name: cilium
            namespace: kube-system
          status:
            numberReady: ($numberAvailable)
    - assert:
        resource:
          apiVersion: v1
          kind: Pod
          metadata:
            namespace: kube-system
            labels:
              k8s-app: cilium
          status:
            phase: Running
            
  # Step 2: Test pod-to-pod connectivity
  - name: test-pod-connectivity
    try:
    - apply:
        resource:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: cilium-test
    - apply:
        resource:
          apiVersion: v1
          kind: Pod
          metadata:
            name: test-client
            namespace: cilium-test
          spec:
            containers:
            - name: client
              image: curlimages/curl:latest
              command: ['sleep', '3600']
              resources:
                requests:
                  memory: "64Mi"
                  cpu: "50m"
                limits:
                  memory: "128Mi"
                  cpu: "100m"
    - apply:
        resource:
          apiVersion: v1
          kind: Pod
          metadata:
            name: test-server
            namespace: cilium-test
            labels:
              app: test-server
          spec:
            containers:
            - name: server
              image: nginx:alpine
              ports:
              - containerPort: 80
              resources:
                requests:
                  memory: "64Mi"
                  cpu: "50m"
                limits:
                  memory: "128Mi"
                  cpu: "100m"
    - apply:
        resource:
          apiVersion: v1
          kind: Service
          metadata:
            name: test-server-svc
            namespace: cilium-test
          spec:
            selector:
              app: test-server
            ports:
            - port: 80
              targetPort: 80
    - assert:
        resource:
          apiVersion: v1
          kind: Pod
          metadata:
            name: test-client
            namespace: cilium-test
          status:
            phase: Running
    - assert:
        resource:
          apiVersion: v1
          kind: Pod
          metadata:
            name: test-server
            namespace: cilium-test
          status:
            phase: Running
    - script:
        timeout: 60s
        content: |
          # Test direct pod IP connectivity
          SERVER_IP=$(kubectl get pod test-server -n cilium-test -o jsonpath='{.status.podIP}')
          kubectl exec test-client -n cilium-test -- curl -f --max-time 10 "http://${SERVER_IP}/" || exit 1
          
          # Test service connectivity  
          kubectl exec test-client -n cilium-test -- curl -f --max-time 10 "http://test-server-svc/" || exit 1
          
          echo "Pod-to-pod and service connectivity verified"
          
  # Step 3: Test DNS resolution
  - name: test-dns-resolution
    try:
    - script:
        timeout: 30s
        content: |
          # Test cluster DNS resolution
          kubectl exec test-client -n cilium-test -- nslookup kubernetes.default.svc.cluster.local || exit 1
          kubectl exec test-client -n cilium-test -- nslookup test-server-svc.cilium-test.svc.cluster.local || exit 1
          echo "DNS resolution verified"
          
  # Cleanup is automatic due to namespace deletion
  cleanup:
  - delete:
      ref:
        apiVersion: v1
        kind: Namespace
        name: cilium-test
```

#### 2.2 OpenEBS Storage Testing

**File**: `artifacts/overrides_kuberblue/etc/kuberblue/manifests/openebs/openebs_test.yaml`
```yaml
apiVersion: chainsaw.kyverno.io/v1alpha1
kind: Test
metadata:
  name: openebs-storage-test
  annotations:
    kuberblue.test/component: "openebs"
    kuberblue.test/category: "storage"
    kuberblue.test/priority: "high"
    kuberblue.test/timeout: "300s"
spec:
  timeouts:
    apply: 60s
    assert: 300s
    cleanup: 60s
  steps:
  
  # Step 1: Verify OpenEBS components
  - name: verify-openebs-deployment
    try:
    - assert:
        resource:
          apiVersion: storage.k8s.io/v1
          kind: StorageClass
          metadata:
            name: openebs-hostpath
          provisioner: openebs.io/local
    - assert:
        resource:
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: openebs-localpv-provisioner
            namespace: openebs
          status:
            readyReplicas: 1
            
  # Step 2: Test PVC provisioning
  - name: test-pvc-provisioning
    try:
    - apply:
        resource:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: openebs-test
    - apply:
        resource:
          apiVersion: v1
          kind: PersistentVolumeClaim
          metadata:
            name: test-pvc
            namespace: openebs-test
          spec:
            accessModes: ["ReadWriteOnce"]
            storageClassName: openebs-hostpath
            resources:
              requests:
                storage: 1Gi
    - assert:
        resource:
          apiVersion: v1
          kind: PersistentVolumeClaim
          metadata:
            name: test-pvc
            namespace: openebs-test
          status:
            phase: Bound
            
  # Step 3: Test volume mounting
  - name: test-volume-mounting
    try:
    - apply:
        resource:
          apiVersion: v1
          kind: Pod
          metadata:
            name: storage-test-pod
            namespace: openebs-test
          spec:
            containers:
            - name: test-container
              image: busybox:latest
              command:
              - sh
              - -c
              - |
                echo "Testing storage..." > /data/test.txt &&
                cat /data/test.txt &&
                sleep 30
              volumeMounts:
              - name: test-volume
                mountPath: /data
              resources:
                requests:
                  memory: "64Mi"
                  cpu: "50m"
                limits:
                  memory: "128Mi"
                  cpu: "100m"
            volumes:
            - name: test-volume
              persistentVolumeClaim:
                claimName: test-pvc
            restartPolicy: Never
    - assert:
        resource:
          apiVersion: v1
          kind: Pod
          metadata:
            name: storage-test-pod
            namespace: openebs-test
          status:
            phase: Succeeded
    - script:
        timeout: 60s
        content: |
          # Verify file was written successfully
          kubectl logs storage-test-pod -n openebs-test | grep "Testing storage..." || exit 1
          echo "Volume mounting and I/O verified"
          
  cleanup:
  - delete:
      ref:
        apiVersion: v1
        kind: Namespace
        name: openebs-test
```

### Phase 3: Integration with Test Framework

#### 3.1 Update Makefile

**File**: `Makefile` (additions)
```makefile
# Chainsaw-specific test targets
test_kuberblue_chainsaw:
	@echo ">> Running Kuberblue Chainsaw tests"
	@if [ "$(KUBERBLUE)" != "1" ]; then \
		echo "ERROR: KUBERBLUE=1 required for Chainsaw tests"; \
		exit 1; \
	fi
	KUBERBLUE=1 ./tests/kuberblue/chainsaw_runner.sh

test_kuberblue_chainsaw_container:
	@echo ">> Running Kuberblue Chainsaw tests in container"
	@if [ -z "$(IMAGE)" ]; then \
		echo "ERROR: IMAGE variable required"; \
		exit 1; \
	fi
	podman run --rm --privileged \
		--network=host \
		-v /var/run/docker.sock:/var/run/docker.sock:Z \
		-v $(PWD):/workspace:Z \
		-w /workspace \
		$(IMAGE) \
		./tests/kuberblue/chainsaw_runner.sh

# Update main test targets
test_kuberblue: test_kuberblue_container test_kuberblue_components test_kuberblue_chainsaw test_kuberblue_security

# Optional: Chainsaw-only testing
test_chainsaw: test_kuberblue_chainsaw
```

#### 3.2 Update Test Runner

**File**: `tests/run_tests.sh` (additions)
```bash
# Add after existing Kuberblue test logic
if [[ $IS_KUBERBLUE -eq 1 ]]; then
    echo -e "\n>> Running Kuberblue Chainsaw Tests"
    if KUBERBLUE=1 bash "$TEST_DIR/kuberblue/chainsaw_runner.sh" "$@"; then
        echo "✓ Kuberblue Chainsaw tests passed"
    else
        echo "✗ Kuberblue Chainsaw tests failed"
        EXIT_CODE=1
    fi
fi
```

### Phase 4: Documentation and Examples

#### 4.1 Test Writing Guide

**File**: `docs/content/pages/kuberblue-chainsaw-testing.md`
```markdown
# Kuberblue Chainsaw Testing Guide

## Overview

Kuberblue uses Chainsaw for declarative testing of Kubernetes manifests. Tests are co-located with their corresponding manifests using a `*_test.yaml` naming convention.

## Writing Tests

### Basic Test Structure

```yaml
apiVersion: chainsaw.kyverno.io/v1alpha1
kind: Test
metadata:
  name: my-component-test
  annotations:
    kuberblue.test/component: "my-component"
    kuberblue.test/category: "networking|storage|compute|security"
    kuberblue.test/priority: "high|medium|low"
spec:
  steps:
  - name: verify-deployment
    try:
    - assert:
        resource:
          # Kubernetes resource to validate
```

### Required Annotations

- `kuberblue.test/component`: Component being tested
- `kuberblue.test/category`: Test category (networking, storage, compute, security)
- `kuberblue.test/priority`: Test priority (high, medium, low)

### Test Categories

**Networking Tests:**
- Pod-to-pod connectivity
- Service discovery
- DNS resolution
- Network policy enforcement

**Storage Tests:**
- Storage class validation
- PVC provisioning
- Volume mounting
- Data persistence

**Compute Tests:**
- Pod scheduling
- Resource allocation
- Node readiness

**Security Tests:**
- RBAC validation
- Pod security policies
- Secret access

## Running Tests

```bash
# Run all Chainsaw tests
make test_kuberblue_chainsaw

# Run tests in container
make test_kuberblue_chainsaw_container IMAGE=quay.io/immutablue/immutablue:latest

# Run specific component tests
./tests/kuberblue/chainsaw_runner.sh /etc/kuberblue/manifests/cilium
```
```

#### 4.2 Update CLAUDE.md

**File**: `CLAUDE.md` (additions)
```markdown
## Chainsaw Testing
- **Declarative tests**: Co-located YAML tests alongside manifests
- `make test_kuberblue_chainsaw`: Run all Chainsaw tests
- Test naming: `{component}_test.yaml` (e.g., `cilium_test.yaml`)
- Test discovery: Automatic discovery of `*_test.yaml` files
- Required annotations: `kuberblue.test/component`, `kuberblue.test/category`
- Categories: networking, storage, compute, security
```

## Acceptance Criteria

### Functional Requirements
- [ ] Chainsaw binary installed in Kuberblue container image
- [ ] Test discovery framework automatically finds `*_test.yaml` files
- [ ] Tests execute with proper isolation and cleanup
- [ ] Test results integrate with existing test reporting
- [ ] Makefile targets support Chainsaw test execution

### Test Coverage Requirements
- [ ] Cilium networking functionality validation
- [ ] OpenEBS storage provisioning and mounting
- [ ] Basic workload deployment and connectivity
- [ ] DNS resolution and service discovery

### Quality Requirements
- [ ] All tests follow metadata annotation standards
- [ ] Tests execute in under 5 minutes total
- [ ] Tests cleanup resources automatically
- [ ] Test failures provide actionable error messages
- [ ] Documentation covers test writing and execution

### Integration Requirements
- [ ] Tests run in CI/CD pipeline
- [ ] Tests work in both bare metal and containerized environments
- [ ] Tests integrate with existing shell-based test framework
- [ ] Tests support parallel execution where possible

## Testing Strategy

### Unit Testing
- Validate test discovery logic with mock manifest directories
- Test metadata validation with various annotation combinations
- Verify cleanup functionality with resource tracking

### Integration Testing
- Execute tests against real Kuberblue cluster
- Validate cross-component interactions (e.g., networking + storage)
- Test parallel execution with resource conflicts

### Performance Testing
- Measure test execution time with various cluster sizes
- Validate resource cleanup efficiency
- Test timeout handling under resource pressure

## Migration Strategy

### Phase 1: Parallel Implementation
- Implement Chainsaw framework alongside existing shell tests
- Create initial test suite for core components
- Validate integration with existing CI/CD

### Phase 2: Gradual Migration
- Add Chainsaw tests for additional components
- Identify shell tests suitable for migration
- Maintain both testing approaches during transition

### Phase 3: Optimization
- Remove redundant shell tests where Chainsaw provides coverage
- Optimize test execution performance
- Enhance test reporting and debugging capabilities

## Security Considerations

### Test Isolation
- Tests run in dedicated namespaces with automatic cleanup
- Resource quotas prevent test resource exhaustion
- RBAC ensures tests cannot access sensitive cluster resources

### Credential Management
- Tests use service accounts with minimal required permissions
- No hardcoded credentials in test definitions
- Secrets created for tests are automatically cleaned up

## Monitoring and Observability

### Test Metrics
- Test execution time tracking
- Resource utilization monitoring during tests
- Failure rate analysis by component and category

### Logging and Debugging
- Structured test output with component correlation
- Resource state capture on test failures
- Integration with existing log aggregation

## Future Enhancements

### Advanced Test Scenarios
- Multi-cluster testing support
- Chaos engineering integration
- Load testing with realistic workloads

### Enhanced Tooling
- Visual test result dashboards
- Automated test generation from manifests
- Integration with GitOps workflows

---

**Implementation Timeline:** 2-3 weeks  
**Effort Estimate:** Medium  
**Risk Level:** Low  
**Dependencies:** Chainsaw v0.1.7+, Kubernetes 1.28+
