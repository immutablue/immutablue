+++
date = '2025-04-17T23:01:00-05:00'
draft = false
title = 'Testing'
+++

# Testing Immutablue

Immutablue includes a comprehensive set of unit tests to ensure the integrity and functionality of the container image and its components. This document outlines the testing framework, available tests, and how to extend the testing infrastructure.

## Testing Framework Overview

The testing framework is designed to verify key aspects of Immutablue and its variants:

### Core Immutablue Testing
1. **Container Tests**: Basic verification of the container image's functionality and structure
2. **QEMU Tests**: Ensuring the container image can boot properly in a virtualized environment
3. **Artifacts Tests**: Validating that all files in the `artifacts/overrides` directory are correctly included in the container image and haven't been modified
4. **Pre-Build ShellCheck Tests**: Static analysis of all shell scripts to ensure code quality and catch potential bugs

### Kuberblue Testing Framework
For Kuberblue (the Kubernetes distribution variant), additional comprehensive testing is provided:

5. **Kuberblue Container Tests**: Validates Kubernetes binaries, Kuberblue-specific files, systemd services, and configurations
6. **Kuberblue Components Tests**: Tests just commands, manifest deployment capabilities, user management, and script functionality
7. **Kuberblue Security Tests**: Validates RBAC configuration, network policies, pod security contexts, and system security
8. **Kuberblue Cluster Tests**: Tests cluster initialization, networking setup, storage provisioning, and overall health (requires VM environment)
9. **Kuberblue Integration Tests**: End-to-end testing with real workloads, application deployment validation, and functionality verification

The tests are configured to run automatically as part of the build process and can also be executed manually during development. ShellCheck tests run as pre-build tests to ensure code quality before the build process begins, while the other tests run after building the container.

## Running Tests

### Running All Tests

To run all tests:

```bash
make test
```

To run a more detailed test suite with comprehensive reporting:

```bash
make run_all_tests
```

### Skipping Tests

You can skip all tests, including pre-build tests, using the SKIP_TEST option:

```bash
# Skip tests during build
make build SKIP_TEST=1

# Skip tests when running test targets
make test SKIP_TEST=1
make run_all_tests SKIP_TEST=1
```

The SKIP_TEST variable can be used in the following ways:

1. **Skip all tests during build:**
   - `make build SKIP_TEST=1` - Skips pre-build shellcheck and builds without testing
   - Useful for rapid iteration during development

2. **Skip specific test categories:**
   - `make test SKIP_TEST=1` - Skips post-build tests only
   - `make pre_test SKIP_TEST=1` - Skips pre-build tests only
   - Allows selectively running only the tests you need

3. **Skip tests in CI/CD:**
   - Add `SKIP_TEST=1` to your CI/CD configuration
   - Useful for debugging build issues without running tests

By default, SKIP_TEST is set to 0, which means all tests will run. Setting it to 1 will skip tests according to where it's applied.

### Running Individual Test Categories

You can run specific test categories:

```bash
# Run pre-build ShellCheck tests
make pre_test

# Run only container tests
make test_container

# Run only QEMU boot tests
make test_container_qemu

# Run only artifacts tests
make test_artifacts

# Kuberblue-specific test categories
make test_kuberblue_container    # Test Kuberblue container validation
make test_kuberblue_components   # Test Kuberblue components and scripts
make test_kuberblue_security     # Test Kuberblue security configurations
make test_kuberblue_cluster      # Test cluster functionality (requires VM)
make test_kuberblue_integration  # Test integration scenarios (requires cluster)
make test_kuberblue              # Run complete Kuberblue test suite
```

### Running Kuberblue Tests with Different Levels

Kuberblue tests support different execution levels based on available infrastructure:

```bash
# Basic Kuberblue tests (container and components only)
make test_kuberblue

# Enable cluster testing (requires VM environment)
KUBERBLUE_CLUSTER_TEST=1 make test_kuberblue

# Enable full integration testing (requires cluster environment)
KUBERBLUE_INTEGRATION_TEST=1 make test_kuberblue

# Run individual Kuberblue tests directly
./tests/kuberblue/test_kuberblue_container.sh
./tests/kuberblue/test_kuberblue_components.sh
./tests/kuberblue/test_kuberblue_security.sh
```

### Running Tests with Alternative Container Images

By default, the tests use the `quay.io/immutablue/immutablue:42` image. You can specify a different image by setting the `IMAGE` and `TAG` variables:

```bash
# Run tests against a different tag
make TAG=41 test

# Run tests against a different image and tag
make IMAGE=quay.io/myorg/immutablue TAG=custom test
```

