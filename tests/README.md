# Immutablue Testing

This directory contains tests for the Immutablue container image and related artifacts.

## Test Structure

The tests are organized into the following categories:

1. **Container Tests** (`test_container.sh`): Basic tests for the container image, including:
   - bootc lint functionality
   - Essential packages verification
   - Directory structure validation
   - Systemd services verification

2. **QEMU Container Tests** (`test_container_qemu.sh`): Advanced tests that use QEMU to boot the container image and verify its functionality.

3. **Artifacts Tests** (`test_artifacts.sh`): Tests to verify the structure and presence of essential files in the artifacts directory. This includes:
   - Directory structure validation
   - Verification that files in artifacts/overrides exist in the container
   - SHA256 checksum comparison between repo files and container files
   - Detailed reporting of file integrity

4. **Pre-Build ShellCheck Tests** (`test_shellcheck.sh`): Static analysis of shell scripts using ShellCheck to identify:
   - Common shell script bugs and issues
   - Best practices violations
   - Potential security vulnerabilities
   - Style inconsistencies
   - This test runs automatically before the build process
   - Integrated with CI/CD through the `--report-only` mode
   - Comprehensive diagnostics through the `--fix` mode (shows issues that need manual fixes)

5. **Kuberblue Tests** (`kuberblue/`): Comprehensive testing framework for Kuberblue Kubernetes distribution:
   - **Container Tests** (`test_kuberblue_container.sh`): Validates Kubernetes binaries, Kuberblue-specific files, systemd services, and configurations
   - **Components Tests** (`test_kuberblue_components.sh`): Tests just commands, manifest deployment, user management, and script functionality
   - **Security Tests** (`test_kuberblue_security.sh`): Validates RBAC configuration, network policies, pod security, and system security
   - **Cluster Tests** (`test_kuberblue_cluster.sh`): Tests cluster initialization, networking, storage, and health (requires VM environment)
   - **Integration Tests** (`test_kuberblue_integration.sh`): End-to-end testing with real workloads and application deployment validation
   - **Helper Utilities**: Modular utilities for cluster management, manifest validation, and network testing
   - **Test Fixtures**: Sample configurations, manifests, and scripts for comprehensive testing scenarios

## Running Tests

You can run individual tests or all tests together using the Makefile targets:

```bash
# Run all tests (excluding pre-build tests)
make test

# Run pre-build shellcheck test explicitly
make pre_test

# Skip all tests (including pre-build tests)
make build SKIP_TEST=1
make test SKIP_TEST=1

# Run individual test categories
make test_container
make test_container_qemu
make test_artifacts

# Run the shell script linting with detailed diagnostics
./tests/test_shellcheck.sh --fix

# Run the shell script linting in report-only mode (always exits with success)
./tests/test_shellcheck.sh --report-only

# Run the full test suite with detailed output
make run_all_tests

# Skip specific test suite
make run_all_tests SKIP_TEST=1

# Kuberblue-specific tests
make test_kuberblue_container          # Test container image validation
make test_kuberblue_components         # Test components and scripts
make test_kuberblue_security          # Test security configurations
make test_kuberblue_cluster           # Test cluster functionality (requires VM)
make test_kuberblue_integration       # Test integration scenarios (requires cluster)
make test_kuberblue                   # Run complete Kuberblue test suite

# Enable cluster testing (requires VM environment)
KUBERBLUE_CLUSTER_TEST=1 make test_kuberblue

# Enable integration testing (requires full cluster environment) 
KUBERBLUE_INTEGRATION_TEST=1 make test_kuberblue

# Run Kuberblue tests directly
./tests/kuberblue/test_kuberblue_container.sh
./tests/kuberblue/test_kuberblue_components.sh
./tests/kuberblue/test_kuberblue_security.sh

# Run all tests for a specific Kuberblue image
./tests/run_tests.sh quay.io/immutablue/immutablue:42-kuberblue
```

## Requirements

To run these tests, you need:

### Basic Requirements
- bootc
- podman
- qemu (for the QEMU tests)
- KVM access (for the QEMU tests)
- shellcheck (for the shell script tests)

### Kuberblue-Specific Requirements
- kubectl (for cluster tests)
- helm (for Helm chart validation)
- python3 with yaml module (for configuration validation)
- VM environment with sufficient resources for cluster tests:
  - 4GB+ RAM
  - 4+ CPU cores
  - Hardware virtualization support (KVM/VT-x)
- Network connectivity for external validation tests

## Adding New Tests

When adding new tests:

### For General Immutablue Tests
1. Create a new test script in the `tests` directory
2. Add a corresponding target in the Makefile
3. Update the `run_tests.sh` script to include your new test
4. Update the appropriate section (pre-build tests, regular tests) and target dependency list
5. If it's a pre-build test, add it to the `pre_test` target
6. If it's a regular test, add it to the `test` target dependency list

### For Kuberblue-Specific Tests
1. Create new test scripts in the `tests/kuberblue/` directory
2. Use the helper utilities in `tests/kuberblue/helpers/` for common operations
3. Add test fixtures in `tests/kuberblue/fixtures/` for sample configurations
4. Follow the existing pattern with error handling: `set -euo pipefail`
5. Include proper cleanup functions to remove test resources
6. Use environment variables to control test execution:
   - `KUBERBLUE_CLUSTER_TEST=1` for cluster-level tests
   - `KUBERBLUE_INTEGRATION_TEST=1` for integration tests
7. Add corresponding Makefile targets for the new tests
8. Update the main test runner to include the new Kuberblue tests

### Test Categories
- **Container Tests**: Basic validation without cluster requirement
- **Components Tests**: Script and configuration validation
- **Security Tests**: Security configuration validation
- **Cluster Tests**: Require running Kubernetes cluster
- **Integration Tests**: End-to-end scenarios with real workloads

### Best Practices
- Use the existing helper functions for common operations
- Include both positive and negative test cases
- Provide clear error messages and debugging information
- Use timeouts for operations that might hang
- Clean up resources in failure scenarios
- Follow the shellcheck guidelines for script quality