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
  
  # First, pull the image
  # Actually there is no reason to pull the image. We are going to use the local copy
  # if ! podman pull "$IMAGE"; then
  #   echo "FAIL: Failed to pull the image"
  #   return 1
  # fi
  
  # Run a container with bootc container lint
  # This performs static analysis checks on the container image
  if ! podman run --rm "$IMAGE" bootc container lint; then
    echo "FAIL: bootc container lint failed"
    return 1
  fi
  echo "PASS: bootc container lint succeeded"
  return 0
}

# Test for required packages in the container
# Verifies essential system packages are present
function test_container_packages() {
  echo "Testing essential packages in container"
  # Run a container and check for critical packages
  if ! podman run --rm "$IMAGE" rpm -q bash systemd make; then
    echo "FAIL: Essential packages check failed"
    return 1
  fi
  echo "PASS: Essential packages check succeeded"
  return 0
}

# Test the directory structure in the container
# Verifies critical directories for Immutablue functionality
function test_container_directory_structure() {
  echo "Testing directory structure in container"
  # Test for essential directories that must exist for Immutablue to function
  if ! podman run --rm "$IMAGE" bash -c "test -d /usr/libexec/immutablue && test -d /etc/immutablue"; then
    echo "FAIL: Directory structure check failed"
    return 1
  fi
  echo "PASS: Directory structure check succeeded"
  return 0
}

# Test systemd services in the container
# Verifies Immutablue services are properly installed
function test_services_installed() {
  echo "Testing systemd services in container"
  # Check for Immutablue systemd services
  if ! podman run --rm "$IMAGE" bash -c "systemctl list-unit-files | grep immutablue"; then
    echo "FAIL: Systemd services check failed"
    return 1
  fi
  echo "PASS: Systemd services check succeeded"
  return 0
}

# Run tests
echo "=== Running Tests ==="
FAILED=0

# Execute each test and track failures
if ! test_bootc_lint; then
  ((FAILED++))
fi

if ! test_container_packages; then
  ((FAILED++))
fi

if ! test_container_directory_structure; then
  ((FAILED++))
fi

if ! test_services_installed; then
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
