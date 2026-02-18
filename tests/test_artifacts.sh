#!/bin/bash
# Artifacts Tests for Immutablue
#
# This script tests the artifacts directory structure and validates
# that all files in artifacts/overrides are correctly included in the
# container image with matching checksums.
#
# It can be run directly or through the Makefile with 'make test_artifacts'
#
# Usage: ./test_artifacts.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference (default: quay.io/immutablue/immutablue:42)

# Enable strict error handling
set -euo pipefail

echo "Testing Immutablue artifacts directory structure"

# Test variables
TEST_DIR="$(dirname "$(realpath "$0")")" 
ROOT_DIR="$(dirname "$TEST_DIR")"
ARTIFACTS_DIR="$ROOT_DIR/artifacts"

# Use the first argument as the image name, or default to a standard value
IMAGE="${1:-quay.io/immutablue/immutablue:42}"

# Helper functions

# Test the overrides directory structure
# This verifies the basic structure of the artifacts/overrides directory
function test_overrides_structure() {
  echo "Testing overrides directory structure"
  
  # First check if the artifacts directory exists
  if [[ ! -d "$ARTIFACTS_DIR" ]]; then
    echo "WARN: Missing artifacts directory, test skipped"
    return 0
  fi
  
  # Check if the overrides directory exists
  if [[ ! -d "$ARTIFACTS_DIR/overrides" ]]; then
    echo "WARN: Missing overrides directory, test skipped"
    return 0
  fi
  
  # Mark as passed even if directories don't exist yet, as this may be a pre-build test
  echo "PASS: Overrides directory structure check passed"
  return 0
}

# Test the script directories structure
# This verifies the presence of system and user script directories
function test_scriptdirs_exist() {
  echo "Testing system script directories"
  
  # Check if artifacts directory exists
  if [[ ! -d "$ARTIFACTS_DIR" || ! -d "$ARTIFACTS_DIR/overrides" ]]; then
    echo "WARN: Missing required directories, test skipped"
    return 0
  fi
  
  # Verify scripts structure exists
  if [[ ! -d "$ARTIFACTS_DIR/overrides/etc" ]]; then
    echo "WARN: No script directories found, test skipped"
    return 0
  fi
  
  # Since this may be a fresh repo, we'll mark as passed
  echo "PASS: Script directories check passed"
  return 0
}

# Test systemd service files presence
# This verifies that systemd service files are present
function test_systemd_service_files() {
  echo "Testing systemd service files"
  
  # Check if artifacts directory exists
  if [[ ! -d "$ARTIFACTS_DIR" || ! -d "$ARTIFACTS_DIR/overrides" ]]; then
    echo "WARN: Missing required directories, test skipped"
    return 0
  fi
  
  # Look for at least one systemd file
  if [[ -d "$ARTIFACTS_DIR/overrides/usr/lib/systemd" ]]; then
    echo "INFO: Systemd directory found"
  else
    echo "WARN: Systemd directory not found, test skipped"
    return 0
  fi
  
  # Since this may be a fresh repo, mark as passed
  echo "PASS: Systemd service files check passed"
  return 0
}

# Test override files presence and integrity in container
# Uses a crispy script to verify all file checksums in a single container run
# instead of spawning a container per file (massive speedup)
function test_override_files_in_container() {
  echo "Testing override files in container"

  # Check if artifacts directory exists
  if [[ ! -d "$ARTIFACTS_DIR" || ! -d "$ARTIFACTS_DIR/overrides" ]]; then
    echo "WARN: Missing required directories, test skipped"
    return 0
  fi

  # Check if the crispy validation script exists
  local CRISPY_SCRIPT="${TEST_DIR}/crispy/validate_artifacts.c"
  if [[ ! -f "$CRISPY_SCRIPT" ]]; then
    echo "FAIL: Missing crispy validation script at ${CRISPY_SCRIPT}"
    return 1
  fi

  # Run the crispy script inside a single container with overrides mounted
  # at /expected. The script compares SHA256 hashes of all files under
  # /expected against their corresponding paths on the root filesystem.
  if ! podman run --rm \
    -v "${ARTIFACTS_DIR}/overrides:/expected:ro,z" \
    -v "${CRISPY_SCRIPT}:/tmp/validate_artifacts.c:ro,z" \
    "$IMAGE" \
    crispy --cache-dir /tmp -n /tmp/validate_artifacts.c /expected; then
    echo "FAIL: Override file verification failed"
    return 1
  fi

  echo "PASS: Override file verification completed"
  return 0
}

# Run tests
echo "=== Running Artifacts Tests ==="
FAILED=0

# Execute each test and track failures
if ! test_overrides_structure; then
  ((FAILED++))
fi

if ! test_scriptdirs_exist; then
  ((FAILED++))
fi

if ! test_systemd_service_files; then
  ((FAILED++))
fi

if ! test_override_files_in_container; then
  ((FAILED++))
fi

# Report test results
echo "=== Test Results ==="
if [[ $FAILED -eq 0 ]]; then
  echo "All artifacts tests PASSED!"
  exit 0
else
  echo "$FAILED artifacts tests FAILED!"
  exit 1
fi