## Test Structure

### Container Tests

The container tests (`test_container.sh`) verify:

- Basic container functionality via `bootc container lint`
- Presence of essential packages (`bash`, `systemd`, `make`)
- Directory structure (checking for critical directories)
- Systemd services installation and configuration

These tests ensure the fundamental aspects of the container are working correctly.

### QEMU Container Tests

The QEMU tests (`test_container_qemu.sh`) directly verify container bootability by:

- Exporting the container to a tarball
- Creating a minimal initramfs with busybox
- Booting the container in QEMU with the host's kernel
- Verifying critical Immutablue components and services
- Checking for required directories and systemd units

This provides a comprehensive validation that the container can actually boot and function correctly in a virtualized environment, which is a good proxy for real-world deployment.

The QEMU tests include an intelligent fallback mechanism:
- If QEMU or busybox is not available, it falls back to bootc container lint checks
- If bootc is also not available, it falls back to basic container structure checks
- This ensures tests can still run in environments without all dependencies

### Artifacts Tests

The artifacts tests (`test_artifacts.sh`) verify:

- The directory structure in the `artifacts/overrides` directory
- The presence of required system directories and files
- File integrity validation between the repository and the container

#### File Integrity Checking

One of the most important tests is the file integrity check, which:

1. Finds all files in the `artifacts/overrides` directory
2. Calculates SHA256 checksums for each file
3. Retrieves the corresponding file from the container image
4. Calculates the SHA256 checksum of the container file
5. Compares the checksums to ensure files haven't been modified

This ensures that all files specified in the repository are correctly included in the container and haven't been tampered with during the build process.

### ShellCheck Tests

The ShellCheck tests (`test_shellcheck.sh`) perform static analysis of all shell scripts in the project using the ShellCheck tool. This helps identify:

- Syntax errors and potential bugs
- Common shell script pitfalls and mistakes
- Security vulnerabilities and unsafe practices
- Style inconsistencies and non-portable constructs

#### How ShellCheck Testing Works

The ShellCheck test script:

1. Automatically finds all shell scripts in the project by:
   - Searching for files with `.sh` extension
   - Finding executable files with a bash shebang (`#!/bin/bash`)
   
2. Runs ShellCheck on each script with carefully selected rules:
   - Uses bash as the shell dialect
   - Focuses on warnings and errors (ignores style/info by default)
   - Enables relevant optional checks
   - Excludes specific checks that aren't applicable to the project
   
3. Provides detailed output for any issues found:
   - Line numbers and code context
   - Clear explanation of the problem
   - Suggested fix or best practice reference
   
4. Summarizes test results:
   - Count of files checked
   - Number of files that passed/failed
   - Exit code based on overall success

#### ShellCheck Modes and Integration

The ShellCheck tests offer several modes to adapt to different usage scenarios:

```bash
# Run ShellCheck tests normally (fails if issues are found)
./tests/test_shellcheck.sh

# Run ShellCheck tests with diagnostic mode for manual fixes
./tests/test_shellcheck.sh --fix

# Run ShellCheck tests in report-only mode (always exits with success)
./tests/test_shellcheck.sh --report-only
```

##### Diagnostic Mode (--fix)

The `--fix` mode provides detailed diagnostic information to help developers identify and fix issues:
1. Identifies issues in a shell script
2. Displays specific information about each issue with line numbers
3. Highlights the lines that need manual fixes in a readable format
4. Shows error codes that can be looked up for more information
5. Formats output with bullet points for better readability

**Note**: Despite its name, this mode does NOT automatically fix issues. It provides guidance for manual fixes.

This mode helps address common issues like:
- Double vs. single bracket usage
- Proper variable quoting
- Command substitution safety
- Array handling and expansion
- Return value capturing
- Word splitting prevention
- Unnecessary command usage (like cat)

##### Report-Only Mode (--report-only)

The `--report-only` mode is specifically designed for CI/CD integration:
1. Runs all checks and reports issues
2. Always exits with success (0) even if issues are found
3. Provides the same comprehensive output as normal mode
4. Allows gradual adoption of ShellCheck without breaking existing builds
5. Used by default in the pre-build test phase

This mode ensures that shellcheck issues don't block builds while still making the issues visible in CI/CD logs.

#### ShellCheck Configuration

The project includes a `.shellcheckrc` configuration file in the root directory that:

- Specifies bash as the primary shell dialect
- Sets search paths for sourced files
- Disables certain checks that aren't appropriate for this project
- Configures external source handling

