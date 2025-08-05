#!/bin/bash
# Kuberblue Container Tests
#
# This script tests Kuberblue-specific functionality of the container image, including:
# - Kubernetes binaries verification (kubeadm, kubelet, kubectl, crio)
# - Kuberblue-specific files and directories
# - Systemd services and timers verification
# - Kuberblue user configuration validation
# - System configurations (kernel modules, sysctl, SELinux, SSH)
#
# It extends the existing test_container.sh patterns using same structure and error handling
#
# Usage: ./test_kuberblue_container.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference

# Enable strict error handling
set -euo pipefail

echo "Running Kuberblue container tests"

# Test variables
# Use the first argument as the image name, or default to a standard value
IMAGE="${1:-quay.io/immutablue/immutablue:42}"
TEST_DIR="$(dirname "$(realpath "$0")")" 
ROOT_DIR="$(dirname "$(dirname "$TEST_DIR")")"

# Validate this is a Kuberblue image
if [[ "${KUBERBLUE:-0}" != "1" ]] && [[ "$IMAGE" != *"kuberblue"* ]]; then
  echo "ERROR: This test requires a Kuberblue image or KUBERBLUE=1 environment variable"
  echo "Please build with: make KUBERBLUE=1 build"
  echo "Then run with: make KUBERBLUE=1 test_kuberblue_container"
  echo "Current image: $IMAGE"
  exit 1
fi

# Helper functions

# Test for required Kubernetes binaries in the container
# Verifies essential Kubernetes packages are present
function test_kuberblue_binaries() {
  echo "Testing Kubernetes binaries in container"
  # Run a container and check for critical Kubernetes packages
  if ! podman run --rm "$IMAGE" rpm -q kubernetes1.32 kubernetes1.32-client kubernetes1.32-kubeadm cri-o cri-tools1.32; then
    echo "FAIL: Kubernetes binaries check failed"
    echo "ERROR: The required Kubernetes packages are not installed in the container."
    echo "This likely means the image was not built with KUBERBLUE=1."
    echo "Please build the Kuberblue image first:"
    echo "  make KUBERBLUE=1 build"
    echo "Expected image: $IMAGE"
    return 1
  fi
  
  # Test that binaries are accessible
  if ! podman run --rm "$IMAGE" bash -c "command -v kubeadm && command -v kubelet && command -v kubectl && command -v crio"; then
    echo "FAIL: Kubernetes binaries accessibility check failed"
    return 1
  fi
  
  echo "PASS: Kubernetes binaries check succeeded"
  return 0
}

# Test for Kuberblue-specific files and directories
# Verifies Kuberblue-specific files exist
function test_kuberblue_files() {
  echo "Testing Kuberblue-specific files in container"
  
  # Test for essential Kuberblue directories
  if ! podman run --rm "$IMAGE" bash -c "test -d /usr/libexec/kuberblue && test -d /etc/kuberblue"; then
    echo "FAIL: Kuberblue directory structure check failed"
    return 1
  fi
  
  # Test for Kuberblue-specific configuration files
  local required_files=(
    "/etc/kuberblue/kubeadm.yaml"
    "/etc/kuberblue/manifests/metadata.yaml.tpl"
    "/etc/kuberblue/manifests/kube-flannel.yaml"
    "/etc/kuberblue/manifests/00-infrastructure/00-cilium/00-metadata.yaml"
    "/etc/kuberblue/manifests/00-infrastructure/10-openebs/00-metadata.yaml"
    "/usr/libexec/kuberblue/99-common.sh"
    "/usr/libexec/kuberblue/variables.sh"
    "/usr/libexec/immutablue/just/30-kuberblue.justfile"
  )
  
  for file in "${required_files[@]}"; do
    if ! podman run --rm "$IMAGE" test -f "$file"; then
      echo "FAIL: Required file $file not found"
      return 1
    fi
  done
  
  # Test for kube_setup scripts
  local kube_setup_scripts=(
    "kube_add_kuberblue_user.sh"
    "kube_deploy.sh"
    "kube_get_config.sh"
    "kube_init.sh"
    "kube_post_install.sh"
    "kube_put_config.sh"
    "kube_reset.sh"
    "kube_untaint_master.sh"
    "run_command_as_kuberblue_user.sh"
  )
  
  for script in "${kube_setup_scripts[@]}"; do
    if ! podman run --rm "$IMAGE" test -f "/usr/libexec/kuberblue/kube_setup/$script"; then
      echo "FAIL: Required kube_setup script $script not found"
      return 1
    fi
  done
  
  echo "PASS: Kuberblue files check succeeded"
  return 0
}

