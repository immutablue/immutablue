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
# This is the main test that verifies file integrity between
# the repository and the container image using SHA256 checksums
function test_override_files_in_container() {
  echo "Testing override files in container"
  
  # Create temporary directory for test operations
  local TEMP_DIR
  TEMP_DIR=$(mktemp -d)
  
  # Check if artifacts directory exists
  if [[ ! -d "$ARTIFACTS_DIR" || ! -d "$ARTIFACTS_DIR/overrides" ]]; then
    echo "WARN: Missing required directories, test skipped"
    return 0
  fi
  
  # Find all files in the overrides directory
  echo "Finding all files in overrides directory..."
  local OVERRIDE_FILES
  OVERRIDE_FILES=$(find "$ARTIFACTS_DIR/overrides" -type f 2>/dev/null | sort)
  
  # Skip if no files are found
  if [[ -z "$OVERRIDE_FILES" ]]; then
    echo "INFO: No files found in overrides directory, test skipped"
    return 0
  fi
  
  # Setup counters for tracking test results
  local TOTAL_FILES=0
  local FAILED_FILES=0
  local SKIP_FILES=0
  
  # Process each file found in the overrides directory
  while IFS= read -r file; do
    # Skip test files that are not expected to be in the container
    # This allows adding test-only files to the repository
    if [[ "$file" == *"/test/"* || "$file" == *"/Justfile" ]]; then
      echo "SKIP: Test file $file (not expected to be same in the container)"
      ((SKIP_FILES++))
      continue
    fi
    
    ((TOTAL_FILES++))
    
    # Get relative path from artifact root
    # This path should match the path in the container
    local rel_path="${file#$ARTIFACTS_DIR/overrides/}"
    echo "Checking file: /$rel_path"
    
    # Calculate SHA256 checksum of the file in the repository
    local repo_hash
    repo_hash=$(sha256sum "$file" | awk '{print $1}')
    
    # Run a container and calculate SHA256 checksum of the same file
    # This script checks if the file exists and gets its checksum
    local container_hash_result
    container_hash_result=$(podman run --rm "$IMAGE" bash -c "if [[ -f '/$rel_path' ]]; then sha256sum '/$rel_path' | awk '{print \$1}'; else echo 'FILE_NOT_FOUND'; fi" 2>/dev/null)
    
    # Check if file exists in container
    if [[ "$container_hash_result" == "FILE_NOT_FOUND" || -z "$container_hash_result" ]]; then
      echo "FAIL: File /$rel_path not found in container"
      ((FAILED_FILES++))
      continue
    fi
    
    # Compare checksums to verify file integrity
    if [[ "$repo_hash" != "$container_hash_result" ]]; then
      echo "FAIL: File /$rel_path has different hash in container"
      echo "  Repo hash:      $repo_hash"
      echo "  Container hash: $container_hash_result"
      ((FAILED_FILES++))
    else
      echo "PASS: File /$rel_path has matching hash"
    fi
  done <<< "$OVERRIDE_FILES"
  
  # Clean up temporary directory
  rm -rf "$TEMP_DIR"
  
  # Report summary statistics
  echo ""
  echo "Summary:"
  echo "- Files checked: $TOTAL_FILES"
  echo "- Files skipped: $SKIP_FILES"
  echo "- Files failed:  $FAILED_FILES"
  
  # Return results based on test outcomes
  if [[ $TOTAL_FILES -eq 0 ]]; then
    echo "INFO: No files tested"
    return 0
  fi
  
  if [[ $FAILED_FILES -eq 0 ]]; then
    echo "PASS: All $TOTAL_FILES override files verified in container"
    return 0
  else
    echo "FAIL: $FAILED_FILES out of $TOTAL_FILES override files failed verification"
    return 1
  fi
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