This configuration ensures that ShellCheck validates scripts according to project-specific standards and requirements.

## Kuberblue Testing Framework

The Kuberblue testing framework provides comprehensive validation for the Kubernetes distribution variant of Immutablue. This framework is automatically activated when testing Kuberblue images and includes specialized tests for Kubernetes functionality.

### Kuberblue Container Tests

The Kuberblue container tests (`test_kuberblue_container.sh`) verify:

- **Kubernetes Binaries**: Validates presence and accessibility of `kubeadm`, `kubelet`, `kubectl`, `crio`, and `helm`
- **Kuberblue Directories**: Ensures `/etc/kuberblue` and `/usr/libexec/kuberblue` exist with proper structure
- **Configuration Files**: Verifies kubeadm configuration, manifests directory, and setup scripts
- **Systemd Services**: Validates Kuberblue-specific systemd services and timers
- **User Configuration**: Checks kuberblue user setup and permissions

### Kuberblue Components Tests

The components tests (`test_kuberblue_components.sh`) validate:

- **Just Commands**: Tests all Kuberblue just commands for syntax and basic execution
- **Manifest Deployment**: Validates Helm charts, Kustomize configurations, and raw YAML manifests
- **Script Functionality**: Tests all scripts in `/usr/libexec/kuberblue/` for syntax and functionality
- **User Management**: Validates user creation scripts and kubectl configuration
- **Configuration Files**: Tests kubeadm and system configuration files

### Kuberblue Security Tests

The security tests (`test_kuberblue_security.sh`) verify:

- **RBAC Configuration**: Tests default service account permissions and kuberblue user RBAC
- **Network Policies**: Validates network policy creation and enforcement (if supported by CNI)
- **Pod Security**: Tests security contexts, pod security standards, and privilege restrictions
- **System Security**: Validates SELinux configuration, file permissions, and service security

### Kuberblue Cluster Tests

The cluster tests (`test_kuberblue_cluster.sh`) provide comprehensive cluster validation:

- **Cluster Initialization**: Tests kubeadm cluster initialization with Kuberblue configuration
- **Network Setup**: Validates CNI plugin deployment (Cilium/Flannel) and functionality
- **Storage Setup**: Tests OpenEBS deployment and persistent storage functionality
- **Cluster Health**: Validates overall cluster health and component status

**Requirements**: VM environment with 4GB+ RAM, 4+ CPU cores, and KVM support.

### Kuberblue Integration Tests

The integration tests (`test_kuberblue_integration.sh`) perform end-to-end validation:

- **Application Deployment**: Tests multi-tier application stacks with databases and services
- **Cluster Operations**: Validates scaling, resource management, and operational procedures
- **Stateful Workloads**: Tests StatefulSets, persistent storage, and data persistence
- **Real-World Manifests**: Deploys and validates actual Kuberblue manifests (Cilium, OpenEBS)
- **Functionality Validation**: Ensures deployed applications work correctly, not just deploy successfully

**Requirements**: Full cluster environment with network connectivity for external validation.

### Kuberblue Helper Utilities

The framework includes specialized helper utilities:

- **`cluster_utils.sh`**: Cluster management, pod readiness, and resource cleanup
- **`manifest_utils.sh`**: Helm chart validation, Kustomize testing, and manifest deployment
- **`network_utils.sh`**: Network connectivity testing, service discovery, and CNI validation

### Kuberblue Test Fixtures

Test fixtures provide realistic testing scenarios:

- **Sample Configurations**: Test kubeadm configurations and system settings
- **Helm Charts**: Complete test chart with templates, values, and metadata
- **Kustomize Overlays**: Base configurations with environment-specific overlays
- **Test Scripts**: Helper scripts for cluster setup and network validation

### Environment Variables

Kuberblue tests use environment variables for flexible execution:

- `KUBERBLUE_CLUSTER_TEST=1`: Enables cluster-level testing requiring VM environment
- `KUBERBLUE_INTEGRATION_TEST=1`: Enables full integration testing requiring cluster
- These variables allow selective execution based on available infrastructure

## Extending the Test Suite

### Adding New Container Tests

To add new container tests:

1. Open `tests/test_container.sh`
2. Add a new test function following the existing pattern:
   ```bash
   function test_new_feature() {
     echo "Testing new feature"
     
     # Run test command
     if ! podman run --rm "$IMAGE" command_to_test; then
       echo "FAIL: New feature test failed"
       return 1
     fi
     
     echo "PASS: New feature test passed"
     return 0
   }
   ```