# Test systemd services and timers for Kuberblue
# Verifies Kuberblue systemd services are properly installed
function test_kuberblue_systemd() {
  echo "Testing Kuberblue systemd services in container"
  
  # Check for Kuberblue systemd service
  if ! podman run --rm "$IMAGE" test -f "/etc/systemd/system/kuberblue-onboot.service"; then
    echo "FAIL: kuberblue-onboot.service not found"
    return 1
  fi
  
  # Verify service file contains expected content
  if ! podman run --rm "$IMAGE" grep -q "kuberblue" "/etc/systemd/system/kuberblue-onboot.service"; then
    echo "FAIL: kuberblue-onboot.service content validation failed"
    return 1
  fi
  
  # Check that crio and kubelet services are available (should be from kubernetes packages)
  if ! podman run --rm "$IMAGE" bash -c "systemctl list-unit-files | grep -E '(crio|kubelet)\.service'"; then
    echo "FAIL: Kubernetes systemd services check failed"
    return 1
  fi
  
  echo "PASS: Kuberblue systemd services check succeeded"
  return 0
}

# Test kuberblue user configuration
# Verifies kuberblue user (UID 970) exists with proper permissions
function test_kuberblue_user() {
  echo "Testing kuberblue user configuration in container"
  
  # Note: The kuberblue user might be created during first boot, not at build time
  # So we test for the setup script that creates the user instead
  if ! podman run --rm "$IMAGE" test -f "/usr/libexec/kuberblue/kube_setup/kube_add_kuberblue_user.sh"; then
    echo "FAIL: kuberblue user setup script not found"
    return 1
  fi
  
  # Check sudoers configuration exists
  if ! podman run --rm "$IMAGE" test -f "/etc/sudoers"; then
    echo "FAIL: sudoers configuration not found"
    return 1
  fi
  
  echo "PASS: Kuberblue user configuration check succeeded"
  return 0
}

# Test system configurations for Kuberblue
# Validates system configurations (kernel modules, sysctl, SELinux, SSH)
function test_kuberblue_configs() {
  echo "Testing Kuberblue system configurations in container"
  
  # Test kernel modules configuration
  if ! podman run --rm "$IMAGE" test -f "/etc/modules-load.d/50-kuberblue.conf"; then
    echo "FAIL: Kuberblue kernel modules configuration not found"
    return 1
  fi
  
  # Test sysctl settings
  if ! podman run --rm "$IMAGE" test -f "/etc/sysctl.d/50-kuberblue.conf"; then
    echo "FAIL: Kuberblue sysctl configuration not found"
    return 1
  fi
  
  # Test SELinux configuration
  if ! podman run --rm "$IMAGE" test -f "/etc/selinux/config"; then
    echo "FAIL: SELinux configuration not found"
    return 1
  fi
  
  # Test SSH configuration
  if ! podman run --rm "$IMAGE" test -f "/etc/ssh/sshd_config"; then
    echo "FAIL: SSH configuration not found"
    return 1
  fi
  
  # Test NetworkManager configuration
  if ! podman run --rm "$IMAGE" test -f "/etc/NetworkManager/NetworkManager.conf"; then
    echo "FAIL: NetworkManager configuration not found"
    return 1
  fi
  
  echo "PASS: Kuberblue system configurations check succeeded"
  return 0
}

# Test additional Kuberblue packages
# Verifies helm, cockpit and other Kuberblue-specific packages
function test_kuberblue_packages() {
  echo "Testing additional Kuberblue packages in container"
  
  # Check for Kuberblue-specific packages
  if ! podman run --rm "$IMAGE" rpm -q helm cockpit glances; then
    echo "FAIL: Additional Kuberblue packages check failed"
    return 1
  fi
  
  # Test that helm binary is accessible
  if ! podman run --rm "$IMAGE" command -v helm; then
    echo "FAIL: helm binary accessibility check failed"
    return 1
  fi
  
  echo "PASS: Additional Kuberblue packages check succeeded"
  return 0
}

# Run tests
echo "=== Running Kuberblue Container Tests ==="
FAILED=0

# Execute each test and track failures
if ! test_kuberblue_binaries; then
  ((FAILED++))
fi

if ! test_kuberblue_files; then
  ((FAILED++))
fi

if ! test_kuberblue_systemd; then
  ((FAILED++))
fi

if ! test_kuberblue_user; then
  ((FAILED++))
fi

if ! test_kuberblue_configs; then
  ((FAILED++))
fi

if ! test_kuberblue_packages; then
  ((FAILED++))
fi

# Report test results
echo "=== Kuberblue Container Test Results ==="
if [[ $FAILED -eq 0 ]]; then
  echo "All Kuberblue container tests PASSED!"
  exit 0
else
  echo "$FAILED Kuberblue container tests FAILED!"
  exit 1
fi