#!/bin/bash
# Container Tests for Immutablue
#
# This script tests basic functionality of the Immutablue container image, including:
# - bootc container lint validation
# - Essential packages verification
# - Directory structure validation
# - Systemd services verification
#
# It can be run directly or through the Makefile with 'make test_container'
#
# Usage: ./test_container.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference (default: quay.io/immutablue/immutablue:42)

# Enable strict error handling
set -euo pipefail

echo "Running container tests for Immutablue"

# Test variables
# Use the first argument as the image name, or default to a standard value
IMAGE="${1:-quay.io/immutablue/immutablue:42}"
TEST_DIR="$(dirname "$(realpath "$0")")" 
ROOT_DIR="$(dirname "$TEST_DIR")"

# Helper functions

# Test bootc container lint functionality
# This verifies the container image is compatible with bootc
# and meets the basic requirements for a bootable container
function test_bootc_lint() {
  echo "Testing bootc container lint on $IMAGE"

  # Run a container with bootc container lint
  # This performs static analysis checks on the container image
  if ! podman run --rm "$IMAGE" bootc container lint; then
    echo "FAIL: bootc container lint failed"
    return 1
  fi
  echo "PASS: bootc container lint succeeded"
  return 0
}

# Test container contents using crispy validation script
# Runs packages, directories, and systemd service checks in a single
# container invocation instead of spawning one per check
function test_container_contents() {
  echo "Testing container contents via crispy"

  # Check if the crispy validation script exists
  local CRISPY_SCRIPT="${TEST_DIR}/crispy/validate_container.c"
  if [[ ! -f "$CRISPY_SCRIPT" ]]; then
    echo "FAIL: Missing crispy validation script at ${CRISPY_SCRIPT}"
    return 1
  fi

  # Run all checks (packages, dirs, services) inside one container
  if ! podman run --rm \
    -v "${CRISPY_SCRIPT}:/tmp/validate_container.c:ro,z" \
    "$IMAGE" \
    crispy --cache-dir /tmp -n /tmp/validate_container.c; then
    echo "FAIL: Container content validation failed"
    return 1
  fi

  echo "PASS: Container content validation succeeded"
  return 0
}

# Run tests
echo "=== Running Tests ==="
FAILED=0

# bootc lint still runs separately (needs its own container invocation)
if ! test_bootc_lint; then
  ((FAILED++))
fi

# All other checks consolidated into one container run
if ! test_container_contents; then
  ((FAILED++))
fi

# Report test results
echo "=== Test Results ==="
if [[ $FAILED -eq 0 ]]; then
  echo "All tests PASSED!"
  exit 0
else
  echo "$FAILED tests FAILED!"
  exit 1
fi
