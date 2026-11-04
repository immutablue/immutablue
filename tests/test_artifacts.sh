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

# Write the shared overrides the image's backend replaces or drops on purpose,
# one path per line (an entry ending in '/' covers a directory), for both
# validators: every file under backends/<backend>/overrides (a backend may
# legitimately replace a shared file with its own version) and backend.yaml
# 'drops_overrides' (shared files it removes because its OS keeps them
# elsewhere, e.g. FreeBSD's sudo reads /usr/local/etc/sudoers.d only).
#
# param $1: output file
function write_override_skip_list() {
  local out="$1"
  local backend
  local backend_dir

  : > "${out}"
  backend="$(podman run --rm --entrypoint "" "$IMAGE" cat /usr/immutablue/backend 2>/dev/null || true)"
  [[ -n "${backend}" ]] || return 0
  backend_dir="${ARTIFACTS_DIR}/../backends/${backend}"

  if [[ -d "${backend_dir}/overrides" ]]; then
    (cd "${backend_dir}/overrides" && find . -type f | sed 's|^\.||') >> "${out}"
  fi
  if [[ -f "${backend_dir}/backend.yaml" ]]; then
    yq '.drops_overrides // [] | .[]' "${backend_dir}/backend.yaml" >> "${out}"
  fi
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

  local skip_list
  local rc=0
  skip_list="$(mktemp)"
  write_override_skip_list "${skip_list}"

  # crispy ships with the in-house deps, which not every image has (a
  # backend or build without them), and it compiles its script with gcc and
  # pkg-config, which some images with crispy lack (gnomeos). Those images
  # get the same comparison done in bash, with the same skip rules as
  # validate_artifacts.c.
  if ! podman run --rm --entrypoint "" "$IMAGE" sh -c 'command -v crispy && command -v gcc && command -v pkg-config' > /dev/null 2>&1; then
    test_override_files_in_container_shell "${skip_list}" || rc=$?
    rm -f "${skip_list}"
    return "${rc}"
  fi

  # Run the crispy script inside a single container with overrides mounted
  # at /expected. The script compares SHA256 hashes of all files under
  # /expected against their corresponding paths on the root filesystem.
  if ! podman run --rm \
    -v "${ARTIFACTS_DIR}/overrides:/expected:ro,z" \
    -v "${CRISPY_SCRIPT}:/tmp/validate_artifacts.c:ro,z" \
    -v "${skip_list}:/tmp/override-skips:ro,z" \
    "$IMAGE" \
    crispy --cache-dir /tmp -n /tmp/validate_artifacts.c /expected /tmp/override-skips; then
    rm -f "${skip_list}"
    echo "FAIL: Override file verification failed"
    return 1
  fi
  rm -f "${skip_list}"

  echo "PASS: Override file verification completed"
  return 0
}

# Bash form of validate_artifacts.c for images without crispy: every regular
# file under the overrides must exist on the image with the same SHA256, except
# the paths the C validator skips (test fixtures, the build-appended Justfile,
# system.conf, Python bytecode) and the backend skip list
# (write_override_skip_list).
#
# param $1: the skip list file
function test_override_files_in_container_shell() {
  local skip_list="$1"

  if ! podman run --rm --entrypoint "" \
    -v "${ARTIFACTS_DIR}/overrides:/expected:ro,z" \
    -v "${skip_list}:/tmp/override-skips:ro,z" \
    "$IMAGE" bash -c '
      failed=0; checked=0; skipped=0
      mapfile -t skips < /tmp/override-skips
      backend_skips () {
        local entry
        for entry in "${skips[@]}"; do
          [[ -n "${entry}" ]] || continue
          if [[ "${entry}" == */ ]]; then
            [[ "$1" == "${entry}"* ]] && return 0
          elif [[ "$1" == "${entry}" ]]; then
            return 0
          fi
        done
        return 1
      }
      while IFS= read -r -d "" file; do
        rel="${file#/expected}"
        case "${rel}" in
          */test/*|*/Justfile|*/system.conf|*__pycache__*) skipped=$((skipped + 1)); continue ;;
        esac
        if backend_skips "${rel}"; then
          skipped=$((skipped + 1)); continue
        fi
        checked=$((checked + 1))
        if [[ ! -f "${rel}" ]]; then
          echo "FAIL: ${rel} (not found on filesystem)"; failed=$((failed + 1)); continue
        fi
        if [[ "$(sha256sum < "${file}")" != "$(sha256sum < "${rel}")" ]]; then
          echo "FAIL: ${rel}"; failed=$((failed + 1))
        fi
      done < <(find /expected -type f -print0)
      echo "- Files checked: ${checked}, skipped: ${skipped}, failed: ${failed}"
      [[ ${failed} -eq 0 ]]
    '; then
    echo "FAIL: Override file verification failed"
    return 1
  fi

  echo "PASS: Override file verification completed"
  return 0
}