3. Add your test function to the test runner section:
   ```bash
   if ! test_new_feature; then
     ((FAILED++))
   fi
   ```

### Adding New QEMU Tests

To add new QEMU-based tests:

1. Open `tests/test_container_qemu.sh`
2. Add a new test function that verifies boot-related or hardware-related functionality
3. Add your test to the runner section like with container tests

### Adding New Artifacts Tests

To add new artifact validation tests:

1. Open `tests/test_artifacts.sh`
2. Add a new test function that verifies specific directory structures or file content
3. Add your test to the runner section

### Adding New Kuberblue Tests

To add new Kuberblue-specific tests:

1. **For Container Tests**: Add functions to `tests/kuberblue/test_kuberblue_container.sh`
2. **For Components Tests**: Add functions to `tests/kuberblue/test_kuberblue_components.sh`
3. **For Security Tests**: Add functions to `tests/kuberblue/test_kuberblue_security.sh`
4. **For Cluster Tests**: Add functions to `tests/kuberblue/test_kuberblue_cluster.sh`
5. **For Integration Tests**: Add functions to `tests/kuberblue/test_kuberblue_integration.sh`

Follow the existing pattern:

```bash
function test_new_kuberblue_feature() {
    echo "Testing new Kuberblue feature"
    
    # Ensure cluster is initialized (for cluster/integration tests)
    if ! is_cluster_initialized; then
        echo "SKIP: Cluster not initialized, skipping test"
        return 0
    fi
    
    # Use helper utilities
    source "$TEST_DIR/helpers/cluster_utils.sh"
    
    # Run test logic
    if ! kubectl get nodes >/dev/null 2>&1; then
        echo "FAIL: New feature test failed"
        return 1
    fi
    
    echo "PASS: New feature test passed"
    return 0
}
```

### Creating New Helper Utilities

To add new helper functions:

1. Create new files in `tests/kuberblue/helpers/` or extend existing ones
2. Follow the pattern of existing helpers with proper error handling
3. Include cleanup functions for resource management
4. Source helpers in test scripts that need them

### Adding Test Fixtures

To add new test fixtures:

1. **Configurations**: Add to `tests/kuberblue/fixtures/configs/`
2. **Manifests**: Add to `tests/kuberblue/fixtures/manifests/`
3. **Scripts**: Add to `tests/kuberblue/fixtures/scripts/`
4. Make scripts executable and include proper documentation

### Adding Test Documentation

When adding new tests, be sure to:

1. Update this documentation page with details about the new tests
2. Add comprehensive comments to your test functions
3. Update the README.md in the tests directory
4. Include environment variable requirements and usage

## Continuous Integration

The test suite is designed to be integrated into CI/CD pipelines. When setting up CI for Immutablue, make sure to:

1. Run `make test` as part of your pipeline
2. Ensure the build environment has access to podman and bootc
3. Set up appropriate error handling for test failures

## Test File Organization

The test files are organized as follows:

### Core Immutablue Tests
- `tests/test_container.sh`: Container tests
- `tests/test_container_qemu.sh`: QEMU-based tests (includes Kuberblue support)
- `tests/test_artifacts.sh`: Artifacts and file integrity tests
- `tests/test_shellcheck.sh`: ShellCheck static analysis tests
- `tests/run_tests.sh`: Master test runner script (detects and runs Kuberblue tests)
- `tests/README.md`: Test documentation for developers
- `.shellcheckrc`: ShellCheck configuration file (in project root)

### Kuberblue Testing Framework
- `tests/kuberblue/test_kuberblue_container.sh`: Kuberblue container validation
- `tests/kuberblue/test_kuberblue_components.sh`: Components and scripts testing
- `tests/kuberblue/test_kuberblue_security.sh`: Security configuration validation
- `tests/kuberblue/test_kuberblue_cluster.sh`: Cluster functionality testing
- `tests/kuberblue/test_kuberblue_integration.sh`: Integration and end-to-end testing
- `tests/kuberblue/helpers/cluster_utils.sh`: Cluster management utilities
- `tests/kuberblue/helpers/manifest_utils.sh`: Manifest validation utilities
- `tests/kuberblue/helpers/network_utils.sh`: Network testing utilities
- `tests/kuberblue/fixtures/configs/`: Sample configurations for testing
- `tests/kuberblue/fixtures/manifests/`: Test Helm charts, Kustomize overlays, and YAML
- `tests/kuberblue/fixtures/scripts/`: Helper scripts for test scenarios

## Future Improvements

