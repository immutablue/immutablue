#!/bin/bash
# Immutablue Test Runner
#
# This is the main test runner script that executes all Immutablue tests.
# It can be used to run all tests with a single command.
#
# Usage: ./run_tests.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference (default: quay.io/immutablue/immutablue:42)
#
# The script will execute all test scripts in the following order:
# - test_shellcheck.sh: Static analysis of all shell scripts (pre-build test)
# - test_container.sh: Basic container tests
# - test_container_qemu.sh: QEMU boot tests
# - test_artifacts.sh: Artifacts and file integrity tests
# - test_setup.sh: Enhanced first-boot setup tests
#
# SKIP_TEST=1 environment variable can be used to skip all tests
#
# Return codes:
# - 0: All tests passed
# - 1: One or more tests failed

# Enable strict error handling
set -euo pipefail

EXIT_CODE=0
TEST_DIR="$(dirname "$(realpath "$0")")" 
IMAGE="${1:-quay.io/immutablue/immutablue:42}"

# Detect if this is a Kuberblue variant
IS_KUBERBLUE=0
if [[ "${KUBERBLUE:-0}" == "1" ]] || [[ "$IMAGE" == *"kuberblue"* ]]; then
    IS_KUBERBLUE=1
fi

# Run all tests
echo "=== Running Immutablue Test Suite ==="
if [[ $IS_KUBERBLUE -eq 1 ]]; then
    echo "Detected Kuberblue variant - including Kuberblue-specific tests"
fi

# Run pre-build tests first
echo -e "\n>> Running Pre-Build Tests (ShellCheck)"
bash "$TEST_DIR/test_shellcheck.sh" --report-only
if [[ $? -ne 0 ]]; then
  EXIT_CODE=1
fi

# Run brew variant tests
echo -e "\n>> Running Brew Variant Tests"
bash "$TEST_DIR/test_brew_variants.sh"
if [[ $? -ne 0 ]]; then
  EXIT_CODE=1
fi

# Run container tests
echo -e "\n>> Running Container Tests"
bash "$TEST_DIR/test_container.sh" "$@"
if [[ $? -ne 0 ]]; then
  EXIT_CODE=1
fi

# Run QEMU container tests
echo -e "\n>> Running QEMU Container Tests"
bash "$TEST_DIR/test_container_qemu.sh" "$@"
if [[ $? -ne 0 ]]; then
  EXIT_CODE=1
fi

# Run artifacts tests
echo -e "\n>> Running Artifacts Tests"
bash "$TEST_DIR/test_artifacts.sh" "$@"
if [[ $? -ne 0 ]]; then
  EXIT_CODE=1
fi

# Run setup tests
echo -e "\n>> Running Setup Tests"
bash "$TEST_DIR/test_setup.sh"
if [[ $? -ne 0 ]]; then
  EXIT_CODE=1
fi

# Run Kuberblue-specific tests if this is a Kuberblue variant
if [[ $IS_KUBERBLUE -eq 1 ]]; then
    echo -e "\n>> Running Kuberblue Container Tests"
    KUBERBLUE=1 bash "$TEST_DIR/kuberblue/test_kuberblue_container.sh" "$@"
    if [[ $? -ne 0 ]]; then
        EXIT_CODE=1
    fi
    
    echo -e "\n>> Running Kuberblue Components Tests"
    KUBERBLUE=1 bash "$TEST_DIR/kuberblue/test_kuberblue_components.sh" "$@"
    if [[ $? -ne 0 ]]; then
        EXIT_CODE=1
    fi
    
    echo -e "\n>> Running Kuberblue Security Tests"
    KUBERBLUE=1 bash "$TEST_DIR/kuberblue/test_kuberblue_security.sh" "$@"
    if [[ $? -ne 0 ]]; then
        EXIT_CODE=1
    fi
    
    echo -e "\n>> Running Kuberblue Chainsaw Tests"
    if KUBERBLUE=1 bash "$TEST_DIR/kuberblue/chainsaw_runner.sh" "$@"; then
        echo "✓ Kuberblue Chainsaw tests passed"
    else
        echo "✗ Kuberblue Chainsaw tests failed"
        EXIT_CODE=1
    fi
    
    # Run cluster tests only if enabled (requires VM environment)
    if [[ "${KUBERBLUE_CLUSTER_TEST:-0}" == "1" ]]; then
        echo -e "\n>> Running Kuberblue Cluster Tests"
        KUBERBLUE=1 KUBERBLUE_CLUSTER_TEST=1 bash "$TEST_DIR/kuberblue/test_kuberblue_cluster.sh" "$@"
        if [[ $? -ne 0 ]]; then
            EXIT_CODE=1
        fi
        
        # Run integration tests only if specifically enabled
        if [[ "${KUBERBLUE_INTEGRATION_TEST:-0}" == "1" ]]; then
            echo -e "\n>> Running Kuberblue Integration Tests"
            KUBERBLUE=1 KUBERBLUE_CLUSTER_TEST=1 KUBERBLUE_INTEGRATION_TEST=1 bash "$TEST_DIR/kuberblue/test_kuberblue_integration.sh" "$@"
            if [[ $? -ne 0 ]]; then
                EXIT_CODE=1
            fi
        fi
    else
        echo -e "\n>> INFO: Set KUBERBLUE_CLUSTER_TEST=1 to enable cluster testing"
        echo -e ">> INFO: Set KUBERBLUE_INTEGRATION_TEST=1 to enable integration testing"
    fi
fi

# Report final results
echo -e "\n=== Test Suite Results ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "ALL TESTS PASSED!"
else
  echo "SOME TESTS FAILED!"
fi

exit $EXIT_CODE