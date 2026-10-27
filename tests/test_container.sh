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

# Backend-neutral content check for images that are not fedora-bootc.
#
# validate_container.c is a crispy script with a Fedora rpm list and needs
# crispy itself, which only ships where the in-house deps are built. Other
# backends get the checks that hold everywhere: Immutablue's tree, its
# commands, and its systemd units; packages are covered by
# test_package_presence.sh through each backend's own package manager.
function test_container_contents_generic() {
  echo "Testing container contents (backend ${IMAGE_BACKEND})"

  if ! podman run --rm --entrypoint "" "$IMAGE" bash -c '
      set -u
      rc=0
      for path in /usr/immutablue/packages.yaml /usr/immutablue/backend \
                  /usr/bin/immutablue /usr/bin/immutablue-backend /usr/bin/immutablue-settings \
                  /usr/libexec/immutablue/immutablue-header.sh /usr/share/immutablue/image-info.json
      do
          [[ -e "${path}" ]] || { echo "missing: ${path}"; rc=1; }
      done
      if command -v systemctl > /dev/null
      then
          for unit in immutablue-first-boot.service immutablue-onboot.service immutablue-daily.timer
          do
              systemctl is-enabled "${unit}" > /dev/null 2>&1 || { echo "not enabled: ${unit}"; rc=1; }
          done
      fi
      [[ "$(immutablue-backend name)" == "$(cat /usr/immutablue/backend)" ]] || { echo "immutablue-backend disagrees with /usr/immutablue/backend"; rc=1; }
      exit ${rc}
  '; then
    echo "FAIL: Container content validation failed"
    return 1
  fi

  echo "PASS: Container content validation succeeded"
  return 0
}

IMAGE_BACKEND="$(podman run --rm --entrypoint "" "$IMAGE" cat /usr/immutablue/backend 2>/dev/null || true)"
IMAGE_BACKEND="${IMAGE_BACKEND:-fedora-bootc}"

# Run tests
echo "=== Running Tests ==="
FAILED=0

# bootc lint still runs separately (needs its own container invocation)
# Only bootc images can be linted by bootc; a freebsd-be image is delivered as
# a ZFS boot environment instead.
LINT_BACKEND="$(podman run --rm --entrypoint "" "$IMAGE" sh -c 'cat /usr/immutablue/backend' 2>/dev/null || true)"
if [[ "${LINT_BACKEND}" == "freebsd-be" ]]; then
  echo "SKIP: bootc container lint (freebsd-be images are boot environments, not bootc images)"
elif ! test_bootc_lint; then
  ((FAILED++))
fi

# All other checks consolidated into one container run
if [[ "${IMAGE_BACKEND}" == "fedora-bootc" ]]; then
  if ! test_container_contents; then
    ((FAILED++))
  fi
elif ! test_container_contents_generic; then
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