Future improvements to the testing framework could include:

1. **Integration Testing**: Testing the interaction between multiple components
2. **Performance Testing**: Benchmarking container startup times and resource usage
3. **Security Testing**: Scanning for CVEs and security vulnerabilities
4. **Automated UI Testing**: For desktop environments included in the container
5. **Extended QEMU Testing**: Further enhance the QEMU tests to:
   - Boot with UEFI instead of direct kernel boot
   - Test with multiple architectures (aarch64, etc.)
   - Validate more specific functionality after boot
6. **Enhanced Shell Script Testing**:
   - Integration with pre-commit hooks for git
   - Expanded coverage for more script types
   - Custom rules for Immutablue-specific conventions

## Troubleshooting

### Common Issues

- **Image Not Found**: Ensure the container image exists and is properly tagged
- **Missing bootc**: Install bootc with `dnf install bootc`
- **Permission Issues**: Ensure podman can be run without sudo
- **Missing KVM**: For full QEMU tests, KVM needs to be available
- **QEMU Test Failures**: The QEMU tests require:
  - QEMU installed with `dnf install qemu-system-x86`
  - Busybox installed with `dnf install busybox`
  - A working kernel with appropriate modules
  - Access to create temporary files and launch QEMU processes
- **ShellCheck Not Found**: Install ShellCheck with `dnf install ShellCheck`
- **ShellCheck Failures**: Common causes of ShellCheck failures:
  - Single brackets `[ ]` instead of double brackets `[[ ]]`
  - Unquoted variables that should be quoted
  - Unsafe command substitution without quoting
  - Missing error handling in scripts
- **Kuberblue Test Failures**: Common causes specific to Kuberblue:
  - Missing kubectl: Install with `dnf install kubernetes-client`
  - Missing helm: Install with `dnf install helm`
  - Insufficient VM resources: Ensure 4GB+ RAM and 4+ CPU cores
  - Network connectivity issues: Check firewall and DNS settings
  - Cluster initialization timeout: Increase `QEMU_TIMEOUT` for slower systems
  - Missing test fixtures: Ensure all fixture files are present and executable

### Debugging Tests

To debug test failures:

1. Run individual test scripts directly
2. Add `set -x` to the test scripts to enable verbose output
3. Check container logs with `podman logs`
4. Inspect the container interactively with `podman run --rm -it $IMAGE /bin/bash`
5. For QEMU test failures:
   - Modify the QEMU test script to preserve temporary files (`rm -rf "$TEMP_DIR"` → `echo "Temp files at: $TEMP_DIR"`)
   - Examine the QEMU log and container tar file in the temporary directory
   - Try running QEMU manually with the generated files
   - Adjust timeouts and memory settings if needed
6. For ShellCheck failures:
   - Run ShellCheck directly on the failing script: `shellcheck scripts/failing_script.sh`
   - Use the `--format=json` option to get detailed information: `shellcheck --format=json scripts/failing_script.sh`
   - Try the auto-fix mode: `./tests/test_shellcheck.sh --fix`
   - Check the ShellCheck wiki for information on specific error codes: `https://github.com/koalaman/shellcheck/wiki/SC####` (replace #### with the error code)
7. For Kuberblue test failures:
   - Check cluster status: `kubectl cluster-info` and `kubectl get nodes`
   - Examine pod logs: `kubectl logs -n kube-system <pod-name>`
   - Review test resource cleanup: `kubectl get all --all-namespaces -l test=kuberblue`
   - Enable verbose mode: Add `set -x` to specific test functions
   - Check environment variables: `echo $KUBERBLUE_CLUSTER_TEST $KUBERBLUE_INTEGRATION_TEST`
   - Run individual helper functions: `source tests/kuberblue/helpers/cluster_utils.sh && get_cluster_debug_info`
   - Test cluster connectivity: `kubectl run debug --image=busybox --rm -it -- sh`
   - Check VM resources: Monitor CPU, memory, and disk usage during tests

## Conclusion

The Immutablue testing framework provides a robust mechanism for ensuring the quality and integrity of the container image and its variants. The comprehensive Kuberblue testing framework adds specialized validation for Kubernetes deployments, ensuring that the entire Kubernetes distribution works correctly from container validation through cluster operations to real-world workload deployment.

By following the patterns established in the existing tests, developers can extend the test suite to cover new functionality and edge cases, ensuring that both Immutablue and Kuberblue remain stable and reliable for users. The modular architecture allows for selective test execution based on available infrastructure, making the framework adaptable to different development and CI/CD environments.