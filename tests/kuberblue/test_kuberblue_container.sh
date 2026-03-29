#!/bin/bash
# Kuberblue Container Tests
#
# Runs validate_kuberblue_container.c inside the container via crispy.
# The crispy script handles all checks (packages, binaries, files,
# V2 layout, system configs, systemd services) in a single container run.
#
# Usage: ./test_kuberblue_container.sh [IMAGE_NAME:TAG]

set -euo pipefail

echo "Running Kuberblue container tests"

IMAGE="${1:-quay.io/immutablue/immutablue:42}"
TEST_DIR="$(dirname "$(realpath "$0")")"

# Validate this is a Kuberblue image
if [[ "${KUBERBLUE:-0}" != "1" ]] && [[ "$IMAGE" != *"kuberblue"* ]]; then
  echo "ERROR: This test requires a Kuberblue image or KUBERBLUE=1 environment variable"
  echo "Please build with: make KUBERBLUE=1 build"
  echo "Then run with: make KUBERBLUE=1 test_kuberblue_container"
  echo "Current image: $IMAGE"
  exit 1
fi

CRISPY_SCRIPT="${TEST_DIR}/validate_kuberblue_container.c"

if [[ ! -f "$CRISPY_SCRIPT" ]]; then
  echo "FAIL: Missing crispy validation script at ${CRISPY_SCRIPT}"
  exit 1
fi

echo "=== Running Kuberblue Container Tests ==="

if ! podman run --rm \
  -v "${CRISPY_SCRIPT}:/tmp/validate_kuberblue_container.c:ro,z" \
  "$IMAGE" \
  crispy --cache-dir /tmp -n /tmp/validate_kuberblue_container.c; then
  echo "FAIL: Kuberblue container validation failed"
  exit 1
fi

echo "All Kuberblue container tests PASSED!"
exit 0