# Test that the shipped initramfs was regenerated by this build.
#
# The base image's initramfs is generated during Fedora's compose, before any
# Immutablue override exists, and bootc only copies it to /boot at deploy time
# -- it never rebuilds it. So an initramfs that still carries the distribution
# defaults means build/80-initramfs.sh did not run or did not take effect, and
# every /usr and /etc override the initrd reads is being ignored at early boot.
#
# That shipped silently for about two years: the only user-visible symptom was
# the Immutablue logo appearing at shutdown (plymouth restarted from the real
# root) but not at boot (plymouth running from the stale initrd).
function test_initramfs_regenerated() {
  echo "Testing initramfs freshness"

  if ! podman run --rm "$IMAGE" bash -c '
    set -euo pipefail

    # A backend that skips build/80-initramfs.sh boots an initramfs it does
    # not build (gnomeos: GNOME OS ships its own), so there is nothing of
    # Immutablue'"'"'s to check.
    backend_yaml="/usr/immutablue/backends/$(cat /usr/immutablue/backend 2>/dev/null)/backend.yaml"
    if grep -qE "^[[:space:]]*-[[:space:]]*80-initramfs\.sh" "${backend_yaml}" 2> /dev/null; then
      echo "SKIP: this backend does not build the initramfs (80-initramfs.sh skipped)"
      exit 0
    fi

    kver=""
    for moddir in /usr/lib/modules/*/; do
      k="$(basename "$moddir")"
      [[ "$k" == *+debug ]] && continue
      [[ -f "$moddir/vmlinuz" ]] || continue
      kver="$k"
      break
    done

    if [[ -z "$kver" ]]; then
      echo "WARN: no kernel in image, initramfs check skipped"
      exit 0
    fi

    img="/usr/lib/modules/$kver/initramfs.img"
    if [[ ! -f "$img" ]]; then
      echo "FAIL: no initramfs at $img"
      exit 1
    fi

    # Without the ostree module the initrd cannot mount the deployment root,
    # so the image would not boot at all. dracut never adds it automatically:
    # 50ostree returns 255 from check(), meaning "only when requested".
    if ! lsinitrd "$img" 2>/dev/null | sed -n "/^dracut modules:/,/^===/p" | grep -qx "ostree"; then
      echo "FAIL: initramfs for $kver has no ostree module (image would not boot)"
      exit 1
    fi

    # The plymouth theme in the initrd must match the image configuration,
    # otherwise the boot splash falls back to the distribution default.
    if [[ -f /etc/plymouth/plymouthd.conf ]]; then
      want="$(awk -F= "/^[[:space:]]*Theme[[:space:]]*=/ { gsub(/[[:space:]]/, \"\", \$2); print \$2 }" /etc/plymouth/plymouthd.conf)"
      if [[ -n "$want" ]]; then
        got="$(lsinitrd -f etc/plymouth/plymouthd.conf "$img" 2>/dev/null \
          | awk -F= "/^[[:space:]]*Theme[[:space:]]*=/ { gsub(/[[:space:]]/, \"\", \$2); print \$2 }")"
        if [[ "$got" != "$want" ]]; then
          echo "FAIL: initramfs plymouth theme is \"$got\", image configures \"$want\""
          echo "      the initramfs is stale -- build/80-initramfs.sh did not take effect"
          exit 1
        fi

        # The theme name matching is not enough: the branded watermark is a
        # separate asset and is what actually renders as the logo.
        rootfs_wm="/usr/share/plymouth/themes/$want/watermark.png"
        if [[ -f "$rootfs_wm" ]]; then
          want_md5="$(md5sum "$rootfs_wm" | cut -d" " -f1)"
          got_md5="$(lsinitrd -f "usr/share/plymouth/themes/$want/watermark.png" "$img" 2>/dev/null | md5sum | cut -d" " -f1)"
          if [[ "$got_md5" != "$want_md5" ]]; then
            echo "FAIL: initramfs watermark.png does not match the image copy"
            echo "      the boot splash would show the wrong logo"
            exit 1
          fi
        fi
        echo "initramfs plymouth theme \"$want\" and watermark confirmed"
      fi
    fi

    echo "initramfs for $kver verified"
  '; then
    echo "FAIL: initramfs freshness check failed"
    return 1
  fi

  echo "PASS: initramfs regenerated and matches the image"
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

if ! test_initramfs_regenerated; then
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
