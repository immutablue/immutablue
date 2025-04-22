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

# Run all tests
echo "=== Running Immutablue Test Suite ==="

# Run pre-build tests first
echo -e "\n>> Running Pre-Build Tests (ShellCheck)"
bash "$TEST_DIR/test_shellcheck.sh" --report-only
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

# Report final results
echo -e "\n=== Test Suite Results ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "ALL TESTS PASSED!"
else
  echo "SOME TESTS FAILED!"
fi

exit $EXIT_CODE